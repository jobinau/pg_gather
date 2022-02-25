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


=======================HISTORY SCHEMA ANALYSIS=========================
set timezone=UTC;
--Start and End time of data collection
SELECT min(collect_ts),max(collect_ts) FROM history.pg_get_activity ;
--min and max of a particular hour : WHERE DATE_TRUNC('hour',collect_ts) = '2022-01-03 18:00:00+00';

--Inspect the continuity of data collection, whether there is any gap
SELECT DATE_TRUNC('hour',collect_ts) date_hour,count(*) cnt FROM history.pg_get_activity GROUP BY DATE_TRUNC('hour',collect_ts) ORDER BY 1;

---Load over a perioid of time
SELECT collect_ts,count(*) FILTER (WHERE state='active') as active,count(*) FILTER (WHERE state='idle in transaction') as idle_in_transaction,
count(*) FILTER (WHERE state='idle') as idle,count(*) connections  FROM history.pg_get_activity GROUP by collect_ts ORDER BY 1;
--Or use CAST(collect_ts as time) if data is for a single day

--More details about the connections
SELECT rolname,datname,state,client_addr,count(*) FROM 
 pg_get_activity a 
 left join pg_get_roles r on a.usesysid = r.oid
 left join pg_get_db d USING (datid)
GROUP BY rolname,datname,state,client_addr
ORDER BY count(*);





--HISTORY (BULK DATA IMPORT)

WITH w AS (SELECT collect_ts,COALESCE(wait_event,'CPU') as wait_event,count(*) cnt FROM history.pg_pid_wait GROUP BY 1,2 ORDER BY 1,2)
SELECT w.collect_ts,string_agg( w.wait_event ||':'|| w.cnt,',' ORDER BY w.cnt DESC) "wait events" 
FROM w 
WHERE w.collect_ts between '2022-01-03 16:46:01.213361+00' AND '2022-01-03 16:48:01.657648+00 '
GROUP BY w.collect_ts;

--
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


