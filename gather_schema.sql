--Schema for pg_gather
\set QUIET 1
\echo **Dropping pg_gather tables**
set client_min_messages=ERROR;
DROP TABLE IF EXISTS pg_gather, pg_get_activity, pg_get_class, pg_get_confs, pg_get_file_confs, pg_get_db_role_confs, pg_get_db, pg_get_index,pg_get_tablespace, 
  pg_get_rel, pg_get_inherits, pg_srvr, pg_get_pidblock, pg_pid_wait, pg_replication_stat, pg_get_wal, pg_get_io, pg_archiver_stat, pg_tab_bloat, 
  pg_get_toast, pg_get_statements, pg_get_bgwriter, pg_get_roles, pg_get_extension, pg_get_slots, pg_get_hba_rules, pg_get_ns, pg_gather_end, pg_get_prep_xacts;

\echo **Creating pg_gather tables**
CREATE UNLOGGED TABLE pg_srvr (
    connstr text
);

CREATE UNLOGGED TABLE pg_gather (
    collect_ts timestamp with time zone,
    usr text,
    db text,
    ver text,
    pg_start_ts timestamp with time zone,
    recovery bool,
    client inet,
    server inet,
    reload_ts timestamp with time zone,
    timeline int,
    systemid bigint,
    snapshot pg_snapshot,
    current_wal pg_lsn
);

CREATE UNLOGGED TABLE pg_gather_end (
    end_ts timestamp with time zone,
    end_lsn pg_lsn,
    stmnt char
);

CREATE UNLOGGED TABLE pg_get_activity (
    datid oid, 
    pid integer,
    usesysid oid,
    application_name text,
    state text,
    query text,
    wait_event_type text,
    wait_event text,
    xact_start timestamp with time zone,
    query_start timestamp with time zone,
    backend_start timestamp with time zone,
    state_change timestamp with time zone,
    client_addr inet,
    client_hostname text,
    client_port integer,
    backend_xid xid,
    backend_xmin xid,
    backend_type text,
    ssl boolean,
    sslversion text,
    sslcipher text,
    sslbits integer,
    sslcompression boolean,
    ssl_client_dn text,
    ssl_client_serial numeric,
    ssl_issuer_dn text,
    gss_auth boolean,
    gss_princ text,
    gss_enc boolean,
    gss_delegation boolean,
    leader_pid integer,
    query_id bigint
);

CREATE UNLOGGED TABLE pg_get_statements(
    userid oid,
    dbid oid,
    query text,
    calls bigint,
    total_time double precision,
    shared_blks_hit bigint,
    shared_blks_read bigint,
    shared_blks_dirtied bigint,
    shared_blks_written bigint,
    temp_blks_read bigint,
    temp_blks_written bigint
);


CREATE UNLOGGED TABLE pg_pid_wait(
    itr SERIAL,
    pid integer,
    wait_event text
);


CREATE UNLOGGED TABLE pg_get_db (
    datid oid,
    datname text,
    xact_commit bigint,
    xact_rollback bigint,
    blks_fetch bigint,
    blks_hit bigint,
    tup_returned bigint,
    tup_fetched bigint,
    tup_inserted bigint,
    tup_updated bigint,
    tup_deleted bigint,
    temp_files bigint,
    temp_bytes bigint,
    deadlocks bigint,
    blk_read_time double precision,
    blk_write_time double precision,
    db_size bigint,
    age integer,
    mxidage integer,
    stats_reset timestamp with time zone
);

CREATE UNLOGGED TABLE pg_get_roles (
    oid oid,
    rolname text,
    rolsuper boolean,
    rolreplication boolean,
    rolconnlimit integer,
    rolconfig text[],  --remove this column, because we can derive info from pg_get_db_role_confs
    enc_method char
);

CREATE UNLOGGED TABLE pg_get_confs (
    name text,
    setting text,
    unit text,
    source text
);

CREATE UNLOGGED TABLE pg_get_file_confs (
    sourcefile text,
    name text,
    setting text,
    applied boolean,
    error text
);

CREATE UNLOGGED TABLE pg_get_db_role_confs( --pg_db_role_setting
    db oid,
    setrole oid,
    config text[]
);

CREATE UNLOGGED TABLE pg_get_class (
    reloid oid,
    relname text,
    relkind char(1),
    relnamespace oid,
    relfilenode oid,
    reltablespace oid,
    relpersistence char,
    reloptions text[],
    blocks_fetched bigint,
    blocks_hit bigint
);

CREATE UNLOGGED TABLE pg_get_tablespace(
    tsoid oid,
    tsname text,
    location text
);

CREATE UNLOGGED TABLE pg_get_inherits(
    inhrelid oid,
    inhparent oid
);

CREATE UNLOGGED TABLE pg_get_index (
    indexrelid oid,
    indrelid oid,
    indisunique boolean,
    indisprimary boolean,
    indisvalid boolean,
    numscans bigint,
    size bigint,
    lastuse timestamp with time zone
);
--indexrelid - oid of the index
--indrelid - oid of the corresponding table

CREATE UNLOGGED TABLE pg_get_rel (
    relid oid,
    relnamespace oid,
    blks bigint,
    n_live_tup bigint,
    n_dead_tup bigint,
    n_tup_ins bigint,
    n_tup_upd bigint,
    n_tup_del bigint,
    n_tup_hot_upd bigint,
    rel_size bigint,
    tot_tab_size bigint,
    tab_ind_size bigint,
    rel_age bigint,
    last_vac timestamp with time zone,
    last_anlyze timestamp with time zone,
    vac_nos bigint,
    lastuse timestamp with time zone,
    dpart char COLLATE "C"
);


CREATE UNLOGGED TABLE pg_get_pidblock(
  victim_pid int,
  blocking_pids int[]
);

--TODO : Username, client_addr and client_hostname should be removed on the long term
CREATE UNLOGGED TABLE pg_replication_stat (
    usename text,
    client_addr text,
    client_hostname text,
    pid int,
    state text,
    sent_lsn pg_lsn,
    write_lsn pg_lsn,
    flush_lsn pg_lsn,
    replay_lsn pg_lsn,
    sync_state text
);

CREATE UNLOGGED TABLE pg_archiver_stat(
    archived_count bigint,
    last_archived_wal text,
    last_archived_time timestamp with time zone,
    last_failed_wal text,
    last_failed_time timestamp with time zone
);


CREATE UNLOGGED TABLE pg_get_toast(
    relid oid,
    toastid oid
);


CREATE UNLOGGED TABLE pg_tab_bloat (
    table_oid oid,
    est_pages bigint
);

CREATE UNLOGGED TABLE pg_get_bgwriter(
    checkpoints_timed bigint,
    checkpoints_req  bigint,
    checkpoint_write_time double precision,
    checkpoint_sync_time double precision,
    buffers_checkpoint bigint,
    buffers_clean bigint,
    maxwritten_clean bigint,
    buffers_backend bigint,
    buffers_backend_fsync bigint,
    buffers_alloc bigint,
    stats_reset timestamp with time zone
);

CREATE UNLOGGED TABLE pg_get_extension(
    oid oid,
    extname text,
    extowner oid,
    extnamespace oid,
    extrelocatable boolean,
    extversion text
);

CREATE UNLOGGED TABLE pg_get_wal(
 wal_records bigint,
 wal_fpi bigint,
 wal_bytes numeric,
 wal_buffers_full bigint,
 wal_write bigint,   --Remove this column for PG18+
 wal_sync bigint,    --Remove this column for PG18+
 wal_write_time double precision, --Remove this column for PG18+
 wal_sync_time double precision, --Remove this column for PG18+
 stats_reset timestamp with time zone
);

CREATE UNLOGGED TABLE pg_get_io(
 btype char(1), -- 'background writer=G'
 obj char(1), -- 'bulkread=R, bulkwrite=W'
 context char(1),
 reads bigint,
 read_time float8,
 writes bigint,
 write_time float8,
 writebacks bigint,
 writeback_time float8,
 extends bigint,
 extend_time float8,
 op_bytes bigint,
 hits bigint,
 evictions bigint,
 reuses bigint,
 fsyncs bigint,
 fsync_time float8,
 stats_reset timestamptz
);

CREATE UNLOGGED TABLE pg_get_slots(
    slot_name text,
    plugin text,
    slot_type text,
    datoid oid,
    temporary bool,
    active bool,
    active_pid int,
    old_xmin xid,
    catalog_xmin xid,
    restart_lsn pg_lsn,
    confirmed_flush_lsn pg_lsn
);

CREATE UNLOGGED TABLE pg_get_hba_rules(
 seq int,
 typ text,
 db text[],
 usr text[],
 addr text,
 mask text,
 method text,
 err text
);

CREATE UNLOGGED TABLE pg_get_ns(
   nsoid oid,
   nsname text
);

CREATE UNLOGGED TABLE pg_get_prep_xacts(
 txn xid,
 gid text,
 prepared timestamptz
);

\set QUIET 0
