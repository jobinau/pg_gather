---- pg_gather : Gather Performance Metics and PostgreSQL Configuration
---- Version 2 for PG 10,11,12 - 25 - Jan -2021 
---- Version 3 Supporting PG 13 - 06 - Feb -2021
---- Version 4 Bug fixes and Report enhacements
---- Version 5 Force exit if not healthy

---Error out and exit, unless healthy
\echo 'SELECT (SELECT count(*) > 1 FROM pg_srvr) AS conlines \\gset'
\echo '\\if :conlines'
\echo '\\echo SOMETHING WRONG, EXITING'
\echo 'SOMETHING WRONG, EXITING;'
\echo '\\q'
\echo '\\endif'

\pset tuples_only
\echo '\\t'
\echo '\\r'

--PG Server
\echo COPY pg_srvr FROM stdin;
\conninfo
\echo '\\.'

\echo COPY pg_gather FROM stdin;
COPY (SELECT current_timestamp,current_user,current_database(),version(),pg_postmaster_start_time(),pg_is_in_recovery(),inet_client_addr(),inet_server_addr(),pg_conf_load_time(),pg_current_wal_lsn()) TO stdin;
\echo '\\.'

--Activity information based on PG versions
SELECT ( :SERVER_VERSION_NUM > 120000 ) AS pg12, ( :SERVER_VERSION_NUM > 130000 ) AS pg13 \gset
\if :pg13
    \echo COPY pg_get_activity (datid, pid ,usesysid ,application_name ,state ,query ,wait_event_type ,wait_event ,xact_start ,query_start ,backend_start ,state_change ,client_addr, client_hostname, client_port, backend_xid ,backend_xmin, backend_type,ssl ,sslversion ,sslcipher ,sslbits ,sslcompression ,ssl_client_dn ,ssl_client_serial,ssl_issuer_dn ,gss_auth ,gss_princ ,gss_enc,leader_pid) FROM stdin;
\elif :pg12
    \echo COPY pg_get_activity (datid, pid ,usesysid ,application_name ,state ,query ,wait_event_type ,wait_event ,xact_start ,query_start ,backend_start ,state_change ,client_addr, client_hostname, client_port, backend_xid ,backend_xmin, backend_type,ssl ,sslversion ,sslcipher ,sslbits ,sslcompression ,ssl_client_dn ,ssl_client_serial,ssl_issuer_dn ,gss_auth ,gss_princ ,gss_enc) FROM stdin;
\else
    \echo COPY pg_get_activity (datid, pid ,usesysid ,application_name ,state ,query ,wait_event_type ,wait_event ,xact_start ,query_start ,backend_start ,state_change ,client_addr, client_hostname, client_port, backend_xid ,backend_xmin, backend_type,ssl ,sslversion ,sslcipher ,sslbits ,sslcompression ,ssl_client_dn ) FROM stdin;
\endif
\copy (select * from  pg_stat_get_activity(NULL) where pid != pg_backend_pid()) to stdin
\echo '\\.'


--INSERT statements
--SELECT 'SELECT pg_sleep(1);  SELECT ''INSERT INTO pg_get_wait VALUES (' || g ||',''|| pid || '','' || CASE WHEN wait_event IS NULL THEN ''NULL);'' ELSE ''''''''|| wait_event ||'''''');'' END  FROM pg_stat_activity WHERE state != ''idle'';' FROM generate_series(1,10) g;
--\gexec
-- SELECT pg_stat_get_backend_pid(s.backendid) AS pid, pg_stat_get_backend_wait_event(s.backendid) AS wait_event FROM (SELECT pg_stat_get_backend_idset() AS backendid) AS s WHERE pg_stat_get_backend_pid(s.backendid) is not null;

--\echo COPY pg_get_wait (itr,pid,wait_event) FROM stdin;
--SELECT 'SELECT pg_sleep(1);  SELECT ''' || g ||'''||E''\t''|| pid || E''\t'' || CASE WHEN wait_event IS NULL THEN ''\N'' ELSE  wait_event END  FROM pg_stat_get_activity(NULL) WHERE state != ''idle'';' FROM generate_series(1,10) g;
--\gexec
--\echo '\\.'
--\a

--Wait Event Analysis
--A much lightweight implimentation 26/12/2020
\a
PREPARE pidevents AS
SELECT pid || E'\t' || wait_event FROM pg_stat_activity WHERE state != 'idle' and pid != pg_backend_pid();
--SELECT pg_stat_get_backend_pid(s.backendid) || E'\t' || pg_stat_get_backend_wait_event(s.backendid) FROM (SELECT pg_stat_get_backend_idset() AS backendid) AS s WHERE pg_stat_get_backend_wait_event(s.backendid) NOT IN ('AutoVacuumMain','LogicalLauncherMain');
\echo COPY pg_pid_wait (pid,wait_event) FROM stdin;
SELECT 'SELECT pg_sleep(0.01); EXECUTE pidevents;' FROM generate_series(1,1000) g;
\gexec
\echo '\\.'
\a

--pg_stat_statements
SELECT (select count(*) > 0 from pg_class where relname='pg_stat_statements') AS pg_stmnt \gset
\if :pg_stmnt
    \echo COPY pg_get_statements (userid,dbid,query,calls,total_time) FROM stdin;
\if :pg13
    \COPY (SELECT userid,dbid,query,calls,total_plan_time+total_exec_time "total_time" from pg_stat_statements) TO stdout;
\else
    \COPY (SELECT userid,dbid,query,calls,total_time from pg_stat_statements) TO stdout;
\endif
    \echo '\\.'
\endif

--Database level info
\echo COPY pg_get_db (datid,datname,xact_commit,xact_rollback,blks_fetch,blks_hit,tup_returned,tup_fetched,tup_inserted,tup_updated,tup_deleted,temp_files,temp_bytes,deadlocks,blk_read_time,blk_write_time,db_size,age) FROM stdin;
COPY (SELECT d.oid, d.datname, 
pg_stat_get_db_xact_commit(d.oid) AS xact_commit,
pg_stat_get_db_xact_rollback(d.oid) AS xact_rollback,
pg_stat_get_db_blocks_fetched(d.oid) AS blks_fetch,
pg_stat_get_db_blocks_hit(d.oid) AS blks_hit,
pg_stat_get_db_tuples_returned(d.oid) AS tup_returned,
pg_stat_get_db_tuples_fetched(d.oid) AS tup_fetched,
pg_stat_get_db_tuples_inserted(d.oid) AS tup_inserted,
pg_stat_get_db_tuples_updated(d.oid) AS tup_updated,
pg_stat_get_db_tuples_deleted(d.oid) AS tup_deleted,
pg_stat_get_db_temp_files(d.oid) AS temp_files,
pg_stat_get_db_temp_bytes(d.oid) AS temp_bytes,
pg_stat_get_db_deadlocks(d.oid) AS deadlocks,
pg_stat_get_db_blk_read_time(d.oid) AS blk_read_time,
pg_stat_get_db_blk_write_time(d.oid) AS blk_write_time,
pg_database_size(d.oid) AS db_size, age(datfrozenxid)
FROM pg_database d) TO stdin;
\echo '\\.'

--pg_settings
\echo COPY pg_get_confs (name,setting,unit) FROM stdin;
COPY ( SELECT name,setting,unit FROM pg_settings ) TO stdin;
\echo '\\.'

--Major tables and indexes in current schema
\echo COPY pg_get_class FROM stdin;
COPY (SELECT oid,relname,relkind,relnamespace FROM pg_class WHERE relnamespace NOT IN (SELECT oid FROM pg_namespace WHERE nspname like 'pg%_temp_%' OR nspname in ('pg_catalog','information_schema'))) TO stdin;
\echo '\\.'

--Index usage info
\echo COPY pg_get_index FROM stdin;
COPY (SELECT indexrelid,indrelid,indisunique,indisprimary, pg_stat_get_numscans(indexrelid),pg_table_size(indexrelid) from pg_index) TO stdin;
\echo '\\.'

--Table usage Information
\echo COPY pg_get_rel FROM stdin;
COPY (select oid,relnamespace, relpages::bigint blks,pg_stat_get_live_tuples(oid) AS n_live_tup,pg_stat_get_dead_tuples(oid) AS n_dead_tup,
   pg_relation_size(oid) only_tab_size,  pg_table_size(oid) tot_tab_size, pg_total_relation_size(oid) "tot_tab+idx", age(relfrozenxid) rel_age,
   GREATEST(pg_stat_get_last_autovacuum_time(oid),pg_stat_get_last_vacuum_time(oid)),
   GREATEST(pg_stat_get_last_autoanalyze_time(oid),pg_stat_get_last_analyze_time(oid)),
 pg_stat_get_vacuum_count(oid)+pg_stat_get_autovacuum_count(oid)
 FROM pg_class WHERE relkind in ('r','t','p','m','')) TO stdin;
\echo '\\.'

--Blocking information
\echo COPY pg_get_block FROM stdin;
COPY (SELECT blocked_locks.pid  AS blocked_pid,
       blocked_activity.usename  AS blocked_user,
       blocked_activity.client_addr as blocked_client_addr,
       blocked_activity.client_hostname as blocked_client_hostname,
       blocked_activity.application_name as blocked_application_name,
       blocked_activity.wait_event_type as blocked_wait_event_type,
       blocked_activity.wait_event as blocked_wait_event,
       blocked_activity.query   AS blocked_statement,
       blocked_activity.xact_start AS blocked_xact_start,
       blocking_locks.pid  AS blocking_pid,
       blocking_activity.usename AS blocking_user,
       blocking_activity.client_addr as blocking_client_addr,
       blocking_activity.client_hostname as blocking_client_hostname,
       blocking_activity.application_name as blocking_application_name,
       blocking_activity.wait_event_type as blocking_wait_event_type,
       blocking_activity.wait_event as blocking_wait_event,
       blocking_activity.query AS current_statement_in_blocking_process,
       blocking_activity.xact_start AS blocking_xact_start
FROM  pg_catalog.pg_locks   blocked_locks
   JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
   JOIN pg_catalog.pg_locks         blocking_locks 
        ON blocking_locks.locktype = blocked_locks.locktype
        AND blocking_locks.DATABASE IS NOT DISTINCT FROM blocked_locks.DATABASE
        AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
        AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
        AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
        AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
        AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
        AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
        AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
        AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
        AND blocking_locks.pid != blocked_locks.pid
   JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted ORDER BY blocked_activity.pid ) TO stdin;
\echo '\\.'

--select * from pg_stat_replication;
\echo COPY pg_replication_stat FROM stdin;
COPY ( 
   SELECT usename, client_addr, client_hostname, state, sent_lsn, write_lsn, flush_lsn, replay_lsn, sync_state  FROM pg_stat_replication
) TO stdin;
\echo '\\.'

--Archive status
\echo COPY pg_archiver_stat FROM stdin;
COPY (
select archived_count,last_archived_wal,last_archived_time,last_failed_wal,last_failed_time from pg_stat_archiver
) TO stdin;
\echo '\\.'

--Bloat estimate on a 64bit machine with PG version above 9.0. 
\echo COPY pg_tab_bloat FROM stdin;
COPY ( SELECT
table_oid, cc.relname AS tablename, cc.relpages,
CEIL((cc.reltuples*((datahdr+ma- (CASE WHEN datahdr%ma=0 THEN ma ELSE datahdr%ma END))+nullhdr2+4))/(bs-20::float)) AS est_pages
FROM (
SELECT
    ma,bs,table_oid,
    (datawidth+(hdr+ma-(case when hdr%ma=0 THEN ma ELSE hdr%ma END)))::numeric AS datahdr,
    (maxfracsum*(nullhdr+ma-(case when nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2
FROM (
    SELECT s.starelid as table_oid ,23 AS hdr, 8 AS ma, 8192 AS bs, SUM((1-stanullfrac)*stawidth) AS datawidth, MAX(stanullfrac) AS maxfracsum,
    23 +( SELECT 1+count(*)/8  FROM pg_statistic s2 WHERE stanullfrac<>0 AND s.starelid = s2.starelid ) AS nullhdr
    FROM pg_statistic s 
    GROUP BY 1,2
) AS foo
) AS rs
JOIN pg_class cc ON cc.oid = rs.table_oid
JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname <> 'information_schema' 
) TO stdin;
\echo '\\.'

--Toast
\echo COPY pg_get_toast FROM stdin;
COPY (
SELECT oid, reltoastrelid FROM pg_class WHERE reltoastrelid != 0 ) TO stdin;
\echo '\\.'

--active session again
\a
\echo COPY pg_pid_wait (pid,wait_event) FROM stdin;
SELECT 'SELECT pg_sleep(0.01); EXECUTE pidevents;' FROM generate_series(1,1000) g;
\gexec
\echo '\\.'
\a