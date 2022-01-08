--1. What is idle in transaction sessions are doing.
SELECT 
--   pg_get_activity.pid,pg_get_activity.query,
   pg_pid_wait.wait_event,count(*) 
FROM pg_pid_wait
JOIN pg_get_activity ON pg_pid_wait.pid = pg_get_activity.pid
WHERE state='idle in transaction'
GROUP BY 1 ORDER BY 2;

--2.User, database, Active, Total connection (Need for pgbouncer setup)
select 
rolname,datname,count(*) FILTER (WHERE state='active') as active, count(*) 
from pg_get_activity 
  join pg_get_roles on usesysid=pg_get_roles.oid
  join pg_get_db on pg_get_activity.datid = pg_get_db.datid
group by 1,2;

--3.Which session is at the top of the blocking
select blocking_pid,statement_in_blocking_process,count(*)
 from pg_get_block where blocking_pid not in (select blocked_pid from pg_get_block)
 group by 1,2;

--4.Biggest Blockers
select statement_in_blocking_process,count(*) from  pg_get_block group by 1 order by 2;

--5.What is the status of the blocking pids (This may not be accurate as there is 20 second time difference)
SELECT pid,state FROM pg_get_activity WHERE pid IN
(SELECT blocking_pid FROM (select blocking_pid,statement_in_blocking_process,count(*)
 from pg_get_block where blocking_pid not in (select blocked_pid from pg_get_block)
 group by 1,2) blockers);

--6.Wait event associated with blocking session (Important)
select blocking_pid,blocking_wait_event,count(*)
 from pg_get_block where blocking_pid not in (select blocked_pid from pg_get_block)
 group by 1,2;


--7.TOP 5 Tables which require maximum maintenace memory
WITH top_tabs AS (select relid,n_live_tup*0.2*6/1024/1024/1024 maint_work_mem_gb 
   from pg_get_rel order by 2 desc limit 5)
SELECT relid, relname,maint_work_mem_gb
 FROM top_tabs
 JOIN pg_get_class ON top_tabs.relid = pg_get_class.reloid
ORDER BY 3 DESC;

--8. Stats reset info.
select datname,stats_reset from pg_get_db where stats_reset is not null;
select stats_reset from pg_get_bgwriter;

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
select min(collect_ts),max(collect_ts) from history.pg_get_activity ;
--min and max of a particular hour : WHERE DATE_TRUNC('hour',collect_ts) = '2022-01-03 18:00:00+00';

--Inspect the continuity of data collection, whether there is any gap
SELECT DATE_TRUNC('hour',collect_ts) date_hour,count(*) cnt from history.pg_get_activity GROUP BY DATE_TRUNC('hour',collect_ts) ORDER BY 1;

---Load over a perioid of time
select collect_ts,count(*) FILTER (WHERE state='active') as active,count(*) FILTER (WHERE state='idle in transaction') as idle_in_transaction,
count(*) FILTER (WHERE state='idle') as idle,count(*) connections  from history.pg_get_activity group by collect_ts order by 1;
--Or use CAST(collect_ts as time) if data is for a single day


  WITH w AS (SELECT collect_ts,COALESCE(wait_event,'CPU') as wait_event,count(*) cnt FROM history.pg_pid_wait GROUP BY 1,2 ORDER BY 1,2)
  SELECT w.collect_ts,string_agg( w.wait_event ||':'|| w.cnt,',' ORDER BY w.cnt DESC) "wait events" 
  FROM w 
  WHERE w.collect_ts between '2022-01-03 16:46:01.213361+00' AND '2022-01-03 16:48:01.657648+00 '
  GROUP BY w.collect_ts;

--
select rolname,datname,state,count(*) from 
 history.pg_get_activity a 
 left join pg_get_roles r on a.usesysid = r.oid
 left join pg_get_db d USING (datid)
where collect_ts between '2021-12-27 16:32:01' and '2021-12-27 16:36:01' group by rolname,datname,state
order by count(*);

--Top 5 active sessions
select collect_ts,count(*) from history.pg_get_activity where state='active' group by collect_ts order by count(*) desc limit 5;
--Idle in transactions
select collect_ts,count(*) from history.pg_get_activity where state like 'idle in transaction%' group by collect_ts order by count(*) desc limit 5;

select wait_event,count(*) from history.pg_pid_wait where collect_ts='2021-06-28 14:02:01.324049+00'
 and pid in (select pid from history.pg_get_activity where collect_ts='2021-06-28 14:02:01.324049+00' and state like 'idle in transaction%')
group by wait_event;


select distinct collect_ts from history.pg_get_activity where collect_ts < '2021-07-18' order by 1;
select 'DELETE FROM '||n.nspname||'.'||relname||' WHERE collect_ts < ''2021-07-18''' from pg_class c join pg_namespace n ON n.oid = c.relnamespace and n.nspname = 'history';


