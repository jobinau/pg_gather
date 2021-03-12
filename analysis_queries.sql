---What is idle in transaction sessions are doing.
SELECT wait_event,count(*) FROM pg_pid_wait
WHERE pid in (select pid from pg_get_activity where state='idle in transaction')
GROUP BY wait_event ORDER BY 2;

---Which session is at the top of the blocking
select blocking_pid,statement_in_blocking_process,count(*)
 from pg_get_block where blocking_pid not in (select blocked_pid from pg_get_block)
 group by 1,2;