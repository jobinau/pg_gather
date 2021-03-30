---What is idle in transaction sessions are doing.
SELECT wait_event,count(*) FROM pg_pid_wait
WHERE pid in (select pid from pg_get_activity where state='idle in transaction')
GROUP BY wait_event ORDER BY 2;

---Which session is at the top of the blocking
select blocking_pid,statement_in_blocking_process,count(*)
 from pg_get_block where blocking_pid not in (select blocked_pid from pg_get_block)
 group by 1,2;


--TOP 5 Tables which require maximum maintenace memory
WITH top_tabs AS (select relid,n_live_tup*0.2*6/1024/1024/1024 maint_work_mem_gb 
   from pg_get_rel order by 2 desc limit 5)
SELECT relid, relname,maint_work_mem_gb
 FROM top_tabs
 JOIN pg_get_class ON top_tabs.relid = pg_get_class.reloid
ORDER BY 3 DESC;
