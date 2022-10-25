# Explanation for SQL statements in the project
embedding detailed comments inside SQL statement is not a great option because the SQL string will be send to server as it is.
This documentation fills the gap with detailed explanation

#SQL for PG server side analysis which returns a json message.
```
SELECT to_jsonb(r) FROM
(SELECT 
  (select recovery from pg_gather) AS clsr,
  (SELECT to_jsonb(ROW(count(*),COUNT(*) FILTER (WHERE last_vac IS NULL),COUNT(*) FILTER (WHERE last_anlyze IS NULL))) 
     from pg_get_rel r JOIN pg_get_class c ON r.relid = c.reloid AND c.relkind NOT IN ('t','p')) AS tabs,
  --
  --Total number of connections which has some wait even recorded and number of connections started in last 15 mintues
  (SELECT to_jsonb(ROW(COUNT(*),COUNT(*) FILTER (WHERE CONN < interval '15 minutes' ) )) FROM 
  (WITH g AS (SELECT MAX(state_change) as ts FROM pg_get_activity)
  SELECT pid,g.ts - backend_start CONN
    FROM pg_get_activity
    LEFT JOIN g ON true
    WHERE EXISTS (SELECT pid FROM pg_pid_wait WHERE pid=pg_get_activity.pid)
    AND backend_type='client backend') cn) AS cn,
  --
  --Number of partitioned tables
  (select count(*) from pg_get_class where relkind='p') as ptabs,
  (SELECT  to_jsonb(ROW(count(*) FILTER (WHERE state='active' AND state IS NOT NULL), 
   count(*) FILTER (WHERE state='idle in transaction'), count(*) FILTER (WHERE state='idle'),
   count(*) FILTER (WHERE state IS NULL), count(*) FILTER (WHERE leader_pid IS NOT NULL) , count(*)))
  FROM pg_get_activity) as sess
) r;
```

