---What is idle in transaction sessions are doing.
SELECT wait_event,count(*) FROM pg_pid_wait
WHERE pid in (select pid from pg_get_activity where state='idle in transaction')
GROUP BY wait_event ORDER BY 2;


