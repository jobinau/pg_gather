# Explanation for SQL statements in the project
embedding detailed comments inside SQL statement is not a great option because the SQL string will be send to server as it is.
This documentation fills the gap with detailed explanation
## DB level information
```
--Findout the lastest timestamp available in the data collection
WITH cts AS (SELECT COALESCE(collect_ts,(SELECT max(state_change) FROM pg_get_activity)) AS c_ts FROM pg_gather),
--Get when was the last stats_reset of pg_stat_wal, 
--use this as another reference if database level stat_reset is not available
  wal_stat AS (SELECT stats_reset FROM pg_get_wal)
SELECT datname "DB Name",to_jsonb(ROW(tup_inserted/days,tup_updated/days,tup_deleted/days,to_char(pg_get_db.stats_reset,'YYYY-MM-DD HH24-MI-SS')))
,xact_commit/days "Avg.Commits",xact_rollback/days "Avg.Rollbacks",(tup_inserted+tup_updated+tup_deleted)/days "Avg.DMLs", CASE WHEN blks_fetch > 0 THEN blks_hit*100/blks_fetch ELSE NULL END  "Cache hit ratio"
,temp_files/days "Avg.Temp Files",temp_bytes/days "Avg.Temp Bytes",db_size "DB size",age "Age"
FROM pg_get_db LEFT JOIN wal_stat ON true
--if pg_get_db.stats_reset is NULL, use wal_stat.stats_reset. 
--Atleast one day is considered for calculation
LEFT JOIN LATERAL (SELECT GREATEST((EXTRACT(epoch FROM(c_ts-COALESCE(pg_get_db.stats_reset,wal_stat.stats_reset)))/86400)::bigint,1) as days FROM cts) AS lat1 ON TRUE;
```


##  Table level information query
The query under id="tabInfo"
```
SELECT c.relname || CASE WHEN c.relkind != 'r' THEN ' ('||c.relkind||')' ELSE '' END "Name" ,
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
  -- cn stands for connections. count of total connections and number of number of connections started in last 15 mintues are returned
  -- only those connections which has some waitevent is considered
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
  (WITH curdb AS (SELECT trim(both '\"' from substring(connstr from '\"\w*\"')) "curdb" FROM pg_srvr WHERE connstr like '%to database%'),
    cts AS (SELECT COALESCE((SELECT COALESCE(collect_ts,(SELECT max(state_change) FROM pg_get_activity)) FROM pg_gather),current_timestamp) AS c_ts)
    SELECT to_jsonb(ROW(curdb,COALESCE(pg_get_db.stats_reset,pg_get_wal.stats_reset),c_ts,days))  -- stats_reset (dbts.f2) and c_ts(dbts.f3) are still not used. can be avoided
    FROM  curdb LEFT JOIN pg_get_db ON pg_get_db.datname=curdb.curdb
    --Consider stats_reset from pg_get_wal if stats_reset from pg_get_db is NULL
    LEFT JOIN pg_get_wal ON true
    LEFT JOIN LATERAL (SELECT GREATEST((EXTRACT(epoch FROM(c_ts- COALESCE(pg_get_db.stats_reset,pg_get_wal.stats_reset)))/86400)::bigint,1) as days FROM cts) AS lat1 ON TRUE
    LEFT JOIN cts ON true --Avoidable join because c_ts(dbts.f3) is still not used.
    ) as dbts,
  --
  --Array of schema names
  (select json_agg(pg_get_ns) from pg_get_ns where nsoid > 16384 or nsname='public') AS ns

  --WAL archival check. field f1 is true if the last archive is more than 15 mintues old. f2 is calculated delay in WAL archiving.
  (SELECT to_jsonb(ROW((collect_ts-last_archived_time) > '15 minute' :: interval, 
  pg_wal_lsn_diff(current_wal,(coalesce(nullif(ltrim(substring(last_archived_wal,9,8),'0'),''),'0') ||'/'|| substring(last_archived_wal,23,2) || '000001')::pg_lsn))) FROM pg_gather,pg_archiver_stat) AS arcfail,

  --Any Archive library is used or not
  (SELECT to_jsonb(setting) FROM pg_get_confs WHERE name = 'archive_library') AS arclib,
  
  --A crash can be reported if all stats are rest in 2 mintues
  (SELECT CASE WHEN max(stats_reset)-min(stats_reset) < '2 minute' :: interval THEN min(stats_reset) ELSE NULL END 
  FROM (SELECT stats_reset FROM pg_get_db UNION SELECT stats_reset FROM pg_get_bgwriter) reset) crash,

  --Blocking sessions information
  (WITH blockers AS (select array_agg(victim_pid) OVER () victim,blocking_pids blocker from pg_get_pidblock),
   ublokers as (SELECT unnest(blocker) AS blkr FROM blockers)
   SELECT json_agg(blkr) FROM ublokers
   WHERE NOT EXISTS (SELECT 1 FROM blockers WHERE ublokers.blkr = ANY(victim))) blkrs,
  
  --Victims of blockers
  (select json_agg((victim_pid,blocking_pids)) from pg_get_pidblock) victims,

  --Time it took for collecting pg_gather info
  (select to_jsonb((EXTRACT(epoch FROM (end_ts-collect_ts)),pg_wal_lsn_diff(end_lsn,current_wal)*60*60/EXTRACT(epoch FROM (end_ts-collect_ts)))) 
  from pg_gather,pg_gather_end) sumry,

  --Database objects which uses highest maintenance_work_mem
  (SELECT json_agg((relname,maint_work_mem_gb)) FROM (SELECT relname,n_live_tup*0.2*6 maint_work_mem_gb 
   FROM pg_get_rel JOIN pg_get_class ON n_live_tup > 894784853 AND pg_get_rel.relid = pg_get_class.reloid 
   ORDER BY 2 DESC LIMIT 3) AS wmemuse) wmemuse,

  (SELECT to_jsonb(count(*)) FROM pg_get_index WHERE indisvalid=false) indinvalid
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


## BGWriter / checkpointer info
```
SELECT round(checkpoints_req*100/tot_cp,1) "Forced Checkpoint %" ,
round(min_since_reset/tot_cp,2) "avg mins between CP",
round(checkpoint_write_time::numeric/(tot_cp*1000),4) "Avg CP write time (s)",
round(checkpoint_sync_time::numeric/(tot_cp*1000),4)  "Avg CP sync time (s)",
round(total_buffers::numeric*8192/(1024*1024),2) "Tot MB Written",
round((buffers_checkpoint::numeric/tot_cp)*8192/(1024*1024),4) "MB per CP",
round(buffers_checkpoint::numeric*8192/(min_since_reset*60*1024*1024),4) "Checkpoint MBps",
round(buffers_clean::numeric*8192/(min_since_reset*60*1024*1024),4) "Bgwriter MBps",
round(buffers_backend::numeric*8192/(min_since_reset*60*1024*1024),4) "Backend MBps",
round(total_buffers::numeric*8192/(min_since_reset*60*1024*1024),4) "Total MBps",
round(buffers_alloc::numeric/total_buffers,3)  "New buffers ratio",
round(100.0*buffers_checkpoint/total_buffers,1)  "Clean by checkpoints (%)",
round(100.0*buffers_clean/total_buffers,1)   "Clean by bgwriter (%)",
round(100.0*buffers_backend/total_buffers,1)  "Clean by backends (%)",
-- Chance of bgwriter stops due to bgwriter_lru_maxpages, in overall possible bgwriter runs
-- Bgwriter does the cleaning if there is not sufficient free pages. That means small numbers indicates most of the time there is sufficient free buffers
round(100.0*maxwritten_clean/(min_since_reset*60000 / delay.setting::numeric),2)   "Bgwriter halts (%) per runs (**1)",
-- Chance (%) of A bgwriter run which has to perform some cleanup will end up in halt
coalesce(round(100.0*maxwritten_clean/(nullif(buffers_clean,0)/ lru.setting::numeric),2),0)  "Bgwriter halt (%) due to LRU hit (**2)",
-- Big difference between above two reading could indicate spiky load to cause buffer dirtying.

round(min_since_reset/(60*24),1) "Reset days"
FROM pg_get_bgwriter
CROSS JOIN 
(SELECT 
    NULLIF(round(extract('epoch' from (select collect_ts from pg_gather) - stats_reset)/60)::numeric,0) min_since_reset,
    GREATEST(buffers_checkpoint + buffers_clean + buffers_backend,1) total_buffers,
    NULLIF(checkpoints_timed+checkpoints_req,0) tot_cp 
    FROM pg_get_bgwriter) AS bg
LEFT JOIN pg_get_confs delay ON delay.name = 'bgwriter_delay'
LEFT JOIN pg_get_confs lru ON lru.name = 'bgwriter_lru_maxpages';
```
