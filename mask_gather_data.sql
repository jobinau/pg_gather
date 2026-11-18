-- ===========================================================================
-- mask_gather_data.sql
--
-- Masks customer-identifying data in a database that holds an imported
-- pg_gather output (out.tsv), so the generated report can be shared
-- (talks, KB articles, bug reports) without exposing the customer.
--
-- Usage (after importing the data as usual):
--   psql -d gather -f gather_schema.sql -f out.tsv
--   psql -d gather -f mask_gather_data.sql
--   psql -d gather -X -f gather_report.sql > GatherReport.html
--
-- Optional psql variables:
--   -v show_map=1   print the old -> new mapping at the end (DO NOT SHARE IT)
--
-- What is masked (one consistent mapping is applied everywhere):
--   * database names ......... dbN            (template0/1, postgres, cloud admin dbs kept)
--   * role names ............. userN          (postgres, pg_*, cloud admin roles kept)
--   * schema names ........... schemaN        (pg_catalog, public, information_schema, pg_toast kept)
--   * relation names ......... tableN/indexN/mviewN/ptableN/pindexN/seqN/viewN/ftableN
--   * tablespaces ............ tblspcN, location /pgtblspc/tblspcN
--   * IPs / host names ....... 10.99.x.y, fd00::N, hostN.example.com
--   * replication slots ...... slotN
--   * application names ...... standbyN (walsenders / sync standby names), appN (others)
--   * prepared xact GIDs ..... gidN
--   * data_directory ......... /var/lib/pgsql/<major>/data (also in every path that uses it)
--   * log_directory, <ext>.log_directory: /var/log/postgresql[/<ext>] unless "log"/"pg_log" in the data dir
--   * ssl_*_file / krb_server_keyfile / extension cert files: standard names (server.crt, server.key, ...)
--   * pgBackRest stanza, repo options, user@host and passwords in commands/conninfo
--   * SQL text in pg_get_activity / pg_get_statements (identifiers and literals -> ####)
--   * SSL DNs and GSS principals
--   * pg_srvr (\conninfo) in both the old "You are connected..." and PG18 table format
--   * pg_gather header (user, database, client/server address)
--   * pg_hba rules (databases, users, addresses), db/role settings (search_path, ...)
--
-- The whole script runs in one transaction: it either masks everything or nothing.
-- Mapping tables are TEMP tables, so nothing about the original values is left
-- in the database once the session ends.
-- ===========================================================================
\set ON_ERROR_STOP on
\set QUIET 1
\pset pager off
SET client_min_messages = WARNING;

BEGIN;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE mask_map (
  kind text NOT NULL,   -- db, role, schema, tblspc, slot, app, host, path
  old  text NOT NULL,
  new  text NOT NULL,
  PRIMARY KEY (kind, old)
);

-- Escape a literal so it can be embedded in a regular expression
CREATE FUNCTION pg_temp.re_esc(t text) RETURNS text LANGUAGE sql IMMUTABLE AS
$$ SELECT regexp_replace(t, '([!$()*+.:<=>?[\\\]^{|}-])', '\\\1', 'g') $$;

-- Replace every whole-token occurrence of the mapped values of the given kinds.
-- Longest values first, through placeholders, so a new value is never re-mapped.
CREATE FUNCTION pg_temp.mask_tokens(t text, kinds text[]) RETURNS text
LANGUAGE plpgsql STABLE AS $$
DECLARE
  m    record;
  news text[] := '{}';
  i    int := 0;
BEGIN
  IF t IS NULL OR t = '' THEN RETURN t; END IF;
  FOR m IN SELECT kind, old, new FROM mask_map
            WHERE kind = ANY (kinds) AND old <> ''
            ORDER BY length(old) DESC, old
  LOOP
    CONTINUE WHEN position(lower(m.old) IN lower(t)) = 0;   -- fast path
    i := i + 1;
    news := news || m.new;
    t := regexp_replace(t,
           CASE m.kind
             WHEN 'path' THEN '()'
             WHEN 'host' THEN '(^|[^A-Za-z0-9_.-])'
             ELSE             '(^|[^A-Za-z0-9_])' END
           || pg_temp.re_esc(m.old)
           || CASE m.kind
                WHEN 'path' THEN '(?![A-Za-z0-9_.-])'
                WHEN 'host' THEN '(?![A-Za-z0-9_-]|\.[A-Za-z0-9])'
                ELSE             '(?![A-Za-z0-9_])' END,
           '\1' || chr(1) || i || chr(2),
           CASE WHEN m.kind = 'host' THEN 'gi' ELSE 'g' END);
  END LOOP;
  FOR j IN REVERSE i .. 1 LOOP
    t := replace(t, chr(1) || j || chr(2), news[j]);
  END LOOP;
  RETURN t;
END $$;

-- Exact lookup of a single value (NULL / unmapped values are returned as is)
CREATE FUNCTION pg_temp.mask_val(v text, k text) RETURNS text LANGUAGE sql STABLE AS
$$ SELECT COALESCE((SELECT new FROM mask_map WHERE kind = k AND old = v), v) $$;

-- One line of the pre-PG18 \conninfo output:
--   You are connected to database "x" as user "y" on host "h" (address "a") at port "p".
CREATE FUNCTION pg_temp.mask_conninfo_line(t text) RETURNS text LANGUAGE plpgsql STABLE AS $$
DECLARE v text;
BEGIN
  v := substring(t FROM 'to database "([^"]*)"');
  IF v IS NOT NULL THEN
    t := replace(t, 'to database "' || v || '"', 'to database "' || pg_temp.mask_val(v, 'db') || '"');
  END IF;
  v := substring(t FROM 'as user "([^"]*)"');
  IF v IS NOT NULL THEN
    t := replace(t, 'as user "' || v || '"', 'as user "' || pg_temp.mask_val(v, 'role') || '"');
  END IF;
  FOR v IN SELECT (regexp_matches(t, '(?:on host|address) "([^"]*)"', 'g'))[1] LOOP
    t := replace(t, '"' || v || '"', '"' || pg_temp.mask_val(lower(v), 'host') || '"');
  END LOOP;
  v := substring(t FROM 'socket in "([^"]*)"');
  IF v IS NOT NULL THEN
    t := replace(t, 'socket in "' || v || '"', 'socket in "' || pg_temp.mask_tokens(v, ARRAY['path']) || '"');
  END IF;
  RETURN t;
END $$;

-- Secrets and options in conninfo strings and shell commands
CREATE FUNCTION pg_temp.mask_secrets(t text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
SELECT regexp_replace(regexp_replace(regexp_replace(regexp_replace(t,
  -- password-like keys in conninfo / env vars
  '((password|passfile|sslpassword|sslkey|sslcert|sslrootcert|sslcrl|PGPASSWORD|PGPASSFILE)\s*=\s*)(''[^'']*''|"[^"]*"|[^\s''"]+)',
  '\1********', 'gi'),
  -- pgBackRest stanza
  '(stanza[= ]+)[^\s''"]+', '\1db', 'gi'),
  -- pgBackRest / wal-g / barman repository options that identify the customer
  '(--[a-z0-9-]*(bucket|endpoint|region|key|account|container|host-user|repo[0-9]*-path|cipher-pass|token)[a-z0-9-]*[= ])[^\s''"]+',
  '\1********', 'gi'),
  -- remaining user@host
  '[A-Za-z0-9_.-]+@', 'user@', 'g')
$$;

-- SQL text: keep keywords, whitespace, punctuation and $n parameters; mask everything else
CREATE TEMP TABLE mask_kw (word text PRIMARY KEY);
INSERT INTO mask_kw
SELECT word FROM pg_get_keywords()
UNION
SELECT unnest(ARRAY['start_replication','identify_system','base_backup','timeline_history',
                    'read_replication_slot','create_replication_slot','drop_replication_slot',
                    'slot','logical','physical','timeline','reserve_wal','proto_version',
                    'publication_names','streaming','two_phase','origin','binary','messages',
                    'count','sum','avg','min','max','now','coalesce','lower','upper']);

CREATE FUNCTION pg_temp.mask_query(q text) RETURNS text LANGUAGE sql STABLE AS $$
SELECT CASE WHEN q IS NULL OR q = '' THEN q ELSE (
  SELECT string_agg(
           CASE WHEN tok ~ '^\s'                       THEN tok   -- whitespace
                WHEN tok ~ '^[!-/:-@[-^`{-~]$'         THEN tok   -- ASCII punctuation
                WHEN tok ~ '^\$[0-9]+$'                THEN tok   -- bind parameters
                WHEN lower(tok) IN (SELECT word FROM mask_kw) THEN tok
                ELSE repeat('#', length(tok)) END,
           '' ORDER BY ord)
    FROM regexp_matches(q, '(\$[0-9]+|\s+|[!-/:-@[-^`{-~]|[^\s!-/:-@[-^`{-~]+)', 'g')
         WITH ORDINALITY AS m(t, ord),
         LATERAL (SELECT t[1] AS tok) x)
END
$$;

-- ---------------------------------------------------------------------------
-- 1. Build the mappings
-- ---------------------------------------------------------------------------
\echo Building mappings...

-- Databases (pg_get_db + anything referenced in hba / conninfo / \conninfo)
INSERT INTO mask_map
SELECT 'db', old, 'db' || row_number() OVER (ORDER BY old)
FROM (
  SELECT datname FROM pg_get_db
  UNION SELECT unnest(db) FROM pg_get_hba_rules
  UNION SELECT db FROM pg_gather
  UNION SELECT (regexp_matches(setting, 'dbname\s*=\s*([^\s''"]+)', 'gi'))[1] FROM pg_get_confs
  UNION SELECT (regexp_matches(connstr, 'to database "([^"]+)"'))[1] FROM pg_srvr
  UNION SELECT trim(split_part(connstr, '|', 2)) FROM pg_srvr WHERE trim(split_part(connstr, '|', 1)) = 'Database'
) s(old)
WHERE old IS NOT NULL AND old <> ''
  AND old NOT LIKE '@%'
  AND old NOT IN ('template0','template1','postgres','all','sameuser','samerole','samegroup','replication',
                  'rdsadmin','azure_maintenance','azure_sys','cloudsqladmin','alloydbadmin');

-- Roles (login roles + hba users + replication users + conninfo users + collector)
INSERT INTO mask_map
SELECT 'role', old, 'user' || row_number() OVER (ORDER BY old)
FROM (
  SELECT rolname FROM pg_get_roles
  UNION SELECT ltrim(unnest(usr), '+') FROM pg_get_hba_rules
  UNION SELECT usename FROM pg_replication_stat
  -- pg_gather.usr is "<current_user> - pg_gather.V<version>": only the user part is a role
  UNION SELECT COALESCE(substring(usr FROM '^(.*) - pg_gather\.V'), usr) FROM pg_gather
  UNION SELECT (regexp_matches(setting, '\muser\s*=\s*([^\s''"]+)', 'gi'))[1] FROM pg_get_confs
  UNION SELECT (regexp_matches(connstr, 'as user "([^"]+)"'))[1] FROM pg_srvr
  UNION SELECT trim(split_part(connstr, '|', 2)) FROM pg_srvr WHERE trim(split_part(connstr, '|', 1)) = 'Client User'
) s(old)
WHERE old IS NOT NULL AND old <> ''
  AND old NOT LIKE '@%'
  AND old NOT LIKE 'pg\_%'
  AND old NOT IN ('postgres','all','rdsadmin','rds_superuser','rdsrepladmin','rds_replication',
                  'azure_superuser','azure_pg_admin','azuresu','replication',
                  'cloudsqladmin','cloudsqlsuperuser','cloudsqlreplica','alloydbadmin','alloydbsuperuser');

-- Schemas
INSERT INTO mask_map
SELECT 'schema', nsname, 'schema' || row_number() OVER (ORDER BY nsoid)
FROM pg_get_ns
WHERE nsname NOT IN ('pg_catalog','pg_toast','information_schema','public')
  AND nsname NOT LIKE 'pg\_temp\_%' AND nsname NOT LIKE 'pg\_toast\_temp\_%'
ON CONFLICT DO NOTHING;

-- Tablespaces (name and location)
INSERT INTO mask_map
SELECT 'tblspc', tsname, 'tblspc' || row_number() OVER (ORDER BY tsoid)
FROM pg_get_tablespace WHERE tsname NOT IN ('pg_default','pg_global')
ON CONFLICT DO NOTHING;

INSERT INTO mask_map
SELECT 'path', t.location, '/pgtblspc/' || m.new
FROM pg_get_tablespace t JOIN mask_map m ON m.kind = 'tblspc' AND m.old = t.tsname
WHERE t.location IS NOT NULL AND t.location <> ''
ON CONFLICT DO NOTHING;

-- Data directory
INSERT INTO mask_map
SELECT 'path', setting,
       '/var/lib/pgsql/' ||
       COALESCE((SELECT (setting::int / 10000)::text FROM pg_get_confs WHERE name = 'server_version_num'),
                (SELECT substring(ver FROM 'PostgreSQL (\d+)') FROM pg_gather), 'pg') || '/data'
FROM pg_get_confs
WHERE name = 'data_directory' AND setting IS NOT NULL AND setting <> ''
ON CONFLICT DO NOTHING;

-- Replication slots
INSERT INTO mask_map
SELECT 'slot', slot_name, 'slot' || row_number() OVER (ORDER BY slot_name)
FROM (SELECT slot_name FROM pg_get_slots
      UNION SELECT setting FROM pg_get_confs WHERE name = 'primary_slot_name') s(slot_name)
WHERE slot_name IS NOT NULL AND slot_name <> ''
ON CONFLICT DO NOTHING;

-- Application names: standbys (walsenders + synchronous_standby_names) and client applications
INSERT INTO mask_map
SELECT 'app', old, 'standby' || row_number() OVER (ORDER BY old)
FROM (
  SELECT application_name FROM pg_get_activity WHERE backend_type = 'walsender'
  UNION SELECT trim(both '" ' FROM tok)
          FROM pg_get_confs,
               regexp_split_to_table(regexp_replace(setting, '^\s*(FIRST|ANY)?\s*[0-9]*\s*\(?|\)\s*$', '', 'gi'), ',') tok
         WHERE name = 'synchronous_standby_names'
  UNION SELECT (regexp_matches(setting, 'application_name\s*=\s*([^\s''"]+)', 'gi'))[1]
          FROM pg_get_confs WHERE name = 'primary_conninfo'
) s(old)
WHERE old IS NOT NULL AND old NOT IN ('', '*', 'walreceiver', 'pg_basebackup', 'pg_receivewal')
ON CONFLICT DO NOTHING;

INSERT INTO mask_map
SELECT 'app', old, 'app' || row_number() OVER (ORDER BY old)
FROM (SELECT DISTINCT application_name FROM pg_get_activity) s(old)
WHERE old IS NOT NULL AND old <> ''
  -- well known tools are kept: they help the analysis and are not customer data
  AND old !~* '^(psql|pg_dump|pg_dumpall|pg_restore|pg_basebackup|pg_receivewal|pg_rewind|pgbench|vacuumdb|reindexdb|walreceiver|'
              'PostgreSQL JDBC Driver|pgAdmin|DBeaver|DataGrip|Navicat|Patroni|pgbackrest|barman|wal-g|pg_cron|pmm|'
              'pg_stat_monitor|pgbouncer|pgpool|repmgr|TimescaleDB|Npgsql|psycopg|node-postgres|pgx|pg_gather|'
              'PostgreSQL ODBC|Metabase|Grafana|Debezium|Airbyte|Fivetran|pglogical|pg_partman)'
ON CONFLICT DO NOTHING;

-- Hosts / IP addresses from every place they can show up
CREATE TEMP TABLE mask_hosts AS
SELECT DISTINCT lower(trim(both ' "''[]' FROM old)) AS old
FROM (
  SELECT host(client_addr) FROM pg_get_activity
  UNION SELECT client_hostname FROM pg_get_activity
  UNION SELECT client_addr FROM pg_replication_stat
  UNION SELECT client_hostname FROM pg_replication_stat
  UNION SELECT addr FROM pg_get_hba_rules
  UNION SELECT host(client) FROM pg_gather
  UNION SELECT host(server) FROM pg_gather
  -- \conninfo, both formats
  UNION SELECT (regexp_matches(connstr, '(?:on host|address) "([^"]+)"', 'g'))[1] FROM pg_srvr
  UNION SELECT trim(split_part(connstr, '|', 2)) FROM pg_srvr
         WHERE trim(split_part(connstr, '|', 1)) IN ('Host', 'Host Address', 'Server Address')
  -- listen_addresses
  UNION SELECT regexp_split_to_table(setting, ',') FROM pg_get_confs WHERE name = 'listen_addresses'
  UNION SELECT regexp_split_to_table(setting, ',') FROM pg_get_file_confs WHERE name = 'listen_addresses'
  -- host= / hostaddr= in conninfo strings
  UNION SELECT regexp_split_to_table((regexp_matches(setting, 'host(?:addr)?\s*=\s*([^\s''"]+)', 'gi'))[1], ',')
          FROM pg_get_confs
  UNION SELECT regexp_split_to_table((regexp_matches(setting, 'host(?:addr)?\s*=\s*([^\s''"]+)', 'gi'))[1], ',')
          FROM pg_get_file_confs
  -- any IPv4 in any setting
  UNION SELECT (regexp_matches(setting, '(?:^|[^0-9.])([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})(?![0-9])', 'g'))[1]
          FROM pg_get_confs
  UNION SELECT (regexp_matches(setting, '(?:^|[^0-9.])([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})(?![0-9])', 'g'))[1]
          FROM pg_get_file_confs
  -- host names in shell commands: user@host, -h host, --host=host, FQDNs
  UNION SELECT (regexp_matches(setting, '(?:@|(?:^|\s)-h\s*|--[a-z0-9-]*host[= ])([A-Za-z0-9][A-Za-z0-9.-]*)', 'g'))[1]
          FROM pg_get_confs
         WHERE name IN ('archive_command','restore_command','archive_cleanup_command','recovery_end_command','archive_library')
  UNION SELECT (regexp_matches(setting, '(?:^|[^A-Za-z0-9_./-])([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+){2,}\.[A-Za-z]{2,})(?![A-Za-z0-9_.-])', 'g'))[1]
          FROM pg_get_confs
         WHERE name IN ('archive_command','restore_command','archive_cleanup_command','recovery_end_command','primary_conninfo')
) s(old)
WHERE old IS NOT NULL;

INSERT INTO mask_map
SELECT 'host', old,
       CASE cls
         WHEN 'v4'  THEN '10.99.' || ((rn - 1) / 254) || '.' || ((rn - 1) % 254 + 1)
         WHEN 'v6'  THEN 'fd00::' || to_hex(rn)
         WHEN 'dom' THEN '.domain' || rn || '.example.com'
         ELSE            'host' || rn || '.example.com' END
FROM (
  SELECT old, cls, row_number() OVER (PARTITION BY cls ORDER BY old) rn
  FROM (
    SELECT old,
           CASE WHEN old ~ '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' THEN 'v4'
                WHEN old ~ ':'                             THEN 'v6'
                WHEN old ~ '^\.'                           THEN 'dom'
                ELSE 'name' END AS cls
    FROM mask_hosts
    WHERE old NOT IN ('', '*', 'localhost', 'all', 'samehost', 'samenet', '0.0.0.0', '::', '::1', '127.0.0.1')
      AND old NOT LIKE '127.%'
      AND old NOT LIKE '/%'              -- unix sockets
      AND old ~ '[A-Za-z0-9]'
      AND old !~ '^[0-9]+$'              -- ports
  ) c
) n
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. Apply the mappings
-- ---------------------------------------------------------------------------
\echo Masking names...

UPDATE pg_get_db SET datname = pg_temp.mask_val(datname, 'db');
UPDATE pg_get_roles SET rolname = pg_temp.mask_val(rolname, 'role'),
       rolconfig = (SELECT array_agg(split_part(c, '=', 1) || '=' ||
                      pg_temp.mask_tokens(substr(c, strpos(c, '=') + 1),
                                          ARRAY['db','role','schema','tblspc','slot','app','host','path']) ORDER BY o)
                      FROM unnest(rolconfig) WITH ORDINALITY u(c, o))
;
UPDATE pg_get_ns SET nsname = pg_temp.mask_val(nsname, 'schema');
UPDATE pg_get_tablespace SET tsname = pg_temp.mask_val(tsname, 'tblspc'),
                             location = pg_temp.mask_val(location, 'path');
UPDATE pg_get_slots SET slot_name = pg_temp.mask_val(slot_name, 'slot');
UPDATE pg_get_prep_xacts p SET gid = 'gid' || n.rn
  FROM (SELECT txn, row_number() OVER (ORDER BY prepared, txn::text) rn FROM pg_get_prep_xacts) n
 WHERE p.txn = n.txn;

-- Relations: only user objects (pg_toast_NNN names carry no customer data)
UPDATE pg_get_class c
   SET relname = n.new
  FROM (SELECT reloid,
               CASE relkind WHEN 'r' THEN 'table' WHEN 'i' THEN 'index' WHEN 'm' THEN 'mview'
                            WHEN 'p' THEN 'ptable' WHEN 'I' THEN 'pindex' WHEN 'S' THEN 'seq'
                            WHEN 'v' THEN 'view' WHEN 'f' THEN 'ftable' WHEN 'c' THEN 'type'
                            WHEN 't' THEN 'toast' ELSE 'rel' END
               || row_number() OVER (PARTITION BY relkind ORDER BY reloid) AS new
          FROM pg_get_class cl
         WHERE NOT EXISTS (SELECT 1 FROM pg_get_ns ns
                            WHERE ns.nsoid = cl.relnamespace AND ns.nsname IN ('pg_toast','pg_catalog','information_schema'))
       ) n
 WHERE c.reloid = n.reloid;

\echo Masking hosts, users and applications in sessions / replication...

UPDATE pg_get_activity
   SET client_addr      = pg_temp.mask_val(host(client_addr), 'host')::inet,
       client_hostname  = pg_temp.mask_val(lower(client_hostname), 'host'),
       -- known tools keep their name, but e.g. "DBeaver 25.1 - Main <dbname>" still hides the db
       application_name = COALESCE((SELECT new FROM mask_map WHERE kind = 'app' AND old = application_name),
                                   pg_temp.mask_tokens(application_name, ARRAY['db','role','schema','host'])),
       ssl_client_dn    = CASE WHEN ssl_client_dn IS NOT NULL AND ssl_client_dn <> '' THEN '/CN=client' END,
       ssl_issuer_dn    = CASE WHEN ssl_issuer_dn IS NOT NULL AND ssl_issuer_dn <> '' THEN '/CN=issuer' END,
       ssl_client_serial = CASE WHEN ssl_client_serial IS NOT NULL THEN 1 END,
       gss_princ        = CASE WHEN gss_princ IS NOT NULL AND gss_princ <> '' THEN 'principal@EXAMPLE.COM' END
 WHERE client_addr IS NOT NULL OR client_hostname IS NOT NULL OR application_name IS NOT NULL
    OR ssl_client_dn IS NOT NULL OR ssl_issuer_dn IS NOT NULL OR gss_princ IS NOT NULL;

UPDATE pg_replication_stat
   SET usename         = pg_temp.mask_val(usename, 'role'),
       client_addr     = pg_temp.mask_val(lower(client_addr), 'host'),
       client_hostname = pg_temp.mask_val(lower(client_hostname), 'host');

UPDATE pg_gather
   SET usr    = CASE WHEN usr ~ ' - pg_gather\.V'
                     THEN pg_temp.mask_val(substring(usr FROM '^(.*) - pg_gather\.V'), 'role')
                          || substring(usr FROM ' - pg_gather\.V.*$')
                     ELSE pg_temp.mask_val(usr, 'role') END,
       db     = pg_temp.mask_val(db, 'db'),
       client = pg_temp.mask_val(host(client), 'host')::inet,
       server = pg_temp.mask_val(host(server), 'host')::inet,
       bindir = pg_temp.mask_tokens(bindir, ARRAY['path','host']);

\echo Masking pg_hba rules...

UPDATE pg_get_hba_rules
   SET db   = (SELECT array_agg(pg_temp.mask_val(d, 'db') ORDER BY o) FROM unnest(db) WITH ORDINALITY u(d, o)),
       usr  = (SELECT array_agg(CASE WHEN u LIKE '+%' THEN '+' || pg_temp.mask_val(substr(u, 2), 'role')
                                     ELSE pg_temp.mask_val(u, 'role') END ORDER BY o)
                 FROM unnest(usr) WITH ORDINALITY x(u, o)),
       addr = pg_temp.mask_val(lower(addr), 'host'),
       err  = pg_temp.mask_tokens(err, ARRAY['db','role','host','path']);

\echo Masking per database / role settings...

UPDATE pg_get_db_role_confs
   SET config = (SELECT array_agg(split_part(c, '=', 1) || '=' ||
                   pg_temp.mask_tokens(substr(c, strpos(c, '=') + 1),
                                       ARRAY['db','role','schema','tblspc','slot','app','host','path']) ORDER BY o)
                   FROM unnest(config) WITH ORDINALITY u(c, o))
 WHERE config IS NOT NULL;

\echo Masking parameters...

-- Settings that hold object names (plus every extension GUC: name with a dot)
CREATE TEMP TABLE mask_name_gucs AS
SELECT unnest(ARRAY['search_path','default_tablespace','temp_tablespaces','primary_slot_name',
                    'synchronous_standby_names','application_name','synchronized_standby_slots',
                    'standby_slot_names','session_authorization','role']) AS name;

-- Masking rules per parameter, shared by pg_get_confs and pg_get_file_confs
CREATE FUNCTION pg_temp.mask_conf(n text, v text) RETURNS text LANGUAGE plpgsql STABLE AS $$
DECLARE
  all_ids CONSTANT text[] := ARRAY['db','role','schema','tblspc','slot','app','host','path'];
  datadir text := (SELECT m.new FROM mask_map m JOIN pg_get_confs c
                     ON m.kind = 'path' AND m.old = c.setting AND c.name = 'data_directory');
  r text;
BEGIN
  IF v IS NULL OR v = '' THEN RETURN v; END IF;
  n := lower(n);

  IF n = 'cluster_name' THEN RETURN 'pgcluster'; END IF;

  -- log directories (log_directory, pgaudit.log_directory, ...): keep "log"/"pg_log"
  -- inside the data directory, anything else goes to a standard location
  IF n = 'log_directory' OR n LIKE '%.log_directory' THEN
    r := pg_temp.mask_tokens(v, all_ids);
    IF trim(trailing '/' FROM v) IN ('log', 'pg_log')
       OR (datadir IS NOT NULL AND trim(trailing '/' FROM r) IN (datadir || '/log', datadir || '/pg_log')) THEN
      RETURN r;
    END IF;
    RETURN CASE WHEN n = 'log_directory' THEN '/var/log/postgresql'
                ELSE '/var/log/postgresql/' || split_part(n, '.', 1) END;
  END IF;

  -- certificates / keys: standard names (relative to the data directory, like the PG defaults)
  CASE n
    WHEN 'ssl_cert_file'          THEN RETURN 'server.crt';
    WHEN 'ssl_key_file'           THEN RETURN 'server.key';
    WHEN 'ssl_ca_file'            THEN RETURN 'root.crt';
    WHEN 'ssl_crl_file'           THEN RETURN 'root.crl';
    WHEN 'ssl_crl_dir'            THEN RETURN 'crl';
    WHEN 'ssl_dh_params_file'     THEN RETURN 'dhparams.pem';
    WHEN 'ssl_passphrase_command' THEN RETURN '********';
    WHEN 'krb_server_keyfile'     THEN RETURN 'FILE:/etc/postgresql/krb5.keytab';
    ELSE NULL;
  END CASE;
  -- extension parameters pointing to certificates / keys
  IF n ~ '(cert|key|ca|crl|keytab)(_?file|_?dir|_?path)?$' AND v LIKE '%/%' OR v ~* '\.(crt|pem|key|p12|pfx|jks|keytab)$' THEN
    RETURN '/etc/postgresql/ssl/' || regexp_replace(n, '^.*\.', '') ||
           COALESCE(substring(v FROM '(\.[A-Za-z0-9]+)$'), '');
  END IF;

  IF n = 'primary_conninfo' THEN
    RETURN pg_temp.mask_secrets(pg_temp.mask_tokens(v, ARRAY['db','role','app','host','path']));
  END IF;
  -- settings holding object names, extension parameters, paths and commands
  IF n IN (SELECT name FROM mask_name_gucs) OR n LIKE '%.%' OR v LIKE '%/%' THEN
    RETURN pg_temp.mask_secrets(pg_temp.mask_tokens(v, all_ids));
  END IF;
  RETURN pg_temp.mask_secrets(pg_temp.mask_tokens(v, ARRAY['host','path']));
END $$;

UPDATE pg_get_confs
   SET setting = pg_temp.mask_conf(name, setting),
       source  = pg_temp.mask_tokens(source, ARRAY['db','role','schema','tblspc','app','host','path']);

UPDATE pg_get_file_confs
   SET setting    = pg_temp.mask_conf(name, setting),
       sourcefile = pg_temp.mask_tokens(sourcefile, ARRAY['db','role','schema','tblspc','app','host','path']),
       error      = pg_temp.mask_tokens(error, ARRAY['db','role','host','path']);

\echo Masking connection info (pg_srvr)...

-- Old format:  You are connected to database "x" as user "y" on host "h" (address "a") at port "p".
-- PG18 format: one "Parameter|Value" line per row
UPDATE pg_srvr
   SET connstr = CASE
         WHEN connstr LIKE '%|%' THEN
           trim(split_part(connstr, '|', 1)) || '|' ||
           CASE trim(split_part(connstr, '|', 1))
             WHEN 'Database'         THEN pg_temp.mask_val(trim(split_part(connstr, '|', 2)), 'db')
             WHEN 'Client User'      THEN pg_temp.mask_val(trim(split_part(connstr, '|', 2)), 'role')
             WHEN 'Host'             THEN pg_temp.mask_val(lower(trim(split_part(connstr, '|', 2))), 'host')
             WHEN 'Host Address'     THEN pg_temp.mask_val(lower(trim(split_part(connstr, '|', 2))), 'host')
             WHEN 'Server Address'   THEN pg_temp.mask_val(lower(trim(split_part(connstr, '|', 2))), 'host')
             WHEN 'Socket Directory' THEN pg_temp.mask_tokens(trim(split_part(connstr, '|', 2)), ARRAY['path'])
             WHEN 'Options'          THEN pg_temp.mask_secrets(trim(split_part(connstr, '|', 2)))
             ELSE trim(substr(connstr, strpos(connstr, '|') + 1))
           END
         ELSE pg_temp.mask_conninfo_line(connstr)
       END;

\echo Masking SQL text (this can take a while on big pg_stat_statements)...

UPDATE pg_get_activity  SET query = pg_temp.mask_query(query) WHERE query IS NOT NULL AND query <> '';
UPDATE pg_get_statements SET query = pg_temp.mask_query(query) WHERE query IS NOT NULL AND query <> '';

-- ---------------------------------------------------------------------------
-- 3. Leak check: any original value still present in a text column?
-- ---------------------------------------------------------------------------
\echo Leak check (rows below mean an original value is still visible somewhere):

CREATE TEMP TABLE mask_leak_src AS
          SELECT 'pg_srvr' src, connstr txt FROM pg_srvr
UNION ALL SELECT 'pg_gather', concat_ws(' ', usr, db, host(client), host(server), bindir) FROM pg_gather
UNION ALL SELECT 'pg_get_confs:' || name, setting FROM pg_get_confs
UNION ALL SELECT 'pg_get_file_confs:' || name, concat_ws(' ', sourcefile, setting, error) FROM pg_get_file_confs
UNION ALL SELECT 'pg_get_db_role_confs', config::text FROM pg_get_db_role_confs
UNION ALL SELECT 'pg_get_roles', concat_ws(' ', rolname, rolconfig::text) FROM pg_get_roles
UNION ALL SELECT 'pg_get_hba_rules', concat_ws(' ', db::text, usr::text, addr, err) FROM pg_get_hba_rules
UNION ALL SELECT 'pg_get_activity', concat_ws(' ', application_name, host(client_addr), client_hostname) FROM pg_get_activity
UNION ALL SELECT 'pg_replication_stat', concat_ws(' ', usename, client_addr, client_hostname) FROM pg_replication_stat
UNION ALL SELECT 'pg_get_db', datname FROM pg_get_db
UNION ALL SELECT 'pg_get_ns', nsname FROM pg_get_ns
UNION ALL SELECT 'pg_get_slots', slot_name FROM pg_get_slots
UNION ALL SELECT 'pg_get_tablespace', concat_ws(' ', tsname, location) FROM pg_get_tablespace;

\pset footer off
SELECT m.kind, m.old AS original_value, l.src AS still_found_in, count(*) AS rows
  FROM mask_map m
  JOIN mask_leak_src l
    ON length(m.old) >= 3
   AND l.txt ~* ('(^|[^A-Za-z0-9_])' || pg_temp.re_esc(m.old) || '($|[^A-Za-z0-9_])')
 WHERE m.old <> m.new
 GROUP BY 1, 2, 3
 ORDER BY 1, 2, 3;
\pset footer on

SELECT kind, count(*) AS masked_values FROM mask_map GROUP BY kind ORDER BY kind;

\if :{?show_map}
  \echo '*** Mapping old -> new (keep it private, do not share) ***'
  SELECT kind, old, new FROM mask_map ORDER BY kind, new;
\endif

COMMIT;
\echo Done. Generate the report with: psql -X -f gather_report.sql > GatherReport.html
