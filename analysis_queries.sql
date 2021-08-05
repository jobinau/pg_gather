---What is idle in transaction sessions are doing.
SELECT 
--   pg_get_activity.pid,pg_get_activity.query,
   pg_pid_wait.wait_event,count(*) 
FROM pg_pid_wait
JOIN pg_get_activity ON pg_pid_wait.pid = pg_get_activity.pid
WHERE state='idle in transaction'
GROUP BY 1 ORDER BY 2;

--User, database, Active, Total connection (Need for pgbouncer setup)
select 
rolname,datname,count(*) FILTER (WHERE state='active') as active, count(*) 
from pg_get_activity 
  join pg_get_roles on usesysid=pg_get_roles.oid
  join pg_get_db on pg_get_activity.datid = pg_get_db.datid
group by 1,2;

---Which session is at the top of the blocking
select blocking_pid,statement_in_blocking_process,count(*)
 from pg_get_block where blocking_pid not in (select blocked_pid from pg_get_block)
 group by 1,2;

--Biggest Blockers
select statement_in_blocking_process,count(*) from  pg_get_block group by 1 order by 2;

---What is the status of the blocking pids (This may not be accurate as there is 20 second time difference)
SELECT pid,state FROM pg_get_activity WHERE pid IN
(SELECT blocking_pid FROM (select blocking_pid,statement_in_blocking_process,count(*)
 from pg_get_block where blocking_pid not in (select blocked_pid from pg_get_block)
 group by 1,2) blockers);

--Wait event associated with blocking session (Important)
select blocking_pid,blocking_wait_event,count(*)
 from pg_get_block where blocking_pid not in (select blocked_pid from pg_get_block)
 group by 1,2;


--TOP 5 Tables which require maximum maintenace memory
WITH top_tabs AS (select relid,n_live_tup*0.2*6/1024/1024/1024 maint_work_mem_gb 
   from pg_get_rel order by 2 desc limit 5)
SELECT relid, relname,maint_work_mem_gb
 FROM top_tabs
 JOIN pg_get_class ON top_tabs.relid = pg_get_class.reloid
ORDER BY 3 DESC;

-- Stats reset info.
select datname,stats_reset from pg_get_db where stats_reset is not null;
select stats_reset from pg_get_bgwriter;

--Cache hit on databases
SELECT datname, 100 * blks_hit / blks_fetch as cache_hit_ratio FROM pg_get_db WHERE blks_fetch > 0;


=======================HISTORY SCHEMA ANALYSIS=========================
set timezone=UTC;
--Start and End time of data collection
select min(collect_ts),max(collect_ts) from history.pg_get_activity ;
---Load over a perioid of time
select CAST(collect_ts as time),count(*) FILTER (WHERE state='active') as active,count(*) FILTER (WHERE state='idle in transaction') as idle_in_transaction,
count(*) FILTER (WHERE state='idle') as idle,count(*) connections  from history.pg_get_activity group by collect_ts order by 1;

WITH w AS (SELECT collect_ts,wait_event,count(*) cnt FROM history.pg_pid_wait GROUP BY 1,2 ORDER BY 1,2)
SELECT w.collect_ts,string_agg( w.wait_event ||':'|| w.cnt,',' ORDER BY w.wait_event ) FROM w GROUP BY w.collect_ts;



--Top 5 active sessions
select collect_ts,count(*) from history.pg_get_activity where state='active' group by collect_ts order by count(*) desc limit 5;
--Idle in transactions
select collect_ts,count(*) from history.pg_get_activity where state like 'idle in transaction%' group by collect_ts order by count(*) desc limit 5;

select wait_event,count(*) from history.pg_pid_wait where collect_ts='2021-06-28 14:02:01.324049+00'
 and pid in (select pid from history.pg_get_activity where collect_ts='2021-06-28 14:02:01.324049+00' and state like 'idle in transaction%')
group by wait_event;


select distinct collect_ts from history.pg_get_activity where collect_ts < '2021-07-18' order by 1;
select 'DELETE FROM '||n.nspname||'.'||relname||' WHERE collect_ts < ''2021-07-18''' from pg_class c join pg_namespace n ON n.oid = c.relnamespace and n.nspname = 'history';
