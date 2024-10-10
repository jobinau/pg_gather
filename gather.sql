---- pg_gather : Gather Performance Metics and PostgreSQL Configuration
---- For Revision History : https://github.com/jobinau/pg_gather/releases
\echo '--**** THIS IS A TSV FORMATED FILE. PLEASE DONT COPY-PASTE OR SAVE USING TEXT EDITORS. Because formatting can be lost and file becomes corrupt  ****--'
\echo '\\r'
\set ver 28
\echo '\\set ver ':ver
--Detect PG versions and type of gathering
SELECT ( :SERVER_VERSION_NUM > 120000 ) AS pg12, ( :SERVER_VERSION_NUM > 130000 ) AS pg13, ( :SERVER_VERSION_NUM > 140000 ) AS pg14, ( :SERVER_VERSION_NUM >= 160000 ) AS pg16, ( :SERVER_VERSION_NUM >= 170000 ) AS pg17, ( current_database() != 'template1' ) as fullgather \gset

\if :fullgather
---Error out and exit, unless healthy
\echo 'SELECT (SELECT count(*) > 1 FROM pg_srvr) AS conlines \\gset'
\echo '\\if :conlines'
\echo '\\echo SOMETHING WRONG, EXITING'
\echo 'SOMETHING WRONG, EXITING;'
\echo '\\q'
\echo '\\endif'
--PG Server
\echo COPY pg_srvr FROM stdin;
\conninfo
\echo '\\.'
\endif

---Option for passing parameters
--\if :{?FULL}
--\else
--    \set FULL true
--\endif

\set QUIET on
SET statement_timeout=180000;
\t on
\x off
PREPARE pidevents AS
SELECT pid || E'\t' || COALESCE(wait_event,'\N') FROM pg_stat_get_activity(NULLIF(pg_sleep(0.01)::text,'')::INT) WHERE (state != 'idle' OR state IS NULL) AND pid != pg_backend_pid();
\a
\set QUIET off
\echo '\\t'
\echo '\\r'

\if :{?ERROR}
\set ERROR true
\echo COPY pg_gather (collect_ts,usr,db,ver,pg_start_ts,recovery,client,server,reload_ts,timeline,systemid,snapshot,current_wal) FROM stdin;
COPY (SELECT current_timestamp,current_user||' - pg_gather.V'||:ver ,current_database(),version(),pg_postmaster_start_time(),pg_is_in_recovery(),inet_client_addr(),inet_server_addr(),pg_conf_load_time(),(SELECT timeline_id FROM pg_control_checkpoint()) as timeline, (SELECT system_identifier FROM pg_control_system()) as systemid, txid_current_snapshot(), CASE WHEN pg_is_in_recovery() THEN pg_last_wal_receive_lsn() ELSE pg_current_wal_lsn() END) TO stdout; 
\if :ERROR
COPY (SELECT current_timestamp,current_user||' - pg_gather.V'||:ver ,current_database(),version(),pg_postmaster_start_time(),pg_is_in_recovery(),inet_client_addr(),inet_server_addr(),pg_conf_load_time(),(SELECT timeline_id FROM pg_control_checkpoint()) as timeline, (SELECT system_identifier FROM pg_control_system()) as systemid, txid_current_snapshot(), NULL ) TO stdout; 
\endif
\else
do $$ BEGIN  RAISE '***** FATAL : MINIMUM PSQL VERSION 11 IS EXPECTED : PLEASE VERIFY : psql --version ********'; END; $$;
\q
\endif
\echo '\\.'

\if :pg16
   \echo COPY pg_get_activity (datid, pid ,usesysid ,application_name ,state ,query ,wait_event_type ,wait_event ,xact_start ,query_start ,backend_start ,state_change ,client_addr, client_hostname, client_port, backend_xid ,backend_xmin, backend_type,ssl ,sslversion ,sslcipher ,sslbits ,ssl_client_dn ,ssl_client_serial,ssl_issuer_dn ,gss_auth,gss_princ ,gss_enc,gss_delegation,leader_pid,query_id) FROM stdin;
\elif :pg14
    \echo COPY pg_get_activity (datid, pid ,usesysid ,application_name ,state ,query ,wait_event_type ,wait_event ,xact_start ,query_start ,backend_start ,state_change ,client_addr, client_hostname, client_port, backend_xid ,backend_xmin, backend_type,ssl ,sslversion ,sslcipher ,sslbits ,ssl_client_dn ,ssl_client_serial,ssl_issuer_dn ,gss_auth ,gss_princ ,gss_enc,leader_pid,query_id) FROM stdin;
\elif :pg13
    \echo COPY pg_get_activity (datid, pid ,usesysid ,application_name ,state ,query ,wait_event_type ,wait_event ,xact_start ,query_start ,backend_start ,state_change ,client_addr, client_hostname, client_port, backend_xid ,backend_xmin, backend_type,ssl ,sslversion ,sslcipher ,sslbits ,sslcompression ,ssl_client_dn ,ssl_client_serial,ssl_issuer_dn ,gss_auth ,gss_princ ,gss_enc,leader_pid) FROM stdin;
\elif :pg12
    \echo COPY pg_get_activity (datid, pid ,usesysid ,application_name ,state ,query ,wait_event_type ,wait_event ,xact_start ,query_start ,backend_start ,state_change ,client_addr, client_hostname, client_port, backend_xid ,backend_xmin, backend_type,ssl ,sslversion ,sslcipher ,sslbits ,sslcompression ,ssl_client_dn ,ssl_client_serial,ssl_issuer_dn ,gss_auth ,gss_princ ,gss_enc) FROM stdin;
\else
    \echo COPY pg_get_activity (datid, pid ,usesysid ,application_name ,state ,query ,wait_event_type ,wait_event ,xact_start ,query_start ,backend_start ,state_change ,client_addr, client_hostname, client_port, backend_xid ,backend_xmin, backend_type,ssl ,sslversion ,sslcipher ,sslbits ,sslcompression ,ssl_client_dn ) FROM stdin;
\endif
\copy (select * from  pg_stat_get_activity(NULL) where pid != pg_backend_pid()) to stdin
\echo '\\.'

\o /dev/null
SELECT 'EXECUTE pidevents;' FROM generate_series(1,1000) g;
\o
\echo COPY pg_pid_wait (pid,wait_event) FROM stdin;
\gexec
\echo '\\.'

--Database level info
\echo COPY pg_get_db (datid,datname,xact_commit,xact_rollback,blks_fetch,blks_hit,tup_returned,tup_fetched,tup_inserted,tup_updated,tup_deleted,temp_files,temp_bytes,deadlocks,blk_read_time,blk_write_time,db_size,age,mxidage,stats_reset) FROM stdin;
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
pg_database_size(d.oid) AS db_size, age(datfrozenxid), mxid_age(datminmxid),
pg_stat_get_db_stat_reset_time(d.oid) AS stats_reset
FROM pg_database d) TO stdin;
\echo '\\.'

--Source of top statement is unknown now
\set stmnt N

--Starting fullgather section
\if :fullgather

--Users / Roles, 
\echo COPY pg_get_roles(oid,rolname,rolsuper,rolreplication,rolconnlimit,enc_method) FROM stdin;
COPY (SELECT oid,rolname,rolsuper,rolreplication,rolconnlimit,left(rolpassword,1) enc_method from pg_authid WHERE rolcanlogin) TO stdout;
\if :ERROR
COPY (SELECT oid,rolname,rolsuper,rolreplication,rolconnlimit,NULL FROM pg_roles WHERE rolcanlogin) TO stdout;
\endif
\echo '\\.'

--pg_settings
\echo COPY pg_get_confs (name,setting,unit,source) FROM stdin;
COPY ( SELECT name,setting,unit,coalesce(sourcefile,source) FROM pg_settings) TO stdin;
\echo '\\.'

--pg_file_settings
\echo COPY pg_get_file_confs (sourcefile,name,setting,applied,error) FROM stdin;
COPY ( SELECT sourcefile,name,setting,applied,error FROM pg_file_settings) TO stdin;
\echo '\\.'

--pg_db_role_setting
\echo COPY pg_get_db_role_confs (db,setrole,config) FROM stdin;
COPY ( SELECT setdatabase,setrole,setconfig FROM pg_db_role_setting) TO stdin;
\echo '\\.'

--Major tables and indexes in current db
\echo COPY pg_get_class (reloid,relname,relkind,relnamespace,relfilenode,reltablespace,relpersistence,reloptions,blocks_fetched,blocks_hit) FROM stdin;
COPY (SELECT oid,relname,relkind,relnamespace,relfilenode,reltablespace,relpersistence,reloptions,pg_stat_get_blocks_fetched(oid),pg_stat_get_blocks_hit(oid) FROM pg_class WHERE relnamespace NOT IN (SELECT oid FROM pg_namespace WHERE nspname in ('pg_catalog','information_schema'))) TO stdin;
\echo '\\.'

--Index info
\if :pg16
\echo COPY pg_get_index(indexrelid,indrelid,indisunique,indisprimary,indisvalid,numscans,size,lastuse) FROM stdin;
COPY (SELECT indexrelid,indrelid,indisunique,indisprimary,indisvalid, pg_stat_get_numscans(indexrelid),pg_table_size(indexrelid),pg_stat_get_lastscan(indexrelid) from pg_index) TO stdin;
\else
\echo COPY pg_get_index(indexrelid,indrelid,indisunique,indisprimary,indisvalid,numscans,size) FROM stdin;
COPY (SELECT indexrelid,indrelid,indisunique,indisprimary,indisvalid, pg_stat_get_numscans(indexrelid),pg_table_size(indexrelid) from pg_index) TO stdin;
\endif
\echo '\\.'

--Table Info
\if :pg16
\echo COPY pg_get_rel (relid,relnamespace,blks,n_live_tup,n_dead_tup,n_tup_ins,n_tup_upd,n_tup_del,n_tup_hot_upd,rel_size,tot_tab_size,tab_ind_size,rel_age,last_vac,last_anlyze,vac_nos,lastuse) FROM stdin;
COPY (select oid,relnamespace, relpages::bigint blks,pg_stat_get_live_tuples(oid) AS n_live_tup,pg_stat_get_dead_tuples(oid) AS n_dead_tup,
   pg_stat_get_tuples_inserted(oid) n_tup_ins, pg_stat_get_tuples_updated(oid) n_tup_upd, pg_stat_get_tuples_deleted(oid) n_tup_del, pg_stat_get_tuples_hot_updated(oid) n_tup_hot_upd,
   pg_relation_size(oid) rel_size,  pg_table_size(oid) tot_tab_size, pg_total_relation_size(oid) tab_ind_size, age(relfrozenxid) rel_age,
   GREATEST(pg_stat_get_last_autovacuum_time(oid),pg_stat_get_last_vacuum_time(oid)), GREATEST(pg_stat_get_last_autoanalyze_time(oid),pg_stat_get_last_analyze_time(oid)),
 pg_stat_get_vacuum_count(oid)+pg_stat_get_autovacuum_count(oid),pg_stat_get_lastscan(oid)
 FROM pg_class WHERE relkind in ('r','t','p','m','')) TO stdin;
\else
\echo COPY pg_get_rel (relid,relnamespace,blks,n_live_tup,n_dead_tup,n_tup_ins,n_tup_upd,n_tup_del,n_tup_hot_upd,rel_size,tot_tab_size,tab_ind_size,rel_age,last_vac,last_anlyze,vac_nos) FROM stdin;
COPY (select oid,relnamespace, relpages::bigint blks,pg_stat_get_live_tuples(oid) AS n_live_tup,pg_stat_get_dead_tuples(oid) AS n_dead_tup,
   pg_stat_get_tuples_inserted(oid) n_tup_ins, pg_stat_get_tuples_updated(oid) n_tup_upd, pg_stat_get_tuples_deleted(oid) n_tup_del, pg_stat_get_tuples_hot_updated(oid) n_tup_hot_upd,
   pg_relation_size(oid) rel_size,  pg_table_size(oid) tot_tab_size, pg_total_relation_size(oid) tab_ind_size, age(relfrozenxid) rel_age,
   GREATEST(pg_stat_get_last_autovacuum_time(oid),pg_stat_get_last_vacuum_time(oid)), GREATEST(pg_stat_get_last_autoanalyze_time(oid),pg_stat_get_last_analyze_time(oid)),
 pg_stat_get_vacuum_count(oid)+pg_stat_get_autovacuum_count(oid)
 FROM pg_class WHERE relkind in ('r','t','p','m','')) TO stdin;
\endif
\echo '\\.'

--Tablespace info
\echo COPY pg_get_tablespace(tsoid,tsname,location) FROM stdin;
COPY (SELECT oid,spcname,pg_tablespace_location(oid) FROM pg_tablespace WHERE oid > 16384) TO stdout;
\echo '\\.'

--Bloat estimate on a 64bit machine with PG version above 9.0.
\echo COPY pg_tab_bloat(table_oid,est_pages) FROM stdin;
COPY ( SELECT
table_oid, 
--cc.relname AS tablename, cc.relpages,
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
) TO stdout;
\echo '\\.'

--TOAST info
\echo COPY pg_get_toast FROM stdin;
COPY (SELECT oid, reltoastrelid FROM pg_class WHERE reltoastrelid != 0 ) TO stdout;
\echo '\\.'

--Partitioning
\echo COPY pg_get_inherits (inhrelid,inhparent) FROM stdin;
COPY (SELECT inhrelid,inhparent FROM pg_inherits) TO stdout;
\echo '\\.'

--namespaces/schemas
\echo COPY pg_get_ns(nsoid,nsname) FROM stdin;
COPY (SELECT oid,nspname FROM pg_namespace) TO stdout;
\echo '\\.'

--Extensions present
\echo COPY pg_get_extension FROM stdin;
COPY (select oid,extname,extowner,extnamespace,extrelocatable,extversion from pg_extension) TO stdout;
\echo '\\.'

--Check for extensions like pg_stat_statements and pg_stat_monitor
SELECT count(*) FILTER (WHERE extname='pg_stat_statements') > 0 AS pgss,count(*) FILTER (WHERE extname='pg_stat_monitor') > 0 AS pgsm FROM pg_extension \gset
\if :pgss
    \set stmnt S
    \echo COPY pg_get_statements (userid,dbid,query,calls,total_time,shared_blks_hit,shared_blks_read,shared_blks_dirtied,shared_blks_written,temp_blks_read,temp_blks_written) FROM stdin;
\if :pg13
    COPY (SELECT userid,dbid,query,calls,total_plan_time+total_exec_time "total_time",shared_blks_hit,shared_blks_read,shared_blks_dirtied,shared_blks_written,temp_blks_read,temp_blks_written FROM pg_stat_statements WHERE calls > 5 AND not upper(query) like any (array['DEALLOCATE%', 'SET %', 'RESET %', 'BEGIN%', 'BEGIN;','COMMIT%', 'END%', 'ROLLBACK%', 'SHOW%'])) TO stdout;
\else
    COPY (SELECT userid,dbid,query,calls,total_time,shared_blks_hit,shared_blks_read,shared_blks_dirtied,shared_blks_written,temp_blks_read,temp_blks_written FROM pg_stat_statements WHERE calls > 5 AND not upper(query) like any (array['DEALLOCATE%', 'SET %', 'RESET %', 'BEGIN%', 'BEGIN;',    'COMMIT%', 'END%', 'ROLLBACK%', 'SHOW%'])) TO stdout;
\endif
\echo '\\.'
\elif :pgsm
\if :pg13
 \set stmnt M
 \echo COPY pg_get_statements (userid,dbid,query,calls,total_time,shared_blks_hit,shared_blks_read,shared_blks_dirtied,shared_blks_written,temp_blks_read,temp_blks_written) FROM stdin;
 COPY ( SELECT userid,dbid,max(query) query,sum(calls) calls,sum(total_plan_time+total_exec_time) "total_time"
 ,sum(shared_blks_hit) shared_blks_hit,sum(shared_blks_read) shared_blks_read,sum(shared_blks_dirtied) shared_blks_dirtied
 ,sum(shared_blks_written) shared_blks_written,sum(temp_blks_read) temp_blks_read,sum(temp_blks_written) temp_blks_written
 FROM pg_stat_monitor WHERE not upper(query) like any (array['DEALLOCATE%', 'SET %', 'RESET %', 'BEGIN%', 'BEGIN;','COMMIT%', 'END%', 'ROLLBACK%', 'SHOW%'])
 GROUP BY queryid,1,2 ) TO stdout;
 \echo '\\.'
\endif
\endif

--pg_hba rules
\echo COPY pg_get_hba_rules(seq,typ,db,usr,addr,mask,method,err) FROM stdin;
COPY (select line_number,type,database,user_name,address,netmask,auth_method,error from pg_hba_file_rules) TO stdout;
\echo '\\.'

--pg_prepared_xacts
\echo COPY pg_get_prep_xacts(txn,gid,prepared) FROM stdin;
COPY (select transaction,gid,prepared FROM pg_prepared_xact()) TO stdout;
\echo '\\.'

--End fullgather, started before pg_get_roles (line: 102)
\endif

--Lock chain info
\echo COPY pg_get_pidblock(victim_pid,blocking_pids) FROM stdin;
COPY (SELECT pid,pg_blocking_pids(pid) FROM pg_stat_get_activity(NULL) WHERE wait_event_type = 'Lock') TO stdout;
\echo '\\.'

--Replication status
--TODO replace with pg_stat_get_wal_senders()
\echo COPY pg_replication_stat(usename,client_addr,client_hostname, pid, state,sent_lsn,write_lsn,flush_lsn,replay_lsn,sync_state) FROM stdin;
COPY ( SELECT usename, client_addr, client_hostname, pid, state, sent_lsn, write_lsn, flush_lsn, replay_lsn, sync_state  FROM pg_stat_replication ) TO stdin;
\echo '\\.'

--Slot status
\echo COPY pg_get_slots(slot_name, plugin, slot_type, datoid, temporary, active,  active_pid, old_xmin, catalog_xmin, restart_lsn, confirmed_flush_lsn) FROM stdin;
COPY ( SELECT slot_name, plugin, slot_type, datoid, temporary, active, active_pid, xmin, catalog_xmin, restart_lsn, confirmed_flush_lsn  FROM pg_get_replication_slots()) TO stdout;
\echo '\\.'

--Archive status
\echo COPY pg_archiver_stat FROM stdin;
COPY (
select archived_count,last_archived_wal,last_archived_time,last_failed_wal,last_failed_time from pg_stat_archiver
) TO stdin;
\echo '\\.'


--WAL stats
\if :pg14
\echo COPY pg_get_wal(wal_records,wal_fpi,wal_bytes,wal_buffers_full,wal_write,wal_sync,wal_write_time,wal_sync_time,stats_reset) FROM stdin;
COPY (SELECT wal_records,wal_fpi,wal_bytes,wal_buffers_full,wal_write,wal_sync,wal_write_time,wal_sync_time,stats_reset FROM pg_stat_wal) TO stdout;
\echo '\\.'
\endif

--bgwriter
\echo COPY pg_get_bgwriter FROM stdin;
\if :pg17
COPY (SELECT pg_stat_get_checkpointer_num_timed(),pg_stat_get_checkpointer_num_requested(),pg_stat_get_checkpointer_write_time(),pg_stat_get_checkpointer_sync_time(),
pg_stat_get_checkpointer_buffers_written(),pg_stat_get_bgwriter_buf_written_clean(),pg_stat_get_bgwriter_maxwritten_clean(),NULL,NULL,pg_stat_get_buf_alloc(),pg_stat_get_bgwriter_stat_reset_time()) TO stdout;
\else
COPY ( SELECT * FROM pg_stat_bgwriter ) TO stdout;
\endif
\echo '\\.'

--IO stats
\if :pg16
\echo COPY pg_get_io(btype,obj,context,reads,read_time,writes,write_time,writebacks,writeback_time,extends,extend_time,op_bytes,hits,evictions,reuses,fsyncs,fsync_time,stats_reset) FROM stdin;
COPY ( SELECT CASE backend_type WHEN 'background writer' THEN 'G' WHEN 'checkpointer' THEN 'k' ELSE left(backend_type,1) END btype, left(object,1) obj,
CASE context WHEN 'bulkread' THEN 'R' WHEN 'bulkwrite' THEN 'W' ELSE left(context,1) END context,
reads,read_time,writes,write_time,writebacks,writeback_time,extends,extend_time,op_bytes,hits,evictions,reuses,fsyncs,fsync_time,stats_reset
FROM pg_stat_io WHERE backend_type NOT LIKE 's%'
) TO stdout;
\echo '\\.'
\endif

--Active session (again)
\o /dev/null
SELECT 'EXECUTE pidevents;' FROM generate_series(1,1000) g;
\o
\echo COPY pg_pid_wait (pid,wait_event) FROM stdin;
\gexec
\echo '\\.'

--End Marker
\echo COPY pg_gather_end(end_ts,end_lsn,stmnt) FROM stdin;
COPY ( SELECT current_timestamp,
  CASE WHEN pg_is_in_recovery() THEN pg_last_wal_receive_lsn() ELSE pg_current_wal_lsn() END,:'stmnt'::char
) TO stdin;
\echo '\\.\n'
