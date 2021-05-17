---What is idle in transaction sessions are doing.
SELECT 
--   pg_get_activity.pid,pg_get_activity.query,
   pg_pid_wait.wait_event,count(*) 
FROM pg_pid_wait
JOIN pg_get_activity ON pg_pid_wait.pid = pg_get_activity.pid
WHERE state='idle in transaction'
GROUP BY 1 ORDER BY 2;

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


