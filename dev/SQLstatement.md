# Explanation for SQL statements in the project
embedding detailed comments inside SQL statement is not a great option because the SQL string will be send to server as it is.
This documentation fills the gap with detailed explanation

##  Table level information query
The query under id="tabInfo
```
ELECT c.relname || CASE WHEN c.relkind != 'r' THEN ' ('||c.relkind||')' ELSE '' END "Name" ,
--
--Second column is a json message for displaying in popup box. the "nsname" is just a dummy value, not used anymore.
to_jsonb(ROW(ns.nsname)),r.relnamespace "NS", CASE WHEN r.blks > 999 AND r.blks > tb.est_pages THEN (r.blks-tb.est_pages)*100/r.blks||'%' ELSE '' END "Bloat*",
r.n_live_tup "Live tup",r.n_dead_tup "Dead tup", CASE WHEN r.n_live_tup <> 0 THEN  ROUND((r.n_dead_tup::real/r.n_live_tup::real)::numeric,4) END "Dead/Live",
r.rel_size "Rel size",r.tot_tab_size "Tot.Tab size",r.tab_ind_size "Tab+Ind size",r.rel_age,to_char(r.last_vac,'YYYY-MM-DD HH24:MI:SS') "Last vacuum",to_char(r.last_anlyze,'YYYY-MM-DD HH24:MI:SS') "Last analyze",r.vac_nos,
ct.relname "Toast name",rt.tab_ind_size "Toast+Ind" ,rt.rel_age "Toast Age",GREATEST(r.rel_age,rt.rel_age) "Max age"
FROM pg_get_rel r
JOIN pg_get_class c ON r.relid = c.reloid AND c.relkind NOT IN ('t','p')
LEFT JOIN pg_get_toast t ON r.relid = t.relid
LEFT JOIN pg_get_class ct ON t.toastid = ct.reloid
LEFT JOIN pg_get_rel rt ON rt.relid = t.toastid
LEFT JOIN pg_tab_bloat tb ON r.relid = tb.table_oid
LEFT JOIN pg_get_ns ns ON r.relnamespace = ns.nsoid
--
--Limit to 10K tables to avoid browser using high resources.
ORDER BY r.tab_ind_size DESC LIMIT 10000;
```


## SQL for PG server side analysis which returns a json message.
The query under section id="analdata"
```
SELECT to_jsonb(r) FROM
(SELECT 
  --
  --Check whether PostgreSQL is in recovery
  (select recovery from pg_gather) AS clsr,
  --
  --Number of tables without analyze or vacuum (stats missing)
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
  --
  --Number of active, idle, idle-in-transaactions etc
  (SELECT  to_jsonb(ROW(count(*) FILTER (WHERE state='active' AND state IS NOT NULL), 
   count(*) FILTER (WHERE state='idle in transaction'), count(*) FILTER (WHERE state='idle'),
   count(*) FILTER (WHERE state IS NULL), count(*) FILTER (WHERE leader_pid IS NOT NULL) , count(*)))
  FROM pg_get_activity) as sess,
  ---
  ---Current database selected and its stats reset ts, collection ts, number of days
  (WITH curdb AS (SELECT trim(both '\"' from substring(connstr from '\"[[:word:]]*\"')) "curdb" FROM pg_srvr),
  cts AS (SELECT COALESCE((SELECT COALESCE(collect_ts,(SELECT max(state_change) FROM pg_get_activity)) FROM pg_gather),current_timestamp) AS c_ts)
  SELECT to_jsonb(ROW(curdb,stats_reset,c_ts,days)) FROM 
  curdb LEFT JOIN pg_get_db ON pg_get_db.datname=curdb.curdb
  LEFT JOIN LATERAL (SELECT GREATEST((EXTRACT(epoch FROM(c_ts-stats_reset))/86400)::bigint,1) as days FROM cts) AS lat1 ON TRUE
  LEFT JOIN cts ON true) as dbts,
  --
  --Array of schema names
  (select json_agg(pg_get_ns) from pg_get_ns where nsoid > 16384 or nsname='public') AS ns
) r;
```

## Wait-events per session
```
SELECT * FROM (
    --Stage 2. Group by PID, get wait_event list with its count, get total wait event `pidwcnt` for the pid
    WITH w AS (SELECT pid, string_agg( wait_event ||':'|| cnt,',') waits, sum(cnt) pidwcnt, max(max) itr_max, min(min) itr_min FROM
    --Stage 1, Findout the waitevents for each PID, NULL indicates the CPU usage.
    (SELECT pid,COALESCE(wait_event,'CPU') wait_event,count(*) cnt, max(itr),min(itr) FROM pg_pid_wait GROUP BY 1,2 ORDER BY cnt DESC) 
       pw GROUP BY 1),
    --Independent sub query to get Max of timestamp and xid
  g AS (SELECT MAX(state_change) as ts,MAX(GREATEST(backend_xid::text::bigint,backend_xmin::text::bigint)) mx_xid FROM pg_get_activity),
  --Stage 3, Get the maximum value of itr from the pg_pid_wait
  itr AS (SELECT max(itr_max) gitr_max FROM w)
  SELECT a.pid,to_jsonb(ROW(d.datname,application_name,client_hostname,sslversion)), a.state,r.rolname "User",client_addr "client"
  , CASE query WHEN '' THEN '**'||backend_type||' process**' ELSE query END "Last statement"
  , g.ts - backend_start "Connection Since", g.ts - xact_start "Transaction Since", g.mx_xid - backend_xmin::text::bigint "xmin age",
   g.ts - query_start "Statement since",g.ts - state_change "State since", w.waits ||
   CASE WHEN (itr_max - itr_min)::float/itr.gitr_max*2000 - pidwcnt > 0 THEN
    ', Net/Delay*:' || ((itr_max - itr_min)::float/itr.gitr_max*2000 - pidwcnt)::int
   ELSE '' END waits
  FROM pg_get_activity a 
   LEFT JOIN w ON a.pid = w.pid
   LEFT JOIN itr ON true
   LEFT JOIN g ON true
   LEFT JOIN pg_get_roles r ON a.usesysid = r.oid
   LEFT JOIN pg_get_db d on a.datid = d.datid
  ORDER BY "xmin age" DESC NULLS LAST) AS sess
WHERE waits IS NOT NULL OR state != 'idle';
```
The above query collects the wait events per pid, like
```
SELECT pid, string_agg( wait_event ||':'|| cnt,',') waits FROM
    (SELECT pid,COALESCE(wait_event,'CPU') wait_event,count(*) cnt FROM pg_pid_wait GROUP BY 1,2 ORDER BY cnt DESC) pw GROUP BY 1;
```