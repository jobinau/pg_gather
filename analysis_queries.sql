--1. What is idle in transaction sessions are doing.
SELECT 
--   pg_get_activity.pid,pg_get_activity.query,
   pg_pid_wait.wait_event,count(*) 
FROM pg_pid_wait
JOIN pg_get_activity ON pg_pid_wait.pid = pg_get_activity.pid
WHERE state='idle in transaction'
GROUP BY 1 ORDER BY 2;

--2.User, database, Active, Total connection (Need for pgbouncer setup)
SELECT 
rolname,datname,count(*) FILTER (WHERE state='active') as active,
count(*) FILTER (WHERE state='idle in transaction') as idle_in_transaction,
count(*) FILTER (WHERE state='idle') as idle,
count(*) 
FROM pg_get_activity 
  join pg_get_roles on usesysid=pg_get_roles.oid
  join pg_get_db on pg_get_activity.datid = pg_get_db.datid
GROUP BY ROLLUP(1,2)
ORDER BY 1,2;

--2.1 Details of a sessions
SELECT pid, rolname "user",datname "database",application_name,client_addr,backend_type,state_change
FROM pg_get_activity a 
  join pg_get_roles on a.usesysid=pg_get_roles.oid
  join pg_get_db on a.datid = pg_get_db.datid
WHERE true 
--Add custom filters and comment out what is not required
--AND PID=7494
AND backend_type = 'client backend' 
AND application_name NOT LIKE ALL (ARRAY['PostgreSQL JDBC Driver%','DBeaver%','pgAdmin%'])
AND rolname = 'pmmmaint'

--3.Which session is at the top of the blocking
SELECT blocking_pid,statement_in_blocking_process,count(*)
 FROM pg_get_block WHERE blocking_pid not in (SELECT blocked_pid FROM pg_get_block)
 GROUP by 1,2;

--4.Biggest Blockers
SELECT statement_in_blocking_process,count(*) FROM  pg_get_block GROUP BY 1 ORDER BY 2;

--5.What is the status of the blocking pids (This may not be accurate as there is 20 second time difference)
SELECT pid,state FROM pg_get_activity WHERE pid IN
(SELECT blocking_pid FROM (SELECT blocking_pid,statement_in_blocking_process,count(*)
 from pg_get_block WHERE blocking_pid not in (SELECT blocked_pid FROM pg_get_block)
 GROUP by 1,2) blockers);

--6.Wait event associated with blocking session (Important)
SELECT blocking_pid,blocking_wait_event,count(*)
 from pg_get_block WHERE blocking_pid not in (SELECT blocked_pid FROM pg_get_block)
 GROUP BY 1,2;


--7.TOP 5 Tables which require maximum maintenace memory
WITH top_tabs AS (SELECT relid,n_live_tup*0.2*6/1024/1024/1024 maint_work_mem_gb 
   from pg_get_rel ORDER BY 2 DESC LIMIT 5)
SELECT relid, relname,maint_work_mem_gb
 FROM top_tabs
 JOIN pg_get_class ON top_tabs.relid = pg_get_class.reloid
ORDER BY 3 DESC;

--8. Stats reset info.
SELECT datname,stats_reset FROM pg_get_db WHERE stats_reset is not null;
SELECT stats_reset FROM pg_get_bgwriter;

--9. Cache hit on databases
SELECT datname, 100 * blks_hit / blks_fetch as cache_hit_ratio FROM pg_get_db WHERE blks_fetch > 0;

--10. All table information
SELECT c.relname "Name",c.relkind "Kind",r.relnamespace "Schema",r.blks,r.n_live_tup "Live tup",r.n_dead_tup "Dead tup", CASE WHEN r.n_live_tup <> 0 THEN  ROUND((r.n_dead_tup::real/r.n_live_tup::real)::numeric,4) END "Dead/Live",
r.rel_size "Rel size",r.tot_tab_size "Tot.Tab size",r.tab_ind_size "Tab+Ind size",r.rel_age,r.last_vac "Last vacuum",r.last_anlyze "Last analyze",r.vac_nos,
ct.relname "Toast name",rt.tab_ind_size "Toast+Ind" ,rt.rel_age "Toast Age",GREATEST(r.rel_age,rt.rel_age) "Max age"
FROM pg_get_rel r
JOIN pg_get_class c ON r.relid = c.reloid AND c.relkind NOT IN ('t','p')
LEFT JOIN pg_get_toast t ON r.relid = t.relid
LEFT JOIN pg_get_class ct ON t.toastid = ct.reloid
LEFT JOIN pg_get_rel rt ON rt.relid = t.toastid
ORDER BY r.tab_ind_size DESC;

-- 11. All index information
SELECT ct.relname AS "Table", ci.relname as "Index",indisunique,indisprimary,numscans,size
  FROM pg_get_index i 
  JOIN pg_get_class ct on i.indrelid = ct.reloid and ct.relkind != 't'
  JOIN pg_get_class ci ON i.indexrelid = ci.reloid
ORDER BY size DESC;

-- 12. Compile time parameter changes
SELECT * FROM pg_get_confs cnf
JOIN
(VALUES ('block_size','8192'),('max_identifier_length','63'),('max_function_args','100'),('max_index_keys','32'),('segment_size','131072'),('wal_block_size','8192'),('wal_segment_size','16777216')) AS T (name,setting)
ON cnf.name = T.name and cnf.setting != T.setting;

--13. Tables without Primary key
SELECT ct.relname AS "Table", ct.relkind, ci.relname as "Index",indisunique,indisprimary,numscans,size
  FROM  pg_get_class ct 
  LEFT JOIN pg_get_index i on i.indrelid = ct.reloid and indisprimary = 't'
  LEFT JOIN pg_get_class ci ON  ci.reloid = i.indexrelid
WHERE ct.relkind not in  ('t','i','f','v','c')
AND ci.relname IS NULL;

-- 14. Unused Indexes bye comparing two snapshots
--Create a index history table using the data from the first pg_gather
CREATE TABLE pg_get_index_hist AS SELECT * FROM pg_get_index;
--Add the data from the second, thired pg_gather to it
INSERT INTO  pg_get_index_hist  SELECT * FROM pg_get_index;
--finally query the data
SELECT ct.relname AS "Table", ci.relname as "Index",minscan,maxscan
FROM
(SELECT indexrelid,indrelid,min(numscans) minscan,max(numscans) maxscan FROM pg_get_index_hist
WHERE indisprimary != true
GROUP BY indexrelid,indrelid) i
JOIN pg_get_class ct on i.indrelid = ct.reloid and ct.relkind != 't'
JOIN pg_get_class ci ON i.indexrelid = ci.reloid
WHERE maxscan-minscan = 0;

--15. WAL accumunation estimation due to WAL archive failure
SELECT pg_size_pretty(sz) FROM (
select  (
  (('x'||lpad(split_part(current_wal::TEXT,'/', 1),8,'0'))::bit(32)::bigint - ('x'||substring(last_archived_wal,9,8))::bit(32)::bigint) * 255 * 16^6 + 
  ('x'||lpad(split_part(current_wal::TEXT,'/', 2),8,'0'))::bit(32)::bigint - ('x'||substring(last_archived_wal,17,8))::bit(32)::bigint*16^6 
)::bigint
 as sz from pg_archiver_stat JOIN pg_gather ON TRUE
) a;

--16. FILLFACTOR recommendations - Statement generator
WITH  tabs AS 
(SELECT ns.nsname, c.relname , r.n_tup_ins, r.n_tup_upd, r.n_tup_del, r.n_tup_hot_upd
FROM pg_get_rel r
JOIN pg_get_class c ON r.relid = c.reloid AND c.relkind NOT IN ('t','p') AND r.n_tup_upd > 0
JOIN pg_get_ns ns ON r.relnamespace = ns.nsoid)
SELECT 'ALTER TABLE '||nsname||'.'||relname||' SET ( FILLFACTOR='|| 100 - 20*n_tup_upd/(n_tup_ins+n_tup_upd) + 20*n_tup_upd*n_tup_hot_upd/((n_tup_ins+n_tup_upd)*n_tup_upd) || ' );'
--, (20*n_tup_upd/(n_tup_ins+n_tup_upd) - 20*n_tup_upd*n_tup_hot_upd/((n_tup_ins+n_tup_upd)*n_tup_upd))
FROM tabs
WHERE (20*n_tup_upd/(n_tup_ins+n_tup_upd) - 20*n_tup_upd*n_tup_hot_upd/((n_tup_ins+n_tup_upd)*n_tup_upd)) > 1 ;

--17. Table level AUTOVACUUM recommendations
WITH curdb AS (SELECT trim(both '\"' from substring(connstr from '\"\w*\"')) "curdb" FROM pg_srvr WHERE connstr like '%to database%'),
    cts AS (SELECT COALESCE((SELECT COALESCE(collect_ts,(SELECT max(state_change) FROM pg_get_activity)) FROM pg_gather),current_timestamp) AS c_ts),
    tabs AS (SELECT ns.nsname, c.relname , r.n_tup_ins, r.n_tup_upd, r.n_tup_del, r.n_tup_hot_upd, r.vac_nos
           FROM pg_get_rel r
           JOIN pg_get_class c ON r.relid = c.reloid AND c.relkind NOT IN ('t','p') AND r.n_tup_upd > 0
           JOIN pg_get_ns ns ON r.relnamespace = ns.nsoid),
    curstatus AS (SELECT curdb,stats_reset,c_ts,days FROM 
    curdb LEFT JOIN pg_get_db ON pg_get_db.datname=curdb.curdb
    LEFT JOIN LATERAL (SELECT GREATEST((EXTRACT(epoch FROM(c_ts-stats_reset))/86400)::bigint,1) as days FROM cts) AS lat1 ON TRUE
    LEFT JOIN cts ON true)
SELECT 'ALTER TABLE '||nsname||'.'||relname||' SET ( autovacuum_vacuum_threshold='|| GREATEST(ROUND((n_tup_upd/curstatus.days + n_tup_del/curstatus.days)/48),500) ||', autovacuum_analyze_threshold='|| GREATEST(ROUND((n_tup_upd/curstatus.days + n_tup_del/curstatus.days)/48),500) || ' );'
FROM tabs JOIN curstatus ON TRUE
WHERE tabs.vac_nos/curstatus.days > 48;

--18. Oldest transactions which are still not completed
select pid,backend_xid::text::int from pg_get_activity order by 2;

--19. Partitioned tables and Indexes
SELECT c.relkind,p.relname, c.relname
FROM pg_get_inherits i
LEFT JOIN pg_get_class p ON i.inhparent = p.reloid
LEFT JOIN pg_get_class c ON i.inhrelid = c.reloid
ORDER BY 1,2;

--20. Invalid indexes
SELECT ind.relname index, indexrelid indexoid,tab.relname table ,indrelid tableoid 
FROM pg_get_index i
LEFT JOIN pg_get_class ind ON i.indexrelid = ind.reloid
LEFT JOIN pg_get_class tab ON i.indrelid = tab.reloid
WHERE i.indisvalid=false;

--21. User and database level parameters. In the decreasing order of priority
SELECT rolname,datname,setting,split_part(setting,'=',1) 
FROM pg_get_db_role_confs drc
LEFT JOIN LATERAL unnest(config) AS setting ON TRUE
LEFT JOIN pg_get_db db ON drc.db = db.datid
LEFT JOIN pg_get_roles rol ON rol.oid = drc.setrole
ORDER BY 1,2;


=======================HISTORY SCHEMA ANALYSIS=========================
set timezone=UTC;
SET timezone = '-7';
--Start and End time of data collection
SELECT min(collect_ts),max(collect_ts) FROM history.pg_get_activity ;
--min and max of a particular hour : WHERE DATE_TRUNC('hour',collect_ts) = '2022-01-03 18:00:00+00';

--Inspect the continuity of data collection, whether there is any gap
SELECT DATE_TRUNC('hour',collect_ts) date_hour,count(*) cnt FROM history.pg_get_activity GROUP BY DATE_TRUNC('hour',collect_ts) ORDER BY 1;

--Difference between collections
SELECT collect_ts,prev,collect_ts-prev FROM (
select collect_ts, lag(collect_ts,1) OVER (ORDER BY collect_ts) as prev from history.pg_gather) a;


---Load over a perioid of time
SELECT collect_ts,count(*) FILTER (WHERE state='active') as active,count(*) FILTER (WHERE state='idle in transaction') as idle_in_transaction,
count(*) FILTER (WHERE state='idle') as idle,count(*) connections  FROM history.pg_get_activity GROUP by collect_ts ORDER BY 2 DESC;
--Or use CAST(collect_ts as time) if data is for a single day

--Wait events between two periods
WITH w AS (SELECT collect_ts,COALESCE(wait_event,'CPU') as wait_event,count(*) cnt FROM history.pg_pid_wait GROUP BY 1,2 ORDER BY 1,2)
SELECT w.collect_ts,string_agg( w.wait_event ||':'|| w.cnt,',' ORDER BY w.cnt DESC) "wait events" 
FROM w 
WHERE w.collect_ts between '2022-01-03 16:46:01.213361+00' AND '2022-01-03 16:48:01.657648+00 '
GROUP BY w.collect_ts;

--Wait events over each data collection
WITH w AS (SELECT collect_ts,COALESCE(wait_event,'CPU') as wait_event,count(*) cnt FROM history.pg_pid_wait GROUP BY 1,2 ORDER BY 1,2)
SELECT w.collect_ts,string_agg( w.wait_event ||':'|| w.cnt,',' ORDER BY w.cnt DESC) "wait events" 
FROM w JOIN (SELECT collect_ts-'1 seconds'::interval start_tm , collect_ts+'1 seconds'::interval end_tm FROM history.pg_gather) tm
    ON w.collect_ts between tm.start_tm AND tm.end_tm
GROUP BY w.collect_ts ORDER BY w.collect_ts;


--Major wait events
SELECT COALESCE(wait_event,'CPU'),COUNT(*) FROM history.pg_pid_wait GROUP BY 1 ORDER BY 2;

--Dump wait events over a time to CSV format
psql "options='-c timezone=UTC'" -c "COPY (SELECT to_char(collect_ts,'YYYY-MM-DD HH24:MI'),COUNT(*) FROM history.pg_pid_wait WHERE wait_event='DataFileRead' GROUP BY 1 ORDER BY 1) TO stdout with CSV  DELIMITER ','" > datafileread.csv

--Session information
SELECT rolname,datname,state,count(*) from 
 history.pg_get_activity a 
 left join pg_get_roles r on a.usesysid = r.oid
 left join pg_get_db d USING (datid)
WHERE collect_ts between '2021-12-27 16:32:01' and '2021-12-27 16:36:01' GROUP BY rolname,datname,state
ORDER BY count(*);

--Top 5 active sessions
SELECT collect_ts,count(*) FROM history.pg_get_activity WHERE state='active' GROUP BY collect_ts ORDER BY count(*) DESC LIMIT 5;
--Idle in transactions
SELECT collect_ts,count(*) FROM history.pg_get_activity WHERE state like 'idle in transaction%' GROUP by collect_ts ORDER BY count(*) DESC LIMIT 5;

SELECT wait_event,count(*) FROM history.pg_pid_wait WHERE collect_ts='2021-06-28 14:02:01.324049+00'
 and pid in (SELECT pid FROM history.pg_get_activity WHERE collect_ts='2021-06-28 14:02:01.324049+00' and state like 'idle in transaction%')
GROUP BY wait_event;


SELECT distinct collect_ts FROM history.pg_get_activity WHERE collect_ts < '2021-07-18' ORDER BY 1;
SELECT 'DELETE FROM '||n.nspname||'.'||relname||' WHERE collect_ts < ''2021-07-18''' FROM pg_class c join pg_namespace n ON n.oid = c.relnamespace and n.nspname = 'history';


======= Import a particular snapshot from history and generate report.
TRUNCATE TABLE pg_gather;
TRUNCATE TABLE pg_get_activity;
TRUNCATE TABLE pg_pid_wait;
TRUNCATE TABLE pg_get_db;
TRUNCATE TABLE pg_get_block;
TRUNCATE TABLE pg_replication_stat;
TRUNCATE TABLE pg_archiver_stat;
TRUNCATE TABLE pg_get_bgwriter;


SET pg_gather.ts = '2022-04-12 16:48:01.721693+00';
INSERT INTO pg_gather SELECT collect_ts,usr,db,ver,pg_start_ts,recovery,client,server,reload_ts,current_wal FROM history.pg_gather where collect_ts = current_setting('pg_gather.ts')::timestamptz;
INSERT INTO pg_get_activity SELECT datid,pid,usesysid,application_name,state,query,wait_event_type,wait_event,xact_start,query_start,backend_start,state_change,
     client_addr,client_hostname,client_port,backend_xid,backend_xmin,backend_type,ssl,sslversion,sslcipher,sslbits,sslcompression,ssl_client_dn,ssl_client_serial,ssl_issuer_dn,gss_auth,gss_princ,gss_enc,leader_pid,query_id
     FROM history.pg_get_activity WHERE collect_ts = current_setting('pg_gather.ts')::timestamptz;
INSERT INTO pg_pid_wait SELECT itr,pid,wait_event FROM history.pg_pid_wait WHERE collect_ts = current_setting('pg_gather.ts')::timestamptz;
INSERT INTO pg_get_db SELECT datid,datname,xact_commit,xact_rollback,blks_fetch,blks_hit,tup_returned,tup_fetched,tup_inserted,tup_updated,tup_deleted,temp_files,temp_bytes,deadlocks,blk_read_time,blk_write_time,db_size,age,stats_reset 
     FROM history.pg_get_db WHERE collect_ts = current_setting('pg_gather.ts')::timestamptz;
INSERT INTO pg_get_block SELECT blocked_pid,blocked_user,blocked_client_addr,blocked_client_hostname,blocked_application_name,blocked_wait_event_type,blocked_wait_event,blocked_statement,blocked_xact_start,
    blocking_pid,blocking_user,blocking_user_addr,blocking_client_hostname,blocking_application_name,blocking_wait_event_type,blocking_wait_event,statement_in_blocking_process,blocking_xact_start
    FROM history.pg_get_block WHERE collect_ts = current_setting('pg_gather.ts')::timestamptz;
INSERT INTO pg_replication_stat SELECT usename,client_addr,client_hostname,state,sent_lsn,write_lsn,flush_lsn,replay_lsn,sync_state 
    FROM history.pg_replication_stat WHERE collect_ts = current_setting('pg_gather.ts')::timestamptz;
INSERT INTO pg_archiver_stat SELECT archived_count,last_archived_wal,last_archived_time,last_failed_wal,last_failed_time
    FROM history.pg_archiver_stat WHERE collect_ts = current_setting('pg_gather.ts')::timestamptz;
INSERT INTO pg_get_bgwriter SELECT checkpoints_timed,checkpoints_req,checkpoint_write_time,checkpoint_sync_time,buffers_checkpoint,buffers_clean,maxwritten_clean,
    buffers_backend,buffers_backend_fsync,buffers_alloc,stats_reset FROM history.pg_get_bgwriter WHERE collect_ts = current_setting('pg_gather.ts')::timestamptz;


--Compare autovacuum runs
ALTER TABLE pg_get_rel RENAME TO pg_get_rel_old;
ALTER TABLE pg_gather RENAME TO pg_gather_old;
select EXTRACT(EPOCH FROM ('2022-06-07 22:11:11'::timestamp - '2022-06-01 21:18:13'::timestamp))/86400;

SELECT c.relname "Name" ,
--r.relnamespace "Schema",r.n_live_tup "Live tup",r.n_dead_tup "Dead tup", CASE WHEN r.n_live_tup <> 0 THEN  ROUND((r.n_dead_tup::real/r.n_live_tup::real)::numeric,4) END "Dead/Live",
--r.rel_size "Rel size",r.tot_tab_size "Tot.Tab size",r.tab_ind_size "Tab+Ind size",r.rel_age,to_char(r.last_vac,'YYYY-MM-DD HH24:MI:SS') "Last vacuum",to_char(r.last_anlyze,'YYYY-MM-DD HH24:MI:SS') "Last analyze",
r.vac_nos - o.vac_nos "vacs", (r.vac_nos - o.vac_nos)/dys "vacs_day"
--ct.relname "Toast name",rt.tab_ind_size "Toast+Ind" ,rt.rel_age "Toast Age",GREATEST(r.rel_age,rt.rel_age) "Max age"
FROM pg_get_rel r
JOIN pg_get_rel_old o ON r.relid = o.relid
JOIN (SELECT EXTRACT(EPOCH FROM (g.collect_ts - go.collect_ts))/86400 "dys" FROM pg_gather g JOIN pg_gather_old go ON true) d ON true
JOIN pg_get_class c ON r.relid = c.reloid AND c.relkind NOT IN ('t','p')
LEFT JOIN pg_get_toast t ON r.relid = t.relid
LEFT JOIN pg_get_class ct ON t.toastid = ct.reloid
LEFT JOIN pg_get_rel rt ON rt.relid = t.toastid
LEFT JOIN pg_tab_bloat tb ON r.relid = tb.table_oid
ORDER BY 3 DESC LIMIT 100;

--And generate report like
--psql -X -f report.sql > GatherReport_ts.html