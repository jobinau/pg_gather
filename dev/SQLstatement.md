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
    (SELECT to_jsonb(ROW(count(*),COUNT(*) FILTER (WHERE last_vac IS NULL), COUNT(*) FILTER (WHERE b.table_oid IS NULL AND r.n_live_tup != 0 ),COUNT(*) FILTER (WHERE last_anlyze IS NULL))) 
  FROM pg_get_rel r JOIN pg_get_class c ON r.relid = c.reloid AND c.relkind NOT IN ('t','p')
LEFT JOIN pg_tab_bloat b ON c.reloid = b.table_oid) AS tabs,
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
  --Number of partitioned tables, Number of unlogged tables, maximum relid reached. 
  (SELECT to_jsonb(ROW(count(*) FILTER (WHERE relkind='p'), count(*) FILTER (WHERE relkind='r' AND relpersistence='u'), max(reloid))) from pg_get_class) as clas,
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
  -- Findout the DBs with highest mxid age.
  (WITH maxmxid AS (SELECT max(mxidage) FROM pg_get_db),
  topdbmx AS (SELECT array_agg(datname),maxmxid.max FROM pg_get_db JOIN maxmxid ON pg_get_db.mxidage=maxmxid.max AND pg_get_db.mxidage > 1000 GROUP BY 2)
  SELECT to_jsonb(ROW(array_agg,max)) FROM topdbmx) AS mxiddbs,

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

  (SELECT to_jsonb(count(*)) FROM pg_get_index WHERE indisvalid=false) indinvalid,

  --Findout tables without neither primary key nor unique keys
  ( WITH pkuk AS (SELECT indrelid,bool_or(indisprimary) pk,bool_or(indisunique) uk FROM pg_index GROUP BY indrelid)
    SELECT to_jsonb(ROW(COUNT(*) FILTER (WHERE pkuk.pk IS NULL OR NOT pkuk.pk), COUNT(*) FILTER (WHERE pkuk.uk IS NULL OR NOT pkuk.uk))) 
    FROM pg_class c LEFT JOIN pkuk ON pkuk.indrelid = c.oid WHERE c.relkind IN ('r')) nokey,

  -- Catalog metadata size and number of objects
  (SELECT to_jsonb(ROW(sum(tab_ind_size) FILTER (WHERE relid < 16384),count(*))) FROM pg_get_rel) meta
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
   -- Expected number of waitevents per pid = (Duration the pid has some waitevents / Total duration) * 2000 = ((itr_max - itr_min)/gitr_max) * 2000
   -- Missing waitevents due to Net/Delay = Expected number of waitevents - Actual number of waitevents =  ((itr_max - itr_min)/gitr_max) * 2000 - pidwcnt
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
round(bg.buffers_backend::numeric*8192/(min_since_reset*60*1024*1024),4) "Backend MBps",
round(total_buffers::numeric*8192/(min_since_reset*60*1024*1024),4) "Total MBps",
round(buffers_alloc::numeric/total_buffers,3)  "New buffers ratio",
round(100.0*buffers_checkpoint/total_buffers,1)  "Clean by checkpoints (%)",
round(100.0*buffers_clean/total_buffers,1)   "Clean by bgwriter (%)",
round(100.0*bg.buffers_backend/total_buffers,1)  "Clean by backends (%)",
-- Chance of bgwriter stops due to bgwriter_lru_maxpages, in overall possible bgwriter runs
-- Bgwriter does the cleaning if there is not sufficient free pages. That means small numbers indicates most of the time there is sufficient free buffers
round(100.0*maxwritten_clean/(min_since_reset*60000 / delay.setting::numeric),2)   "Bgwriter halts (%) per runs (**1)",
-- Chance (%) of A bgwriter run which has to perform some cleanup will end up in halt
coalesce(round(100.0*maxwritten_clean/(nullif(buffers_clean,0)/ lru.setting::numeric),2),0)  "Bgwriter halt (%) due to LRU hit (**2)",
-- Big difference between above two reading could indicate spiky load to cause buffer dirtying.

round(min_since_reset/(60*24),1) "Reset days"
FROM pg_get_bgwriter
CROSS JOIN 
(
  --Get the client backend related information from pg_stat_io (for PG17)
  WITH client AS (SELECT sum(evictions) buffers_backend FROM pg_get_io WHERE btype='c')  
SELECT 
    NULLIF(round(extract('epoch' from (select collect_ts from pg_gather) - stats_reset)/60)::numeric,0) min_since_reset,
    GREATEST(buffers_checkpoint + buffers_clean + COALESCE(client.buffers_backend,pg_get_bgwriter.buffers_backend),1) total_buffers,
    NULLIF(checkpoints_timed+checkpoints_req,0) tot_cp,
    --Select which ever is available as buffers_backend, same for total_buffers
    COALESCE(client.buffers_backend,pg_get_bgwriter.buffers_backend) buffers_backend
FROM pg_get_bgwriter,client) AS bg
LEFT JOIN pg_get_confs delay ON delay.name = 'bgwriter_delay'
LEFT JOIN pg_get_confs lru ON lru.name = 'bgwriter_lru_maxpages';
```

## Top Statemnts

```
SELECT 
  DENSE_RANK() OVER (ORDER BY ranksum) "Rank"   --Rank consiidering both Total Time and Average Time ranking
  ,"Statement",total_time "Tot.DB.time"  --Total Database time consumed
  ,calls ,total_time::int/calls "Avg.ExecTime" --Average Execution time
  ,"C.Hit" --Cache Hit
  ,"Avg.Reads","Avg.Dirty","Avg.Write","Avg.Temp(r)","Avg.Temp(w)"
FROM 
(select left(query,50) "Statement", total_time::int, 
--Total-Time based Ranking. The statements which consumes more database time need to be ranked.
DENSE_RANK() OVER (ORDER BY total_time DESC) AS tottrank,calls,
total_time::int/calls, 
--Average execution time based ranking. If the average execution time is high, it can affect other concurrent statements in the system
DENSE_RANK() OVER (ORDER BY total_time::int/calls DESC) as avgtrank, 
DENSE_RANK() OVER (ORDER BY total_time DESC)+DENSE_RANK() OVER (ORDER BY total_time::int/calls DESC) ranksum,
100 * shared_blks_hit / nullif((shared_blks_read + shared_blks_hit),0) as "C.Hit",
shared_blks_read/calls "Avg.Reads",
shared_blks_dirtied/calls "Avg.Dirty",
shared_blks_written/calls "Avg.Write",
temp_blks_read/calls "Avg.Temp(r)",
temp_blks_written/calls "Avg.Temp(w)"
from pg_get_statements) AS stmnts
WHERE tottrank < 10 OR avgtrank < 10 ;
```

## Replication status
```
WITH M AS (SELECT GREATEST((SELECT(current_wal) FROM pg_gather),(SELECT MAX(sent_lsn) FROM pg_replication_stat))),
g AS (SELECT max(mx_xid) mx_xid FROM
--findout the biggest xmin of all the sessions
(SELECT MAX(GREATEST(backend_xid::text::bigint,backend_xmin::text::bigint)) mx_xid FROM pg_get_activity
  UNION
 SELECT NULL::text::bigint mx_xid FROM pg_gather) a)
SELECT usename AS "Replication User",client_addr AS "Replica Address",pid,state,
 pg_wal_lsn_diff(M.greatest, sent_lsn) "Transmission Lag (Bytes)",pg_wal_lsn_diff(sent_lsn,write_lsn) "Replica Write lag(Bytes)",
 pg_wal_lsn_diff(write_lsn,flush_lsn) "Replica Flush lag(Bytes)",pg_wal_lsn_diff(flush_lsn,replay_lsn) "Replay at Replica lag(Bytes)",
 slot_name "Slot",plugin,slot_type "Type",datname "DB name",temporary,active,GREATEST(g.mx_xid-old_xmin::text::bigint,0) as "xmin age",
 GREATEST(g.mx_xid-catalog_xmin::text::bigint,0) as "catalog xmin age", GREATEST(pg_wal_lsn_diff(M.greatest,restart_lsn),0) as "Restart LSN lag(Bytes)",
 GREATEST(pg_wal_lsn_diff(M.greatest,confirmed_flush_lsn),0) as "Confirmed LSN lag(Bytes)"
FROM pg_replication_stat JOIN M ON TRUE
  FULL OUTER JOIN pg_get_slots s ON pid = active_pid
  LEFT JOIN g ON TRUE
  LEFT JOIN pg_get_db ON s.datoid = datid;
```

## FILLFACTOR calculation 
100    -    Space for new tuples   +      HOT updates in new tuples

(Assuming 20% can be reserved)

100 - 20 *      n_tup_upd               +      20   *    n_tup_upd            *    n_tup_hot_upd
           ---------                                   ------------                --------------
           (n_tup_upd + n_tup_ins)                 (n_tup_upd + n_tup_ins)           n_tup_upd


## HBA analysis
```SQL
--Create a CTE with name "rules" with only those set of rules where CIDR need to be calcuated
WITH rules AS (SELECT * FROM pg_get_hba_rules WHERE mask IS NOT NULL AND addr NOT IN ('all','samehost','samenet')),
--Calculate CIDR mask based on "mask" column
cidr AS (SELECT seq, COALESCE(sum((length(mask) - length(replace(mask, ip4mask.col1, ''))) / length(ip4mask.col1) * ip4mask.col2) ,
 sum((length(mask) - length(replace(mask, ip6mask.col1, ''))) / length(ip6mask.col1) * ip6mask.col2)) cidr_mask
FROM rules
LEFT JOIN (VALUES ('255',8),('254',7),('252',6),('248',5),('240',4),('224',3),('192',2),('128',1)) AS ip4mask (col1,col2)
  ON family(addr::inet) = 4
LEFT JOIN (VALUES ('8',1),('c',2),('e',3),('f',4)) AS ip6mask (col1,col2) ON family(addr::inet) = 6
GROUP BY 1),
--Create a "rule_data" for as table with calculated CIDR mask
rule_data AS (SELECT hba.seq ,typ ,db ,usr ,addr , cidr_mask , mask,
CASE WHEN addr IN ('all','samehost','samenet') OR ( mask IS NULL AND addr IS NOT NULL) THEN 'IPv4,IPv6'
 ELSE 'IPv'||family(addr::inet)
END  "IP" ,method , err, (addr||'/'||cidr_mask)::inet network_block
FROM  pg_get_hba_rules hba  LEFT JOIN cidr ON cidr.seq = hba.seq)
SELECT victim.seq "Line",victim.typ "Type",victim.db "Database",victim.usr "User",victim.addr "Address", victim.cidr_mask "CIDR Mask",victim.mask "DDN/Binary Mask" 
  ,victim."IP" "IP Ver.",victim.Method,victim.err,victim.network_block "Network Block", string_agg(shadower.seq::text,',')
 FROM rule_data AS victim
-- Findout rules which are in shadow of the previous rules (For Version 32)
LEFT JOIN rule_data AS shadower
ON  shadower.seq < victim.seq
    AND (
     (victim.typ = 'local' AND shadower.typ = 'local')
     OR (victim.typ = 'host' AND shadower.typ = 'host')
     OR (victim.typ = 'hostssl' AND shadower.typ IN ('host', 'hostssl'))
     OR (victim.typ = 'hostnossl' AND shadower.typ IN ('host', 'hostnossl'))
    )
    AND ( victim.typ = 'local'
     OR ( victim.network_block IS NOT NULL  AND shadower.network_block IS NOT NULL AND shadower.network_block >>= victim.network_block )
     OR shadower.addr = 'all'
    )
    AND (('replication' = ANY(victim.db) AND 'replication' = ANY(shadower.db) AND  victim.db <@ shadower.db)  OR
        (NOT ('replication' = ANY(victim.db)) AND ( shadower.db = '{all}'  OR victim.db <@ shadower.db ) ))
    AND (  shadower.usr = '{all}'  OR victim.usr <@ shadower.usr)
GROUP BY 1,2,3,4,5,6,7,8,9,10,11
ORDER BY 1;

```
```SQL
--NEW replacement SQL for version 33
WITH rule_data AS ( SELECT seq, typ, db, usr, addr, s.prefix AS cidr_mask, mask,
  CASE WHEN addr IN ('all','samehost','samenet') OR (mask IS NULL AND addr IS NOT NULL) THEN 'IPv4,IPv6' ELSE 'IPv'||family(addr::inet) END AS "IP",
  method, err, set_masklen(addr::inet, s.prefix) AS network_block
  FROM pg_get_hba_rules
  LEFT JOIN LATERAL (
    SELECT i AS prefix FROM generate_series(0, 128) AS i WHERE netmask(set_masklen(addr::inet, i)) = mask::inet LIMIT 1 ) s ON TRUE )
SELECT 
  v.seq AS "Line", v.typ AS "Type", v.db AS "Database", v.usr AS "User", v.addr AS "Address", v.cidr_mask AS "CIDR Mask",
  v.mask AS "DDN/Binary Mask",  v."IP" AS "IP Ver.", v.method, v.err, v.network_block AS "Network Block",
  ( SELECT string_agg(s.seq::text, ',')  FROM rule_data s
    WHERE s.seq < v.seq
      AND ( (v.typ = s.typ) OR (v.typ = 'hostssl' AND s.typ = 'host') OR (v.typ = 'hostnossl' AND s.typ = 'host'))
      AND ( v.typ = 'local' OR (v.network_block IS NOT NULL AND s.network_block IS NOT NULL AND s.network_block >>= v.network_block) OR s.addr = 'all' )
      AND ( ('replication' = ANY(v.db) AND 'replication' = ANY(s.db) AND v.db <@ s.db) OR (NOT ('replication' = ANY(v.db)) AND (s.db = '{all}' OR v.db <@ s.db)))
      AND (s.usr = '{all}' OR v.usr <@ s.usr) ) AS "Shadowed By",
  CASE v."IP" WHEN 'IPv4' THEN (2::numeric ^ (32 - masklen(network_block)))::numeric(38,0) 
  WHEN 'IPv6' THEN (2::numeric ^ (128 - masklen(network_block)))::numeric(38,0) ELSE NULL END
  AS total_ips
FROM rule_data v
ORDER BY v.seq;
```
