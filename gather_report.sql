\set QUIET 1
\echo <!DOCTYPE html>
\echo <html><meta charset="utf-8" />
\echo <style>
\echo #finditem,#paramtune,table {box-shadow: 0px 20px 30px -10px grey; margin: 2em; caption {font:large bold; text-align:left; span {font: italic bold 1.7em Georgia, serif}}}
\echo table, th, td { border: 1px solid black; border-collapse: collapse; padding: 2px 4px 2px 4px;} 
\echo th {background-color: #d2f2ff;cursor: pointer; }
\echo tr:nth-child(even) {background-color: #eef8ff} 
\echo a:hover,tr:hover { background-color: #EBFFDA}
\echo /* h2 { scroll-margin-left: 2em;} keep the scroll left
\echo caption { font-size: larger } */
\echo ol { width: fit-content;}
\echo .warn { font-weight:bold; background-color: #FBA }
\echo .high { border: 5px solid red;font-weight:bold}
\echo .lime { font-weight:bold;background-color: #FFD}
\echo .lineblk {float: left; margin:2em }
\echo .thidden tr { td:nth-child(2),th:nth-child(2) {display: none} td:first-child {color:blue}}
\echo #bottommenu { position: fixed; right: 0px; bottom: 0px; padding: 5px; border : 2px solid #AFAFFF; border-radius: 5px; z-index: 100;}
\echo #cur { font: 5em arial; position: absolute; color:brown; animation: vanish 2s ease forwards; }  /*sort indicator*/
\echo #dtls,#finditem,#paramtune,#menu { font-weight:initial;line-height:1.5em;position:absolute;background-color:#FAFFEA;border: 2px solid blue; border-radius: 5px; padding: 1em;box-shadow: 0px 20px 30px -10px grey}
\echo @keyframes vanish { from { opacity: 1;} to {opacity: 0;} }
\echo summary {  padding: 1rem; font: bold 1.2em arial;  cursor: pointer } 
\echo footer { text-align: center; padding: 3px; background-color:#d2f2ff}
\echo </style>
\H
\pset footer off 
SET max_parallel_workers_per_gather = 0;
-- SELECT setting AS pgver FROM pg_get_confs WHERE name = 'server_version_num' \gset

\echo <h1>
\echo   <svg width="10em" viewBox="0 0 140 80">
\echo     <path fill="none" stroke="#000000" stroke-linecap="round" stroke-width="2"  d="m 21.2,46.7 c 1,2 0.67,4 -0.3,5.1 c -1.1,1 -2,1.5 -4,1 c -10,-3 -4,-25 -4 -25 c 0.6,-10 8,-9 8 -9 s 7,-4.5 11,0.2 c 1.2,1.4 1.7,3.3 1.7,5.17 c -0.1,3 3,7 -2,10 c-2,2 -1,5 -8,5.5 m -2 -12 c 0,0 -1,1 -0.2,0.2 m -4 12 c 0,0 0,10 -12,11"/>
\echo     <text x="30" y="50" style="font:25px arial">gGather</text>
\echo     <text x="60" y="62" style="fill:red; font:15px arial">Report</text>
\echo    </svg>
\echo    <b id="busy" class="warn"> Loading... </b>
\echo </h1>
\pset tableattr 'id="tblgather" class="lineblk"'
SELECT (SELECT count(*) > 1 FROM pg_srvr WHERE connstr ilike 'You%') AS conlines \gset
\if :conlines
  \echo "There is serious problem with the data. Please make sure that all tables are dropped and recreated as part of importing data (gather_schema.sql) and there was no error"
  "SOMETHING WENT WRONG WHILE IMPORTING THE DATA. PLEASE MAKE SURE THAT ALL TABLES ARE DROPPED AND RECREATED AS PART OF IMPORTING";
  \q
\endif
\set tzone `echo "$PG_GATHER_TIMEZONE"`
SELECT * FROM 
(WITH TZ AS (SELECT CASE WHEN :'tzone' = ''
    THEN (SELECT set_config('timezone',setting,false) FROM pg_get_confs WHERE name='log_timezone')
    ELSE  set_config('timezone',:'tzone',false) 
  END AS val)
SELECT  UNNEST(ARRAY ['Collected At','Collected By','PG build', 'Last Startup','In recovery?','Client','Server','Last Reload','Latest xid','Oldest xid ref','Current LSN','Time Line','WAL file','System']) AS pg_gather,
        UNNEST(ARRAY [CONCAT(collect_ts::text,' (',TZ.val,')'),usr,ver, pg_start_ts::text ||' ('|| collect_ts-pg_start_ts || ')',recovery::text,client::text,server::text,reload_ts::text || ' ('|| collect_ts-reload_ts || ')',
        pg_snapshot_xmax(snapshot)::text,pg_snapshot_xmin(snapshot)::text,current_wal::text,timeline::text || ' (Hex:' ||  upper(to_hex(timeline)) || ')',  lpad(upper(to_hex(timeline)),8,'0')||substring(pg_walfile_name(current_wal) from 9 for 16),
        'ID: ' || systemid || ' Since: ' || to_timestamp ( systemid >> 32 ) || ' ('|| collect_ts-to_timestamp ( systemid >> 32 ) || ')']) AS "Report"
FROM pg_gather LEFT JOIN TZ ON TRUE 
UNION
SELECT  'Connection', replace(connstr,'You are connected to ','') FROM pg_srvr ) a WHERE "Report" IS NOT NULL ORDER BY 1;
\pset tableattr 'id="dbs" class="thidden"'
\C ''
WITH cts AS (SELECT COALESCE(collect_ts,(SELECT max(state_change) FROM pg_get_activity)) AS c_ts FROM pg_gather),
  wal_stat AS (SELECT stats_reset FROM pg_get_wal)
SELECT datname "DB Name",to_jsonb(ROW(tup_inserted/days,tup_updated/days,tup_deleted/days,to_char(pg_get_db.stats_reset,'YYYY-MM-DD HH24-MI-SS'),datid,mxidage))
,xact_commit/days "Avg.Commits",xact_rollback/days "Avg.Rollbacks",(tup_inserted+tup_updated+tup_deleted)/days "Avg.DMLs", CASE WHEN blks_fetch > 0 THEN blks_hit*100/blks_fetch ELSE NULL END  "Cache hit ratio"
,temp_files/days "Avg.Temp Files",temp_bytes/days "Avg.Temp Bytes",db_size "DB size",age "Age"
FROM pg_get_db LEFT JOIN wal_stat ON true
LEFT JOIN LATERAL (SELECT GREATEST((EXTRACT(epoch FROM(c_ts-COALESCE(pg_get_db.stats_reset,wal_stat.stats_reset)))/86400)::bigint,1) as days FROM cts) AS lat1 ON TRUE;
\pset tableattr off

\echo <div>
\echo <details style="clear: left; border: 2px solid #b3aeae; border-radius: 5px; padding: 1em;margin: 2em;">
\echo   <summary style="font: italic bold 2em Georgia">Parameter Recommendations</summary>
\echo   <fieldset style="border: 2px solid blue; border-radius: 5px; padding: 1em; width: fit-content;">
\echo   <legend>Inputs</legend>
\echo   <label for="cpus">CPUs:
\echo   <input type="number" id="cpus" name="cpus" value="4">
\echo   </label>
\echo   <label for="mem" style="padding-left: 3em;">Memory(GB):
\echo   <input type="number" id="mem" name="mem" value="8">
\echo  </label>
\echo  <label for="strg" style="padding-left: 3em;"> Storage:
\echo   <select id="strg" name="strg">
\echo     <option value="ssd">SSD/NVMe</option>
\echo     <option value="san">SAN</option>
\echo     <option value="mag">Magnetic</option>
\echo    </select>
\echo  </label>
\echo  <label for="wrkld" style="padding-left: 3em;"> Work load:
\echo   <select id="wrkld" name="wrkld">
\echo     <option value="oltp">OLTP</option>
\echo     <option value="olap">OLAP/DSS</option>
\echo     <option value="mixed">Mixed</option>
\echo    </select>
\echo  </label>
\echo  <label for="flsys" style="padding-left: 3em;"> Filesystem:
\echo   <select id="flsys" name="flsys">
\echo     <option value="rglr">Regular (like: ext4/xfs)</option>
\echo     <option value="cow">COW (like: zfs/btrfs)</option>
\echo    </select>
\echo  </label>
\echo  <p>☛ Please provide the CPU and memory available on the host machine. Choose the most suitable options from the list to receive specific recommendations. If you''re unsure, seek expert guidance.</p>
\echo </fieldset>
\echo   <div id="paramtune" style="padding:2em;position:relative;width: fit-content;">
\echo    <h3 style="font: italic 1.2em Georgia, serif;text-decoration: underline; margin: 0 0 0.5em;">Recommendations:</h3>
\echo   <ol>
\echo   </ol>
\echo   <p>* Collecting pg_gather data during right utilization levels is important to tune the system for the specific workload</p>
\echo </div>
\echo   <button type="button" onclick="getreccomendation()" title="Calculate / Recalculate Parameters">&#128257; Calculate</button>
\echo   <button type="button" onclick="copyashtml()" title="Copy as html tags">Copy as HTML tags</button>
\echo   <button type="button" onclick="copyrichhtml()" title="Copy as Rich HTML">Copy as Rich HTML</button>
\echo </details>
\echo </div>
\echo <h2 id="topics">Sections</h2>
\echo <ol>
\echo <li><a href="#tabInfo">Tables</a></li>
\echo <li><a href="#tabPart">Partition info</a></li>
\echo <li><a href="#IndInfo">Indexes</a></li>
\echo <li><a href="#params">Parameters / Settings</a></li>
\echo <li><a href="#tblextn">Extensions</a></li>
\echo <li><a href="#tblhba">Security-HBA rules</a>
\echo <li><a href="#tblcs">Connection & Users</a></li>
\echo <li><a href="#tableConten">Database Time</a></li>
\echo <li><a href="#tblsess">Session Details</a></li>
\echo <li><a href="#tblstmnt">Top Statements</a></li>
\echo <li><a href="#tblreplstat">Replications</a></li>
\echo <li><a href="#tblchkpnt" >BGWriter & Checkpointer</a></li>
\echo <li><a href="#finditem">Findings</a></li>
\echo </ol>
\echo <div id="bottommenu">
\echo  <a href="#topics" title="Sections">☰ Section Index (Alt+I)</a>
\echo  <div id="menu" style="display:none; position: relative">
\echo   <ol>
\echo     <li><a href="#tblgather">Head Info</a></li>
\echo     <li><a href="#tabInfo">Tables</a></li>
\echo     <li><a href="#tabPart">Partition info</a></li>
\echo     <li><a href="#IndInfo">Indexes</a></li>
\echo     <li><a href="#params">Parameters / Settings</a></li>
\echo     <li><a href="#tblextn">Extensions</a></li>
\echo     <li><a href="#tblhba">Security-HBA rules</a>
\echo     <li><a href="#tblcs">Connection & Users</a></li>
\echo     <li><a href="#tableConten">Database Time</a></li>
\echo     <li><a href="#tblsess">Session Details</a></li>
\echo     <li><a href="#tblstmnt">Top Statements</a></li>
\echo     <li><a href="#tblreplstat">Replications</a></li>
\echo     <li><a href="#tblchkpnt" >BGWriter & Checkpointer</a></li>
\echo     <li><a href="#tbliostat">IO Statistics</a></li>
\echo     <li><a href="#finditem">Findings</a></li>
\echo   </ol>
\echo  </div>
\echo </div>
\echo <div id="sections" style="display:none">
\pset footer on
\pset tableattr 'id="tabInfo" class="thidden"'
SELECT c.relname || CASE WHEN inh.inhrelid IS NOT NULL THEN ' (part)' WHEN c.relkind != 'r' THEN ' ('||c.relkind||')' ELSE '' END "Name" ,
to_jsonb(ROW(r.relid,r.n_tup_ins,r.n_tup_upd,r.n_tup_del,r.n_tup_hot_upd,isum.totind,isum.ind0scan,isum.pk,isum.uk,inhp.relname,inhp.relkind,c.relfilenode,c.reltablespace,c.reloptions)),r.relnamespace "NS", CASE WHEN r.blks > 999 AND r.blks > tb.est_pages THEN (r.blks-tb.est_pages)*100/r.blks ELSE NULL END "Bloat%",
r.n_live_tup "Live",r.n_dead_tup "Dead", CASE WHEN r.n_live_tup <> 0 THEN  ROUND((r.n_dead_tup::real/r.n_live_tup::real)::numeric,1) END "D/L",
r.rel_size "Rel size",r.tot_tab_size "Tot.Tab size",r.tab_ind_size "Tab+Ind size",r.rel_age,to_char(r.last_vac,'YYYY-MM-DD HH24:MI:SS') "Last vacuum",to_char(r.last_anlyze,'YYYY-MM-DD HH24:MI:SS') "Last analyze",r.vac_nos "Vaccs",
ct.relname "Toast name",rt.tab_ind_size "Toast + Ind" ,rt.rel_age "Toast Age",GREATEST(r.rel_age,rt.rel_age) "Max age",
c.blocks_fetched "Fetch",c.blocks_hit*100/nullif(c.blocks_fetched,0) "C.Hit%",to_char(r.lastuse,'YYYY-MM-DD HH24:MI:SS') "Last Use"
FROM pg_get_rel r
JOIN pg_get_class c ON r.relid = c.reloid AND c.relkind NOT IN ('t','p')
LEFT JOIN pg_get_toast t ON r.relid = t.relid
LEFT JOIN pg_get_class ct ON t.toastid = ct.reloid
LEFT JOIN pg_get_rel rt ON rt.relid = t.toastid
LEFT JOIN pg_tab_bloat tb ON r.relid = tb.table_oid
LEFT JOIN pg_get_inherits inh ON r.relid = inh.inhrelid
LEFT JOIN pg_get_class inhp ON inh.inhparent = inhp.reloid
LEFT JOIN (SELECT count(indexrelid) totind,count(indexrelid)FILTER( WHERE numscans=0 ) ind0scan, count(indexrelid) FILTER (WHERE indisprimary) pk,  
   count(indexrelid) FILTER (WHERE indisunique) uk, indrelid FROM pg_get_index GROUP BY indrelid ) AS isum ON isum.indrelid = r.relid
ORDER BY r.tab_ind_size DESC LIMIT 10000;

\pset tableattr 'id="tabPart"'
SELECT p.relname "Partitioned Table", CASE p.relkind WHEN 'p' THEN 'Native' WHEN 'r' THEN 'Inheritance' ELSE p.relkind END "Partitioning Type",
count(c.reloid) "Partitions", sum(r.tot_tab_size) "Tot.Tab size", sum(r.tab_ind_size) "Tab+Ind size"
FROM pg_get_class c JOIN pg_get_inherits i ON c.reloid = i.inhrelid
JOIN pg_get_class p ON i.inhparent = p.reloid
LEFT JOIN pg_get_rel r ON c.reloid = r.relid 
WHERE p.relkind != 'I'
GROUP BY 1,2;

\pset tableattr 'id="IndInfo"'
SELECT ct.relname AS "Table", ci.relname as "Index",indisunique as "UK?",indisprimary as "PK?",numscans as "Scans",size,ci.blocks_fetched "Fetch",ci.blocks_hit*100/nullif(ci.blocks_fetched,0) "C.Hit%", to_char(i.lastuse,'YYYY-MM-DD HH24:MI:SS') "Last Use"
  FROM pg_get_index i 
  JOIN pg_get_class ct on i.indrelid = ct.reloid and ct.relkind != 't'
  JOIN pg_get_class ci ON i.indexrelid = ci.reloid
ORDER BY size DESC LIMIT 10000;

\pset tableattr 'id="params"'
WITH dset AS (
SELECT string_agg(setting,chr(10)) setting,a.name FROM
(SELECT btrim(CASE WHEN rolname IS NULL THEN '' ELSE 'User: '|| rolname ||' , ' END || CASE WHEN datname IS NULL THEN '' ELSE 'DB: '|| datname END ,' ,') || ' ==> ' ||setting AS setting
,split_part(setting,'=',1) AS name
FROM pg_get_db_role_confs drc
LEFT JOIN LATERAL unnest(config) AS setting ON TRUE
LEFT JOIN pg_get_db db ON drc.db = db.datid
LEFT JOIN pg_get_roles rol ON rol.oid = drc.setrole
ORDER BY 1,2 NULLS LAST
) AS a GROUP BY 2 ),
fset AS (SELECT coalesce(s.name,f.name) AS name
,s.setting,s.unit,s.source
,string_agg(f.sourcefile ||' - '|| f.setting || CASE WHEN f.applied = true THEN ' (applicable)' ELSE '' END ,chr(10)) FILTER (WHERE s.source != f.sourcefile OR s.source IS NULL ) AS loc
FROM pg_get_confs s FULL OUTER JOIN pg_get_file_confs f ON lower(s.name) = lower(f.name)
GROUP BY 1,2,3,4 ORDER BY 1)
SELECT fset.name "Name",fset.setting "Setting",fset.unit "Unit",fset.source "Current Source",
CASE WHEN dset.setting IS NULL THEN '' ELSE dset.setting ||chr(10) END || CASE WHEN fset.loc IS NULL THEN '' ELSE fset.loc END AS "Other Locations & Values"
FROM fset LEFT JOIN dset ON fset.name = dset.name;

\pset footer off
\pset tableattr 'id="tblextn"'
SELECT ext.oid,extname "Extension",rolname "Owner",nsname "Schema", extrelocatable "Relocatable?",extversion "Version" 
FROM pg_get_extension ext LEFT JOIN pg_get_roles ON extowner=pg_get_roles.oid
LEFT JOIN pg_get_ns ON extnamespace = nsoid;

\pset tableattr 'id="tblhba"'
WITH rules AS (SELECT * FROM pg_get_hba_rules WHERE mask IS NOT NULL AND addr NOT IN ('all','samehost','samenet')),
cidr AS (SELECT seq, COALESCE(sum((length(mask) - length(replace(mask, ip4mask.col1, ''))) / length(ip4mask.col1) * ip4mask.col2) ,
 sum((length(mask) - length(replace(mask, ip6mask.col1, ''))) / length(ip6mask.col1) * ip6mask.col2)) "CIDR Mask"
FROM rules
LEFT JOIN (VALUES ('255',8),('254',7),('252',6),('248',5),('240',4),('224',3),('192',2),('128',1)) AS ip4mask (col1,col2)
  ON family(addr::inet) = 4
LEFT JOIN (VALUES ('8',1),('c',2),('e',3),('f',4)) AS ip6mask (col1,col2) ON family(addr::inet) = 6
GROUP BY 1)
SELECT hba.seq "Line",typ "Type",db "DB",usr "USER",addr "Address", "CIDR Mask", mask "DDN/Binary Mask",
CASE WHEN addr IN ('all','samehost','samenet') OR ( mask IS NULL AND addr IS NOT NULL) THEN 'IPv4,IPv6'
 ELSE 'IPv'||family(addr::inet)
END  "IP" ,method "Method", err
FROM  pg_get_hba_rules hba  LEFT JOIN cidr ON cidr.seq = hba.seq;

\pset tableattr 'id="tblcs" class="lineblk thidden"'
WITH db_role AS (SELECT 
pg_get_activity.datid,rolname,count(*) FILTER (WHERE state='active') as active,
count(*) FILTER (WHERE state='idle in transaction') as idle_in_transaction,
count(*) FILTER (WHERE state='idle') as idle,
count(*) as totalcons,
count (*) FILTER (WHERE ssl = true) as sslcons,
count (*) FILTER (WHERE ssl = false) as nonsslcons
FROM pg_get_activity 
  LEFT JOIN pg_get_roles on usesysid=pg_get_roles.oid
  LEFT JOIN pg_get_db on pg_get_activity.datid = pg_get_db.datid
GROUP BY 1,2
ORDER BY 1,2),
db AS (SELECT datid,sum(active) "Active",sum(idle_in_transaction) "IdleInTrans",sum(idle) "Idle",sum(totalcons) "Total",sum(sslcons) "SSL",sum(nonsslcons) "NonSSL"
FROM db_role GROUP BY 1)
SELECT pg_get_db.datname "Database",
(SELECT json_agg(ROW(rolname,active,idle_in_transaction,idle,totalcons,sslcons,nonsslcons)) FROM db_role WHERE db_role.datid = pg_get_db.datid),
"Active","IdleInTrans","Idle","Total","SSL","NonSSL"
FROM pg_get_db LEFT JOIN db ON pg_get_db.datid = db.datid;

\pset tableattr 'id="tblusr" class="thidden"'
WITH rol_db AS (SELECT 
rolname,datname,count(*) FILTER (WHERE state='active') as active,
count(*) FILTER (WHERE state='idle in transaction') as idle_in_transaction,
count(*) FILTER (WHERE state='idle') as idle,
count(*) as totalcons,
count (*) FILTER (WHERE ssl = true) as sslcons,
count (*) FILTER (WHERE ssl = false) as nonsslcons
FROM pg_get_activity 
  join pg_get_roles on usesysid=pg_get_roles.oid
  join pg_get_db on pg_get_activity.datid = pg_get_db.datid
GROUP BY 1,2
ORDER BY 1,2),
rol AS (SELECT rolname,sum(active) "Active",sum(idle_in_transaction) "IdleInTrans",sum(idle) "Idle",sum(totalcons) "Total",sum(sslcons) "SSL",sum(nonsslcons) "NonSSL"
FROM rol_db GROUP BY 1)
SELECT pg_get_roles.rolname "User",
(SELECT json_agg(ROW(datname,active,idle_in_transaction,idle,totalcons,sslcons,nonsslcons)) FROM rol_db WHERE rol_db.rolname = pg_get_roles.rolname),
rolsuper "Super?",rolreplication "Repl?", CASE WHEN rolconnlimit > -1 THEN rolconnlimit ELSE NULL END  "Limit", 
CASE enc_method WHEN 'm' THEN 'MD5' WHEN 'S' THEN 'SCRAM' END "Enc",
"Active","IdleInTrans","Idle","Total","SSL","NonSSL"
FROM pg_get_roles LEFT JOIN rol ON pg_get_roles.rolname = rol.rolname;

\pset tableattr 'id="tableConten" name="waits" style="clear: left"'
\C 'WaitEvents'
SELECT COALESCE(wait_event,'CPU') "Event", count(*)::text FROM pg_pid_wait
WHERE wait_event IS NULL OR wait_event NOT IN ('ArchiverMain','AutoVacuumMain','BgWriterHibernate','BgWriterMain','CheckpointerMain','LogicalApplyMain','LogicalLauncherMain','RecoveryWalStream','SysLoggerMain','WalReceiverMain','WalSenderMain','WalWriterMain','CheckpointWriteDelay','PgSleep','VacuumDelay')
GROUP BY 1 ORDER BY count(*) DESC;

\pset tableattr 'id="tblsess" class="thidden"' 
\C 'Sessions'
SELECT * FROM (
    WITH w AS (SELECT pid, string_agg( wait_event ||': '|| cnt*100::float/2000 ||'%',', ') waits, sum(cnt) pidwcnt, max(max) itr_max, min(min) itr_min FROM
    (SELECT pid,COALESCE(wait_event,'CPU') wait_event,count(*) cnt, max(itr),min(itr) FROM pg_pid_wait GROUP BY 1,2 ORDER BY cnt DESC) pw GROUP BY 1),
  g AS (SELECT max(ts) ts,max(mx_xid) mx_xid FROM
  (SELECT MAX(state_change) as ts,MAX(GREATEST(backend_xid::text::bigint,backend_xmin::text::bigint)) mx_xid FROM pg_get_activity
    UNION
   SELECT NULL, pg_snapshot_xmax(snapshot)::xid::text::bigint mx_xid FROM pg_gather) a),
  wrk AS (select leader_pid, count(*) from pg_get_activity where leader_pid is not null group by 1),
  itr AS (SELECT max(itr_max) gitr_max FROM w)
  SELECT a.pid,to_jsonb(ROW(d.datname,application_name,client_hostname,sslversion,wrk.count)), a.state,r.rolname "User"
  , CASE WHEN a.leader_pid IS NULL THEN host(client_addr) ELSE 'Worker of ' || a.leader_pid END "client"
  , CASE query WHEN '' THEN '**'||backend_type||' process**' ELSE query END "Last statement"
  , g.ts - backend_start "Connection Since", g.ts - xact_start "Transaction Since", g.mx_xid - backend_xmin::text::bigint "xmin age",
   g.ts - query_start "Statement since",g.ts - state_change "State since", w.waits ||
   CASE WHEN (itr_max - itr_min)::float/itr.gitr_max*2000 - pidwcnt > 0 THEN
    ', Net/Delay*: ' || round(((itr_max - itr_min)::float/itr.gitr_max*2000 - pidwcnt)::numeric*100/2000,2) || '%'
   ELSE '' END waits
  FROM pg_get_activity a 
   LEFT JOIN w ON a.pid = w.pid
   LEFT JOIN itr ON true
   LEFT JOIN g ON true
   LEFT JOIN wrk ON wrk.leader_pid = a.pid
   LEFT JOIN pg_get_roles r ON a.usesysid = r.oid
   LEFT JOIN pg_get_db d on a.datid = d.datid
  ORDER BY "xmin age" DESC NULLS LAST) AS sess
WHERE waits IS NOT NULL OR state != 'idle';

\pset tableattr 'id="tblstmnt"'
\C 'Top Statements'
SELECT DENSE_RANK() OVER (ORDER BY ranksum) "Rank", "Statement",time_pct "DB.time%", calls "Execs",total_time::bigint/calls "Avg.ExecTime","Avg.Reads","C.Hit%" 
,"Avg.Dirty","Avg.Write","Avg.Temp(r)","Avg.Temp(w)" FROM 
(select query "Statement",total_time::bigint
, round((100*total_time/sum(total_time) OVER ())::numeric,2) AS time_pct, DENSE_RANK() OVER (ORDER BY total_time DESC) AS tottrank,calls
,total_time::bigint/calls, DENSE_RANK() OVER (ORDER BY total_time::bigint/calls DESC) as avgtrank
,DENSE_RANK() OVER (ORDER BY total_time DESC)+DENSE_RANK() OVER (ORDER BY total_time::bigint/calls DESC) ranksum
,shared_blks_read/calls "Avg.Reads",
shared_blks_dirtied/calls "Avg.Dirty",
shared_blks_written/calls "Avg.Write",
temp_blks_read/calls "Avg.Temp(r)",
temp_blks_written/calls "Avg.Temp(w)"
,100 * shared_blks_hit / nullif((shared_blks_read + shared_blks_hit),0) as "C.Hit%"
from pg_get_statements) AS stmnts
WHERE tottrank < 10 OR avgtrank < 10 ;

\pset tableattr 'id="tblreplstat"'
WITH M AS (SELECT GREATEST((SELECT(current_wal) FROM pg_gather),(SELECT MAX(sent_lsn) FROM pg_replication_stat))),
g AS (SELECT max(mx_xid) mx_xid FROM
(SELECT MAX(GREATEST(backend_xid::text::bigint,backend_xmin::text::bigint)) mx_xid FROM pg_get_activity
  UNION
 SELECT pg_snapshot_xmax(snapshot)::xid::text::bigint mx_xid FROM pg_gather) a)
SELECT usename AS "Replication User",client_addr AS "Replica Address",pid,state,
 pg_wal_lsn_diff(M.greatest, sent_lsn) "Transmission Lag (Bytes)",pg_wal_lsn_diff(sent_lsn,write_lsn) "Replica Write lag(Bytes)",
 pg_wal_lsn_diff(write_lsn,flush_lsn) "Replica Flush lag(Bytes)",pg_wal_lsn_diff(write_lsn,replay_lsn) "Replay at Replica lag(Bytes)",
 slot_name "Slot",plugin,slot_type "Type",datname "DB name",temporary,active,GREATEST(g.mx_xid-old_xmin::text::bigint,0) as "xmin age",
 GREATEST(g.mx_xid-catalog_xmin::text::bigint,0) as "catalog xmin age", GREATEST(pg_wal_lsn_diff(M.greatest,restart_lsn),0) as "Restart LSN lag(Bytes)",
 GREATEST(pg_wal_lsn_diff(M.greatest,confirmed_flush_lsn),0) as "Confirmed LSN lag(Bytes)"
FROM pg_replication_stat JOIN M ON TRUE
  FULL OUTER JOIN pg_get_slots s ON pid = active_pid
  LEFT JOIN g ON TRUE
  LEFT JOIN pg_get_db ON s.datoid = datid;

\pset tableattr 'id="tblchkpnt"'
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
round(100.0*maxwritten_clean/(min_since_reset*60000 / delay.setting::numeric),2)   "Bgwriter halts (%) per runs",
coalesce(round(100.0*maxwritten_clean/(nullif(buffers_clean,0)/ lru.setting::numeric),2),0)  "Bgwriter halt (%) due to LRU hit",
round(min_since_reset/(60*24),1) "Reset days"
FROM pg_get_bgwriter
CROSS JOIN 
(WITH client AS (SELECT sum(evictions) buffers_backend FROM pg_get_io WHERE btype='c')  
SELECT 
    NULLIF(round(extract('epoch' from (select collect_ts from pg_gather) - stats_reset)/60)::numeric,0) min_since_reset,
    GREATEST(buffers_checkpoint + buffers_clean + COALESCE(client.buffers_backend,pg_get_bgwriter.buffers_backend),1) total_buffers,
    NULLIF(checkpoints_timed+checkpoints_req,0) tot_cp,
    COALESCE(client.buffers_backend,pg_get_bgwriter.buffers_backend) buffers_backend
FROM pg_get_bgwriter,client) AS bg
LEFT JOIN pg_get_confs delay ON delay.name = 'bgwriter_delay'
LEFT JOIN pg_get_confs lru ON lru.name = 'bgwriter_lru_maxpages';

\pset tableattr 'id="tbliostat"'
SELECT
CASE btype WHEN 'a' THEN 'Autovacuum' WHEN 'C' THEN 'Client Backend' WHEN 'G' THEN 'BG writer' WHEN 'b' THEN 'background worker' WHEN 'c' THEN 'Clients' 
  WHEN 'k' THEN 'Checkpointer' WHEN 'w' THEN 'WALSender' ELSE btype END As "Backend", 
sum(reads) "Reads",sum(writes) "Writes",sum(writebacks) "Writebacks", sum(extends) "Extends",sum(hits) "Hits",sum(evictions) "Evictions", sum(reuses) "Reuse", sum(fsyncs) "FSyncs"
FROM pg_get_io 
WHERE reads > 0 OR writes > 0  OR writebacks > 0 or extends > 0 OR hits > 0 OR evictions > 0 OR reuses > 0 OR fsyncs > 0
GROUP BY 1;

\echo <ol id="finditem" style="padding:2em;position:relative">
\echo <h3 style="font: italic bold 2em Georgia, serif;text-decoration: underline; margin: 0 0 0.5em;">Findings:</h3>
\pset format aligned
\pset tuples_only on
WITH W AS (SELECT COUNT(*) AS val FROM pg_get_activity WHERE state='idle in transaction')
SELECT CASE WHEN val > 0 
  THEN '<li><b>'||val||' idle-in-transaction</b> session(s). Sessions in idle-in-transaction can cause poor concurrency </li>' 
  ELSE NULL END 
FROM W;
WITH W AS (select last_failed_time,last_archived_time,last_archived_wal from pg_archiver_stat where last_archived_time < last_failed_time)
SELECT CASE WHEN last_archived_time IS NOT NULL
  THEN '<li>WAL archiving is failing since <b>'||last_archived_time||' (duration:'|| (SELECT COALESCE(collect_ts,(SELECT max(state_change) FROM pg_get_activity)) AS c_ts FROM pg_gather) - last_archived_time  ||') onwards</b> '  ||
  CASE WHEN length(last_archived_wal)=24 THEN COALESCE(
  (SELECT ' With estimated size <b>' ||
  pg_size_pretty(((('x'||lpad(split_part(current_wal::TEXT,'/', 1),8,'0'))::bit(32)::bigint - ('x'||substring(last_archived_wal,9,8))::bit(32)::bigint) * 255 * 16^6 + 
  ('x'||lpad(split_part(current_wal::TEXT,'/', 2),8,'0'))::bit(32)::bigint - ('x'||substring(last_archived_wal,17,8))::bit(32)::bigint*16^6 )::bigint)
  FROM pg_gather), ' ') || '</b> behind </li>' ELSE '</li>' END
ELSE NULL END
FROM W;
WITH W AS (select count(*) FILTER (WHERE ct.relkind = 'r') as val, count(*) FILTER (WHERE ct.relkind = 't' ) tval FROM pg_get_index i JOIN pg_get_class ct ON i.indrelid = ct.reloid)
SELECT CASE WHEN val > 10000
  THEN '<li>There are <b>'||val||' Table indexes!</b>  and <b>' || tval || ' Toast Indexes</b> in this database, Only biggest 10000 will be listed in this report under <a href= "#indexes" >Index Info</a>. Please use query No. 11. from the analysis_quries.sql for full details </li>'
  ELSE NULL END
FROM W;
WITH W AS (
 select string_agg(name ||'='||setting,',') as val FROM pg_get_confs WHERE 
 name in ('block_size','max_identifier_length','max_function_args','max_index_keys','segment_size','wal_block_size') AND 
 (name,setting) NOT IN (('block_size','8192'),('max_identifier_length','63'),('max_function_args','100'),('max_index_keys','32'),('segment_size','131072'),('wal_block_size','8192'))
 OR (name = 'wal_segment_size' AND unit ='8kB' and setting != '2048') OR (name = 'wal_segment_size' AND unit ='B' and setting != '16777216')  
)
SELECT CASE WHEN LENGTH(val) > 1
  THEN '<li>Detected Non-Standard Compile/Initialization time parameter changes <b>'||val||' </b>. Custom Compilation is prone to bugs, and it is beyond supportability</li>'
  ELSE NULL END
FROM W;
WITH W AS (
SELECT count(*) cnt FROM pg_get_confs WHERE source IS NOT NULL )
SELECT CASE WHEN cnt < 1
  THEN '<li>Couldn''t get parameter values. Partial gather or corrupt Parameter file(s)</li>'
  ELSE NULL END
FROM W;
SELECT '<li>Parameter '||error ||': '||name||' = '||setting||' in '||sourcefile||'</li>' FROM pg_get_file_confs WHERE error IS NOT NULL;

\echo </ol>
\echo <div id="analdata" hidden>
\pset format unaligned
SELECT to_jsonb(r) FROM
(SELECT 
  (select recovery from pg_gather) AS clsr,
  (SELECT to_jsonb(ROW(count(*),COUNT(*) FILTER (WHERE last_vac IS NULL), COUNT(*) FILTER (WHERE b.table_oid IS NULL AND r.n_live_tup != 0 ),COUNT(*) FILTER (WHERE last_anlyze IS NULL))) 
  FROM pg_get_rel r JOIN pg_get_class c ON r.relid = c.reloid AND c.relkind NOT IN ('t','p')
LEFT JOIN pg_tab_bloat b ON c.reloid = b.table_oid) AS tabs,
  (SELECT to_jsonb(ROW(COUNT(*),COUNT(*) FILTER (WHERE CONN < interval '15 minutes' ) )) FROM 
    (WITH g AS (SELECT MAX(state_change) as ts FROM pg_get_activity)
    SELECT pid,g.ts - backend_start CONN
    FROM pg_get_activity
    LEFT JOIN g ON true
    WHERE EXISTS (SELECT pid FROM pg_pid_wait WHERE pid=pg_get_activity.pid)
    AND backend_type='client backend') cn) AS cn,
  (SELECT to_jsonb(ROW(count(*) FILTER (WHERE relkind='p'), count(*) FILTER (WHERE relkind='r' AND relpersistence='u'), max(reloid))) from pg_get_class) as clas,
  (SELECT to_jsonb(ROW(count(*) FILTER (WHERE state='active' AND state IS NOT NULL), 
  count(*) FILTER (WHERE state='idle in transaction'), count(*) FILTER (WHERE state='idle'),
  count(*) FILTER (WHERE state IS NULL), count(*) FILTER (WHERE leader_pid IS NOT NULL) ,
  count(*),   count(distinct backend_type)))
  FROM pg_get_activity) as sess,
  (WITH curdb AS (SELECT 
  CASE WHEN (SELECT COUNT(*) FROM pg_srvr) > 0 
    THEN (SELECT trim(both '\"' from substring(connstr from '\"\w*\"')) "curdb" FROM pg_srvr WHERE connstr like '%to database%') ELSE (SELECT 'template1' "curdb")
  END),
  cts AS (SELECT COALESCE((SELECT COALESCE(collect_ts,(SELECT max(state_change) FROM pg_get_activity)) FROM pg_gather),current_timestamp) AS c_ts)
  SELECT to_jsonb(ROW(curdb,COALESCE(pg_get_db.stats_reset,pg_get_wal.stats_reset),c_ts,days))
  FROM  curdb LEFT JOIN pg_get_db ON pg_get_db.datname=curdb.curdb
  LEFT JOIN pg_get_wal ON true
  LEFT JOIN LATERAL (SELECT GREATEST((EXTRACT(epoch FROM(c_ts- COALESCE(pg_get_db.stats_reset,pg_get_wal.stats_reset)))/86400)::bigint,1) as days FROM cts) AS lat1 ON TRUE
  LEFT JOIN cts ON true) as dbts,
  (WITH maxmxid AS (SELECT max(mxidage) FROM pg_get_db),
  topdbmx AS (SELECT array_agg(datname),maxmxid.max FROM pg_get_db JOIN maxmxid ON pg_get_db.mxidage=maxmxid.max AND pg_get_db.mxidage > 1000 GROUP BY 2)
  SELECT to_jsonb(ROW(array_agg,max)) FROM topdbmx) AS mxiddbs,
  (SELECT json_agg(pg_get_ns) FROM  pg_get_ns) AS ns,
  (SELECT json_agg(pg_get_tablespace) FROM pg_get_tablespace) AS tbsp,
  (SELECT to_jsonb((extract (EPOCH FROM (collect_ts - last_archived_time)), pg_wal_lsn_diff( current_wal,
  (coalesce(nullif(CASE WHEN length(last_archived_wal) < 24 THEN '' ELSE ltrim(substring(last_archived_wal, 9, 8), '0') END, ''), '0') || '/' || substring(last_archived_wal, 23, 2) || '000001'        ) :: pg_lsn )
  , last_archived_wal, last_archived_time::text || ' (' || CASE WHEN EXTRACT(EPOCH FROM(collect_ts - last_archived_time)) < 0 THEN 'Right Now'::text ELSE (collect_ts - last_archived_time)::text END  || ')'))
  FROM  pg_gather,  pg_archiver_stat) AS arcfail,
  (SELECT to_jsonb(ROW(max(setting) FILTER (WHERE name = 'archive_library'), max(setting) FILTER (WHERE name = 'cluster_name'),count(*) FILTER (WHERE source = 'command line'))) FROM pg_get_confs) AS params,
  (WITH g AS (SELECT collect_ts,pg_start_ts,reload_ts,to_timestamp ( systemid >> 32 ) init_ts from pg_gather),
    r AS (SELECT LEAST(min(last_vac),min(last_anlyze)) known_ts FROM pg_get_rel)
  SELECT CASE WHEN (g.init_ts IS NULL OR g.reload_ts - g.init_ts > '80 minutes'::interval) AND ( r.known_ts > g.reload_ts OR r.known_ts IS NULL) AND g.collect_ts - g.reload_ts < '10 days'::interval 
  THEN g.reload_ts END crash_ts FROM g,r) crash,
  (WITH blockers AS (select array_agg(victim_pid) OVER () victim,blocking_pids blocker from pg_get_pidblock),
   ublokers as (SELECT unnest(blocker) AS blkr FROM blockers)
   SELECT json_agg(blkr) FROM ublokers
   WHERE NOT EXISTS (SELECT 1 FROM blockers WHERE ublokers.blkr = ANY(victim))) blkrs,
  (select json_agg((victim_pid,blocking_pids)) from pg_get_pidblock) victims,
  (SELECT  to_jsonb(( EXTRACT(epoch FROM (end_ts - collect_ts)),  pg_wal_lsn_diff(end_lsn, current_wal) * 60 * 60 / EXTRACT( epoch FROM (end_ts - collect_ts) ),
  wal_bytes/(extract (EPOCH FROM  (collect_ts - stats_reset))/3600)))
  FROM pg_gather JOIN pg_gather_end ON true
   LEFT JOIN pg_get_wal ON true) sumry,
  (SELECT json_agg((relname,maint_work_mem_gb)) FROM (SELECT relname,n_live_tup*0.2*6 maint_work_mem_gb 
   FROM pg_get_rel JOIN pg_get_class ON n_live_tup > 894784853 AND pg_get_rel.relid = pg_get_class.reloid 
   ORDER BY 2 DESC LIMIT 3) AS wmemuse) wmemuse,
   (WITH w AS (SELECT pid,count(*) cnt, max(itr) itr_max,min(itr) itr_min FROM pg_pid_wait group by 1),
   g AS (SELECT max(itr_max) gmax_itr FROM w)
  SELECT to_jsonb(ROW(SUM(((itr_max - itr_min)::float/gmax_itr)*2000 - cnt),max(gmax_itr),count(pid))) FROM w,g
   WHERE ((itr_max - itr_min)::float/gmax_itr)*2000 - cnt > 0) netdlay,
   (SELECT to_jsonb(ROW(count(*) FILTER (WHERE indisvalid=false)
   ,count(*) FILTER (WHERE numscans=0 AND tst.toastid IS NULL) --Unused Indexes of user tables
   ,count(*) FILTER (WHERE numscans=0 AND tst.toastid > 16384) --Unused TOAST index of user tables
   ,count(*) FILTER (WHERE tst.toastid IS NULL) --TOTAL User/Regular indexes
   ,count(*) FILTER (WHERE tst.toastid > 16384) --TOTAL Toast Indexes
   ,sum(size) FILTER (WHERE numscans=0)))
    FROM pg_get_index i
    JOIN pg_get_class ct ON i.indrelid = ct.reloid
    LEFT JOIN pg_get_toast tst ON ct.reloid = tst.toastid) induse,
    (WITH pkuk AS (SELECT indrelid,bool_or(indisprimary) pk,bool_or(indisunique) uk FROM pg_get_index GROUP BY indrelid)
    SELECT to_jsonb(ROW(COUNT(*) FILTER (WHERE pkuk.pk IS NULL OR NOT pkuk.pk), COUNT(*) FILTER (WHERE pkuk.uk IS NULL OR NOT pkuk.uk)))
    FROM pg_get_class c LEFT JOIN pkuk ON pkuk.indrelid = c.reloid WHERE c.relkind IN ('r')) nokey,
   (SELECT to_jsonb(ROW(sum(tab_ind_size) FILTER (WHERE relid < 16384),count(*))) FROM pg_get_rel) meta
) r;

\echo </div>
\echo </div> <!--End of "sections"-->
\echo <footer>End of <a href="https://github.com/jobinau/pg_gather">pgGather</a> Report</footer>
\echo <script type="text/javascript">
\echo ver="29";
\echo obj={};
\echo docurl="https://jobinau.github.io/pg_gather/";
\echo meta={pgvers:["12.22","13.18","14.15","15.10","16.6","17.2"],commonExtn:["plpgsql","pg_stat_statements"],riskyExtn:["citus","tds_fdw"]};
\echo mgrver="";
\echo datadir="";
\echo autovacuum_freeze_max_age = 0;
\echo let strfind = "";
\echo totdb=0;
\echo totCPU=4; 
\echo totMem=8; 
\echo wrkld="";
\echo let blokers = []
\echo let blkvictims = []
\echo let params = []
\echo document.addEventListener("DOMContentLoaded", () => {
\echo obj=JSON.parse( document.getElementById("analdata").innerText);
\echo if (obj.victims !== null){
\echo obj.victims.forEach(function(victim){
\echo   blkvictims.push(victim.f1);
\echo });
\echo obj.victims.forEach(function(victim){
\echo   victim.f2.forEach(function(blker){
\echo     if (blkvictims.indexOf(blker) == -1 && blokers.indexOf(blker) == -1) blokers.push(blker);
\echo   });
\echo });
\echo }
\echo checkgather();
\echo checkpars();
\echo checktabs();
\echo checkindex();
\echo checkdbs();
\echo checkdbtime();
\echo checkextn();
\echo checkhba();
\echo checkconns();
\echo checkusers();
\echo checksess();
\echo checkstmnts();
\echo checkchkpntbgwrtr();
\echo checkiostat()
\echo checkfindings();
\echo });
\echo window.onload = function() {
\echo   document.getElementById("sections").style="display:table";
\echo   document.getElementById("busy").style="display:none";
\echo };
\echo function checkgather(){
\echo   const trs=document.getElementById("tblgather").rows
\echo   let days,xmax=0;
\echo   for (let i = 0; i < trs.length; i++) {
\echo     val = trs[i].cells[1];
\echo     switch(trs[i].cells[0].innerText){
\echo       case "pg_gather" :
\echo         val.innerText = val.innerText + "-v" + ver;
\echo         break;
\echo       case "Collected By" :
\echo         if (val.innerText.slice(-2) < ver ) { val.classList.add("warn"); val.title = "Data is collected using old/obsolete version of gather.sql file. Please use v" + ver; 
\echo         strfind += "<li>Data collected using old/obsolete version (v"+ val.innerText.slice(-2) + ") of gather.sql file. Please use v" + ver + " <a href='"+ docurl +"versionpolicy.html'>Details</a></li>";
\echo         }
\echo         break;
\echo       case "In recovery?" :
\echo         if(val.innerText == "true") {val.classList.add("lime"); val.title="Data collected at standby"; obj.primary = false;}
\echo         else obj.primary = true; 
\echo         break;
\echo       case "System" :  
\echo         let startIndex = val.innerText.indexOf("(") + 1;
\echo         days = parseInt(val.innerText.substring(startIndex,val.innerText.indexOf(" days", startIndex)));
\echo         break;
\echo       case "Latest xid" :
\echo         xmax = parseInt(val.innerText);
\echo         break;
\echo       case "Oldest xid ref" :
\echo         val.innerText += " (" + (xmax - parseInt(val.innerText)).toString() + " xids old)";
\echo         break;
\echo       case "Time Line" :
\echo         let Failover = parseInt(val.innerText.substring(0,val.innerText.indexOf(" (")))-1;
\echo         if (days > 30 && Failover > 5){
\echo           let MTBF = days/Failover;
\echo           if (MTBF < 180){
\echo             val.classList.add("warn"); val.title = "Poor MTBF / Availability number. There were " + Failover + " failovers in " + days + " days." ;
\echo             strfind += "<li><b>Poor MTBF / Availability number: "+ Math.round(MTBF) +" days!</b>. There were " + Failover + " failovers in " + days + " days</li>";
\echo           }
\echo         }
\echo     }
\echo   }
\echo }
\echo function checkfindings(){
\echo  let tmpstr = "";
\echo  if (obj.sess.f7 < 4){ 
\echo   strfind += "<li><b>The pg_gather data is collected by a user who don't have necessary privilege OR Content of the output file (out.txt) is copy-pasted destroying the TSV format</b><br/><b>1.</b>Please run the gather.sql as a privileged user (superuser, rds_superuser etc.) or some account with pg_monitor privilege and <b>2.</b> Please provide the output file as it is without copy-pasting</li>"
\echo   document.getElementById("tableConten").title="Waitevents data will be growsly incorrect because the pg_gather data is collected by a user who don't have proper privilege OR content of output file is copy-pasted. Please refer the Findings section";
\echo   document.getElementById("tableConten").caption.innerHTML += "<br/>" + document.getElementById("tableConten").title
\echo   document.getElementById("tableConten").classList.add("high");
\echo  }
\echo  if (obj.cn.f1 > 0){
\echo     strfind +="<li><b>" + obj.cn.f2 + " / " + obj.cn.f1 + " connections </b> in use are new. "
\echo     if (obj.cn.f2 > 9 || obj.cn.f2/obj.cn.f1 > 0.7 ){
\echo       strfind+="Please consider this for improving connection pooling"
\echo     } 
\echo     strfind += "</li>";
\echo  }
\echo  if (obj.induse.f1 > 0 ) strfind += "<li><b>"+ obj.induse.f1 +" Invalid Index(es)</b> found. Recreate or drop them. Refer <a href='"+ docurl +"InvalidIndexes.html'>Details</a></li>";
\echo  if (obj.induse.f2 > 0 ) strfind += "<li><b>"+ obj.induse.f2 +" regular user indexes and " + obj.induse.f3 + " Toast Indexes are unused,</b> out of " + obj.induse.f4 + " user indexes and " + obj.induse.f5 + " Toast Indexes . Currently the unused indexes needs <b>additional "+ bytesToSize(obj.induse.f6) +" to cache</b>. <a href='"+ docurl +"unusedIndexes.html'>Details</a></li>";
\echo  if (obj.mxiddbs !== null) strfind += "<li> Multi Transaction ID age : <b>" + obj.mxiddbs.f2 + "</b> for databases  <b>" + obj.mxiddbs.f1 + "</b> <a href='"+ docurl +"mxid.html'>Details</a></li>"
\echo  if (obj.clas.f1 > 0) strfind += "<li><b>"+ obj.clas.f1 +" Natively partitioned tables</b> found. Tables section could contain partitions</li>";
\echo  if (obj.clas.f2 > 0) strfind += "<li><b>"+ obj.clas.f2 +" Unlogged tables found.</b> These tables and associated indexes are ephemeral. <a href='"+ docurl +"unloggedtables.html'>Details</a></li>";
\echo  if (obj.params.f3 > 10) strfind += "<li> Patroni/HA PG cluster :<b>" + obj.params.f2 + "</b></li>"
\echo  if (obj.crash !== null) strfind += "<li>Detected a <b>suspected crash / unclean shutdown around : " + obj.crash + ".</b> Please check the PostgreSQL logs</li>"
\echo  if (obj.nokey.f1 > 0) strfind += "<li><b>"+ obj.nokey.f1 +" Tables without Primary Key</b> and <b>"+ obj.nokey.f2 +" Tables without niether Primary key nor Unique keys</b> found. Please refer <a href='"+ docurl +"pkuk.html'>Details</a></li>";
\echo  if (obj.netdlay.f1 > 10) {
\echo    if (obj.netdlay.f1 / obj.netdlay.f2 * 100 > 20 ){ strfind += "<li> There are <b>"+ obj.netdlay.f3 +" Sessions with considerable Net/Delays</b>"
\echo    tmpstr = "Total <a href='"+ docurl +"NetDelay.html'>Net/Delay<a>"
\echo    if (obj.netdlay.f1 / obj.netdlay.f2 > 1){
\echo       tmpstr += " is <b>" + (obj.netdlay.f1 / obj.netdlay.f2).toFixed(1) + "Times ! </b> of overall server activity. which is huge"
\echo    }else if(obj.netdlay.f1 / obj.netdlay.f2 > 0.1){
\echo     tmpstr += " is equivalent to <b>" + (obj.netdlay.f1 * 100 / obj.netdlay.f2).toFixed(2) + "% </b> of server activity"
\echo    }
\echo    if (tmpstr.length > 100 ){
\echo     strfind += "<li>" + tmpstr + "</li>"
\echo     document.getElementById("tableConten").tFoot.children[0].children[0].innerHTML += tmpstr
\echo    }
\echo   }
\echo  }
\echo  for (let item of params) { 
\echo     if (typeof item.warn != "undefined"){
\echo      strfind += "<li>" + item.warn +"</li>";
\echo     }
\echo   }
\echo  if(obj.clsr){
\echo   strfind += "<li>PostgreSQL is in Standby mode or in Recovery</li>";
\echo  }else{
\echo   if ( obj.tabs.f2 > 0 ) strfind += "<li> <b>No vacuum info for " + obj.tabs.f2 + "</b> tables/objects </li>";
\echo   if ( obj.tabs.f3 > 0 ) strfind += "<li> <b>No statistics available for " + obj.tabs.f3 + " tables/objects</b>, query planning can go wrong. <a href='"+ docurl +"missingstats.html'>Learn Details</a></li>";
\echo   if ( obj.tabs.f1 > 10000) strfind += "<li> There are <b>" + obj.tabs.f1 + " tables/objects</b> in the database. Only the biggest 10000 will be displayed in the report. Avoid too many tables/objects in single database. <a href='"+ docurl +"table_object.html'>Learn Details</a></li>";
\echo   if (obj.arcfail != null) {
\echo    if (obj.arcfail.f1 == null) strfind += "<li>No working WAL archiving and backup detected. PITR may not be possible</li>";
\echo    if (obj.arcfail.f1 > 300) strfind += "<li>No WAL archiving happened in last "+ Math.round(obj.arcfail.f1/60) +" minutes. <b>Archiving could be failing</b>; please check PG logs</li>";
\echo    if (obj.arcfail.f2 && obj.arcfail.f2 > 0) strfind += "<li>WAL archiving is <b>lagging by "+ bytesToSize(obj.arcfail.f2,1024)  +"</b>. Last archived WAL is : <b>"+ obj.arcfail.f3 +"</b> at "+ obj.arcfail.f4 +"</li>";
\echo   }
\echo   if (obj.wmemuse !== null && obj.wmemuse.length > 0){ strfind += "<li> Biggest <code>maintenance_work_mem</code> consumers are :<b>"; obj.wmemuse.forEach(function(t,idx){ strfind += (idx+1)+". "+t.f1 + " (" + bytesToSize(t.f2) + ")    " }); strfind += "</b></li>"; }
\echo   if (obj.victims !== null && obj.victims.length > 0) strfind += "<li><b>" + obj.victims.length + " session(s) blocked.</b></li>"
\echo   if (obj.sumry !== null){ strfind += "<li>Data collection took <b>" + obj.sumry.f1 + " seconds. </b>";
\echo      if ( obj.sumry.f1 < 23 ) strfind += "System response is good</li>";
\echo      else if ( obj.sumry.f1 < 28 ) strfind += "System response is below average</li>";
\echo      else strfind += "System response appears to be poor</li>";
\echo      strfind += "<li>Current WAL generation rate is <b>" + bytesToSize(obj.sumry.f2) + " / hour</b>"; 
\echo      if (obj.sumry.f3 !== null ) strfind += ", Long term average WAL generation rate is <b>" + bytesToSize(obj.sumry.f3) + "/hour</b></li>"; 
\echo      else strfind += "</li>" }
\echo   if ( mgrver.length > 0 &&  mgrver < Math.trunc(meta.pgvers[0])) strfind += "<li>PostgreSQL <b>Version : " + mgrver + " is outdated (EOL) and not supported</b>, Please upgrade urgently</li>";
\echo   if (obj.ns !== null){
\echo    let tempNScnt = obj.ns.filter(n => n.nsname.indexOf("pg_temp") > -1).length + obj.ns.filter(n => n.nsname.indexOf("pg_toast_temp") > -1).length ;
\echo    tmpfind = "<li><b>" + (obj.ns.length - tempNScnt).toString()  + " Regular schema(s) and " + tempNScnt + " temporary schema(s)</b> in this database. <a href='"+ docurl +"schema.html'> Details<a>";
\echo    if (tempNScnt > 0 && obj.clas.f3 > 50000) tmpfind += "<br>Currently oid of pg_class stands at " + Number(obj.clas.f3).toLocaleString("en-US") + " <b>indicating the usage of temp tables</b>"
\echo    strfind += tmpfind + "</li>";
\echo   }
\echo   if (obj.meta.f1 > 15728640){
\echo     strfind += "<li>" + "The catalog metadata is :<b>" + bytesToSize(obj.meta.f1) + " For " + obj.meta.f2 + " objects. </b><a href='"+ docurl +"catalogbloat.html'> Details<a></li>"
\echo   }
\echo  }
\echo   document.getElementById("finditem").innerHTML += strfind;
\echo   var el=document.createElement("tfoot");
\echo   el.innerHTML = "<th colspan='9'>**Averages are Per Day. Total size of "+ (document.getElementById("dbs").tBodies[0].rows.length - 1) +" DBs : "+ bytesToSize(totdb) +"</th>";
\echo   dbs=document.getElementById("dbs");
\echo   dbs.appendChild(el);
\echo }
\echo function checkconns(){
\echo   tab=document.getElementById("tblcs");
\echo   tab.caption.innerHTML=''''<span>DB Connections</span>'''';
\echo   const trs=tab.rows
\echo   let nonssl=0;
\echo   for (var i=1;i<trs.length;i++){
\echo     tr=trs[i];
\echo     if (tr.cells[7].innerText > 0) nonssl += parseInt(tr.cells[7].innerText);
\echo     if (tr.cells[5].innerText > 20 && tr.cells[7].innerText/tr.cells[5].innerText > 0.5 ){
\echo       tr.cells[7].classList.add("warn");
\echo       tr.cells[7].title="Large precentage of unencrypted connections"
\echo     }
\echo   }
\echo   if (nonssl > 10) strfind += "<li>Number of unencrypted connections : <b>"+ nonssl +"</b></li>"
\echo   el=document.createElement("tfoot"); 
\echo   el.innerHTML = "<th colspan='7'>Active: "+ obj.sess.f1 +", Idle-in-transaction: " + obj.sess.f2 + ", Idle: " + obj.sess.f3 + ", Background: " + obj.sess.f4 + ", Workers: " + obj.sess.f5 + ", Total: " + obj.sess.f6 + "</th>";
\echo   tab.appendChild(el);
\echo }
\echo ["cpus","mem","strg","wrkld","flsys"].forEach(function(t) {document.getElementById(t).addEventListener("change", (event) => { getreccomendation(); })});
\echo function getreccomendation(){
\echo   totMem = document.getElementById("mem").value;
\echo   totCPU = document.getElementById("cpus").value;
\echo   wrkld = document.getElementById("wrkld").value;
\echo   checkpars();
\echo   let reccomandations = document.getElementById("paramtune").children[1];
\echo   let reccos = "";
\echo   for (let item of params) {
\echo     if (typeof item.suggest != "undefined"){
\echo      reccos += "<li>" + item.param + " = " + item.suggest + "&emsp;<a href='"+ docurl +"params/" + item.param +".html'>#Explanation</a></li>"
\echo     }
\echo   }
\echo   reccomandations.innerHTML = reccos;
\echo }
\echo function flash(msg){
\echo   var el=document.createElement("div");
\echo   el.setAttribute("id", "cur");
\echo   el.setAttribute("style", "position: fixed;top: 50%;left: 50%;transform: translate(-50%, -50%);");
\echo   el.textContent = msg;
\echo   document.body.appendChild(el);
\echo   setTimeout(() => { el.remove();},2000);
\echo }
\echo function copyashtml(){
\echo   let elem = document.getElementById("paramtune");
\echo   let paramtune = elem.cloneNode(true);
\echo   paramtune.style="font-weight:initial;line-height:1.5em;background-color:#FAFFEA;border: 2px solid blue; border-radius: 5px; padding: 1em;box-shadow: 0px 20px 30px -10px grey";
\echo   navigator.clipboard.writeText(paramtune.outerHTML);
\echo   flash("Parameter recommendations are copied to clipboard as HTML code");
\echo }
\echo function copyrichhtml(){
\echo   let elem = document.getElementById("paramtune")
\echo   let paramtune = elem.cloneNode(true);
\echo   paramtune.style="font-weight:initial;line-height:1.5em;background-color:#FAFFEA;border: 2px solid blue; border-radius: 5px; padding: 1em;box-shadow: 0px 20px 30px -10px grey";
\echo   const clipboardItem = new ClipboardItem({	"text/plain": new Blob([paramtune.innerText],	{ type: "text/plain" }),
\echo               "text/html": new Blob([paramtune.outerHTML],{ type: "text/html" })});
\echo   navigator.clipboard.write([clipboardItem]);
\echo   flash("Parameter recommendations are copied to clipboard as HTML Rich object");
\echo }
\echo function bytesToSize(bytes,divisor = 1000) {
\echo   const sizes = ["B","KB","MB","GB","TB"];
\echo   if (bytes == 0) return "0B";
\echo   const i = parseInt(Math.floor(Math.log(bytes) / Math.log(divisor)), 10);
\echo   if (i === 0) return bytes + sizes[i];
\echo   return (bytes / (divisor ** i)).toFixed(1) + sizes[i]; 
\echo }
\echo function setheadtip(th,tips){
\echo   for (i in tips) th.cells[i].title = tips[i];
\echo }
\echo function updateJson(jsonString, key, value) {
\echo   const jsonObject = JSON.parse(jsonString);
\echo   jsonObject[key] = value;
\echo   return JSON.stringify(jsonObject);
\echo }
\echo function DurationtoSeconds(duration){
\echo     let days=0,dayIdx
\echo     dayIdx=duration.indexOf("days")
\echo     if(dayIdx>0){
\echo       days=parseInt(duration.substring(0,dayIdx))
\echo       duration=duration.substring(dayIdx+5)
\echo     }
\echo     const [hours, minutes, seconds] = duration.split(":");
\echo     return days * 24 * 60 * 60 +(hours) * 60 * 60 + Number(minutes) * 60 + Number(seconds);
\echo };
\echo var paramDespatch = {
\echo   archive_mode : function(rowref){
\echo     val=rowref.cells[1];
\echo     if(obj.primary  == true && val.innerHTML == "off"){ val.classList.add("warn"); val.title="Primary server without WAL archiving configured. No PITR possible"}
\echo   },
\echo   archive_command : function(rowref) {
\echo     val=rowref.cells[1];
\echo     if (obj.params !== null && obj.params.f1 !== null && obj.params.f1.length > 0) { val.classList.add("warn"); val.title="archive_command won't be in-effect, because archive_library : " + obj.arclib + " is specified"  }
\echo     else if (val.innerText.length < 5) {val.classList.add("warn"); val.title="A valid archive_command is expected for WAL archiving, unless archive library is used" ; }
\echo   },
\echo   autovacuum : function(rowref) {
\echo     val=rowref.cells[1];
\echo     if(val.innerText != "on") { val.classList.add("warn"); val.title="Autovacuum must be on" }
\echo   },
\echo   autovacuum_max_workers : function(rowref) {
\echo     val=rowref.cells[1];
\echo     if(val.innerText > 3) { val.classList.add("warn"); val.title="High number of workers causes each workers to run slower because of the cost limit" ;
\echo       let param = params.find(p => p.param === "autovacuum_max_workers");
\echo       param["suggest"] = "3";
\echo     }
\echo   },
\echo   autovacuum_vacuum_cost_limit: function(rowref){
\echo     val=rowref.cells[1];
\echo     if(val.innerText > 800 || val.innerText == -1 ) { val.classList.add("warn"); val.title="Better to specify this with a value less than 800" }
\echo   },
\echo   autovacuum_freeze_max_age: function(rowref){
\echo     val=rowref.cells[1];
\echo     autovacuum_freeze_max_age = Number(val.innerText); 
\echo     if (autovacuum_freeze_max_age > 800000000) val.classList.add("warn");
\echo   },
\echo   bgwriter_lru_maxpages: function(rowref){
\echo     let param = params.find(p => p.param === "bgwriter_lru_maxpages");
\echo     if (typeof param["suggest"] != "undefined"){
\echo       val = val=rowref.cells[1];
\echo       val.classList.add("warn"); 
\echo       val.title="bgwriter_lru_maxpages is too low. Increase this to :" + param["suggest"];
\echo     }
\echo   },
\echo   checkpoint_timeout: function(rowref){
\echo     val=rowref.cells[1];
\echo     if(val.innerText < 1200) { val.classList.add("warn"); val.title="Too small gap between checkpoints"}
\echo   },
\echo   data_directory: function(rowref){
\echo     datadir=val.innerText;
\echo   },
\echo   deadlock_timeout: function(rowref){ val=rowref.cells[1]; val.classList.add("lime"); },
\echo   effective_cache_size: function(rowref){ val=rowref.cells[1]; val.classList.add("lime"); val.title=bytesToSize(val.innerText*8192,1024); }, 
\echo   huge_pages: function(rowref){ 
\echo     val=rowref.cells[1]; 
\echo     if (val.innerText != "on" ) {
\echo       val.classList.add("warn");
\echo       let param = params.find(p => p.param === "huge_pages");
\echo       param["suggest"] = "on";
\echo     } else val.classList.add("lime"); 
\echo   },
\echo   huge_page_size: function(rowref){ val=rowref.cells[1]; val.classList.add("lime"); },
\echo   hot_standby_feedback: function(rowref){ val=rowref.cells[1]; val.classList.add("lime"); },
\echo   idle_session_timeout:function(rowref){ 
\echo     val=rowref.cells[1]; 
\echo     if (val.innerText > 0) { val.classList.add("warn"); val.title="It is dangerous to use idle_session_timeout. Avoid using this" }
\echo   },
\echo   idle_in_transaction_session_timeout: function(rowref){ 
\echo     val=rowref.cells[1]; 
\echo     if (val.innerText == 0){ val.classList.add("warn"); val.title="Highly suggestable to use atleast 5min to prevent application misbehaviour" }
\echo     let param = params.find(p => p.param === "idle_in_transaction_session_timeout");
\echo     param["suggest"] = "'5min'";
\echo   },
\echo   jit: function(rowref){ val=rowref.cells[1]; if (val.innerText=="on") { 
\echo     val.classList.add("warn");
\echo     val.title="Avoid JIT globally (Disable), Use only at smaller scope" 
\echo     let param = params.find(p => p.param === "jit");
\echo     param["suggest"] = "off";
\echo   }},
\echo   log_temp_files: function(rowref){
\echo     val = val=rowref.cells[1];
\echo     let param = params.find(p => p.param === "log_temp_files");
\echo     if (typeof param["suggest"] != "undefined"){
\echo       val.classList.add("warn"); 
\echo       val.title="Heavy temporary file generation is detected. Consider setting log_temp_files=" + param["suggest"] ;
\echo     } else if ((param["val"] > -1)){
\echo       val.classList.add("lime");
\echo       val.title="log_temp_files is already set. Analyze PostgreSQL log for problematic SQLs. Adjust parameter value if required";
\echo     }
\echo   },
\echo   log_truncate_on_rotation: function(rowref){
\echo     val=rowref.cells[1];
\echo     let param = params.find(p => p.param === "log_truncate_on_rotation");
\echo     if (val.innerText == "off")  param["suggest"] = "on";
\echo   },
\echo   log_lock_waits: function(rowref){
\echo     val=rowref.cells[1]; let param = params.find(p => p.param === "log_lock_waits");
\echo     if(val.innerText == "off") param["suggest"] = "on";
\echo   },
\echo   lock_timeout: function(rowref){
\echo     val=rowref.cells[1]; let param = params.find(p => p.param === "lock_timeout");
\echo     if(val.innerText == "0") param["suggest"] = "'1min'";
\echo   },
\echo   maintenance_work_mem: function(rowref){ val=rowref.cells[1]; val.classList.add("lime"); val.title=bytesToSize(val.innerText*1024,1024); },
\echo   max_connections: function(rowref){
\echo     val=rowref.cells[1];
\echo     val.title="Avoid value exceeding 10x of the CPUs"
\echo     if( totCPU > 0 ){
\echo       if(val.innerText > 10 * totCPU) { 
\echo         val.classList.add("warn"); val.title="If there is only " + totCPU + " CPUs value above " + 10*totCPU + " Is not recommendable for performance and stability";
\echo         let conns = params.find(p => p.param === "max_connections");
\echo         conns["suggest"] = 10 * totCPU;
\echo       }else { val.classList.remove("warn"); val.classList.add("lime"); val.title="Current value is good" }
\echo     } else if (val.innerText > 500) val.classList.add("warn")
\echo       else val.classList.add("lime")
\echo   },
\echo   max_standby_archive_delay: function(rowref){
\echo     val=rowref.cells[1];
\echo     let param = params.find(p => p.param === "max_standby_archive_delay");
\echo     if (val.innerText > 30000){ param["suggest"] = "30000"; val.classList.add("lime") }
\echo   },
\echo   max_standby_streaming_delay: function(rowref){
\echo     val=rowref.cells[1];
\echo     let param = params.find(p => p.param === "max_standby_streaming_delay");
\echo     if (val.innerText > 30000){ param["suggest"] = "30000"; val.classList.add("lime");}
\echo   },
\echo   max_wal_size: function(rowref){
\echo     val=rowref.cells[1];
\echo     val.title=bytesToSize(val.innerText*1024*1024,1024);
\echo     if(val.innerText < 8192) { val.classList.add("warn"); val.title += ",Too low for production use" }
\echo     else val.classList.add("lime");
\echo   },
\echo   min_wal_size: function(rowref){
\echo     val=rowref.cells[1];
\echo     val.title=bytesToSize(val.innerText*1024*1024,1024);
\echo     if(val.innerText < 2048) {val.classList.add("warn"); val.title+=",Too low for production use" }
\echo     else val.classList.add("lime");
\echo   },
\echo   parallel_leader_participation: function(rowref){
\echo     val=rowref.cells[1];
\echo     let param = params.find(p => p.param === "parallel_leader_participation");
\echo     if (wrkld == "oltp" && val.innerText == "off") param["suggest"] = "on";
\echo     else if (wrkld == "olap" && val.innerText == "on") param["suggest"] = "off" ;
\echo     else delete param["suggest"];
\echo   },
\echo   random_page_cost: function(rowref){
\echo     val=rowref.cells[1];
\echo     let param = params.find(p => p.param === "random_page_cost");
\echo     let strg = document.getElementById("strg").value;
\echo   if ( strg == "ssd" ){
\echo     if (val.innerText > 1.2){param["suggest"] = "1.1";   val.classList.add("warn");}
\echo     else val.classList.add("lime");
\echo   } else if ( strg == "san" ){
\echo     if (val.innerText > 1.5){ param["suggest"] = "1.5";   val.classList.add("warn");}
\echo     else val.classList.add("lime");
\echo   } else { param["suggest"] = "4"; val.classList.add("lime")}; 
\echo   },
\echo   wal_keep_size: function(rowref){
\echo     val=rowref.cells[1];
\echo     val.title=bytesToSize(val.innerText*1024*1024,1024);
\echo     val.classList.add("lime");
\echo   },
\echo   seq_page_cost: function(rowref){
\echo     val=rowref.cells[1];
\echo     let param = params.find(p => p.param === "seq_page_cost");
\echo     if (val.innerText != 1){ 
\echo       param["suggest"] = "1"; val.classList.add("warn"); val.title="Avoid changing seq_page_cost value to anything other than 1, unless there is an unavoidable reason"; 
\echo       param["warn"] = "seq_page_cost is specified as <b>" + val.innerText + "</b>. " + val.title; 
\echo     }
\echo   },
\echo   server_version: function(rowref){
\echo     val=rowref.cells[1];
\echo     let setval = val.innerText.split(" ")[0]; mgrver=setval.split(".")[0];
\echo     let sver_ver = params.find(p => p.param === "server_version");
\echo     if ( mgrver < Math.trunc(meta.pgvers[0])){
\echo       val.classList.add("warn"); val.title="PostgreSQL Version is outdated (EOL) and not supported";
\echo       sver_ver["warn"] = "Running Unsupported PostgreSQL Version " + mgrver;
\echo     } else {
\echo       meta.pgvers.forEach(function(t){
\echo         if (Math.trunc(setval) == Math.trunc(t)){
\echo           if (t.split(".")[1] - setval.split(".")[1] > 0 ) { val.classList.add("warn"); val.title= t.split(".")[1] - setval.split(".")[1] + " minor version updates are pending. Please upgrade ASAP"; 
\echo            sver_ver["warn"] = "PostgreSQL <b>Version"+ val.innerText + ".</b> " + val.title;
\echo           }
\echo         }
\echo       })  
\echo     }
\echo     if(val.classList.length < 1) val.classList.add("lime"); 
\echo   },
\echo   shared_buffers: function(rowref){
\echo     val=rowref.cells[1];
\echo     val.classList.add("lime"); val.title=bytesToSize(val.innerText*8192,1024);
\echo     if(parseFloat(document.getElementById("mem").value) < "0.2" ){
\echo       document.getElementById("mem").value = val.innerText*8*4/(1024*1024);
\echo       totMem = val.innerText*8*4/(1024*1024);
\echo     }
\echo     if( totMem > 0 && ( totMem < val.innerText*8*0.2/1048576 || totMem > val.innerText*8*0.3/1048576 ))
\echo       { val.classList.add("warn"); val.title="Approx. 25% of available memory is recommended, current value of " + bytesToSize(val.innerText*8192,1024) + " appears to be off"; 
\echo       let param = params.find(p => p.param === "shared_buffers");
\echo       param["suggest"]= "'"+ bytesToSize(totMem*1000000000*0.25) + "'";
\echo       }
\echo   },
\echo   statement_timeout : function(rowref){
\echo     val=rowref.cells[1];
\echo     if(rowref.cells[3].innerText == "session" && rowref.cells[4].innerText.indexOf("/") < 0 ){
\echo       rowref.cells[3].innerText= "default"; val.innerText="0";
\echo       val.classList.add("warn"); val.title="It is important to set a value globally to avoid long running sessions and associated problems"
\echo       let tmout = params.find(p => p.param === "statement_timeout");
\echo       tmout["suggest"] = "'4h'";
\echo     }
\echo   },
\echo   synchronous_standby_names: function(rowref){
\echo     val=rowref.cells[1];
\echo     if (val.innerText.trim().length > 0){ val.classList.add("warn"); val.title="Synchronous Standby can cause session hangs, and poor performance"; }
\echo   },
\echo   track_io_timing: function(rowref){
\echo     val=rowref.cells[1];
\echo     if (val.innerText == "off"){
\echo       let param = params.find(p => p.param === "track_io_timing");
\echo       param["suggest"] = "on";
\echo     }
\echo   },
\echo   wal_compression: function(rowref){
\echo     val=rowref.cells[1]; val.classList.add("lime");
\echo     if(totCPU > 3){
\echo       if (val.innerText == "off") { val.classList.add("warn"); val.title="Consider enabling wal_compression for better performance" 
\echo         let param = params.find(p => p.param === "wal_compression");
\echo         param["suggest"] = "'on'";
\echo         if (mgrver >= 15) {
\echo           param["warn"] = "<b>wal_compression is '"+ val.innerText+"' on PostgreSQL "+ mgrver +".</b> 'lz4' or 'zstd' is recommended, if available. <a href='"+ docurl +"params/wal_compression.html'> Details<a>"
\echo           param["suggest"] = "'lz4'";
\echo         }
\echo       }
\echo     }
\echo   },
\echo   work_mem: function(rowref){
\echo     val=rowref.cells[1];
\echo     val.title=bytesToSize(val.innerText*1024,1024) ;
\echo     if(val.innerText > 98304){ val.classList.add("warn"); val.title += ", Avoid global settings above 64MB to avoid memory related issues"  }
\echo     else val.classList.add("lime");
\echo     let conns = params.find(p => p.param === "max_connections");
\echo     let wmem = params.find(p => p.param === "work_mem");
\echo     if ( totMem > 0.2 && conns.val > 1){
\echo       wmem["suggest"] = "'" + Math.min(parseInt(totMem*1024/(5*parseInt(conns.val)) + 4 ),64) + "MB'";
\echo     }
\echo   },
\echo   default : function(rowref) {} 
\echo };
\echo var evalParam = function(param,rowref = null) {
\echo   if (rowref != null && rowref.id == "") rowref.id=param;  
\echo   else rowref = document.getElementById(param); 
\echo   if (paramDespatch.hasOwnProperty(param)){ 
\echo     let paramJson = {}; paramJson["param"] = param; paramJson["val"] = rowref.cells[1].innerText;
\echo     params.push(paramJson);   
\echo     paramDespatch[param](rowref);  
\echo    }
\echo }
\echo function checkpars(){
\echo   tab=document.getElementById("params")
\echo   tab.caption.innerHTML="<span>Parameters</span>"
\echo   trs=tab.rows
\echo   if (document.getElementById("params").rows.length > 1)
\echo     for(var i=1;i<trs.length;i++)  evalParam(trs[i].cells[0].innerText,trs[i]); 
\echo   else  strfind += "<li><b>Partial Data Collection</b></li>"
\echo  }
\echo function aged(cell){
\echo  if(cell.innerHTML > autovacuum_freeze_max_age){ cell.classList.add("warn"); cell.title =  Number(cell.innerText).toLocaleString("en-US"); }
\echo }
\echo function checktabs(){
\echo   const startTime =new Date().getTime();
\echo   tab=document.getElementById("tabInfo")
\echo   tab.caption.innerHTML="<span>Tables</span> in '" + obj.dbts.f1 + "' DB" 
\echo   const trs=document.getElementById("tabInfo").rows
\echo   const len=trs.length;
\echo   setheadtip(trs[0],["Table Name and its OID","","Namespace / Schema OID","Bloat in Percentage","Live Rows/Tuples","Dead Rows/Tuples","Dead/Live ratio","Table (main fork) size in bytes",
\echo   "Total Table size (All forks + TOAST) in bytes","Total Table size + Associated Indexes size in bytes","","","","Number of Vacuums per day","","Size of TOAST and its index",
\echo    "Age of TOAST","Bigger of Table age and TOAST age","Number of Blocks Read/Fetched","Cache hit while reading","Time of last usage"]);
\echo   [10,16,17].forEach(function(num){trs[0].cells[num].title="Age of unfrozen tuple. Indication of the need for VACUUM FREEZE. Current autovacuum_freeze_max_age=" + autovacuum_freeze_max_age.toLocaleString("en-US")})
\echo   for(var i=1;i<len;i++){
\echo     tr=trs[i]; let TotTab=tr.cells[8]; TotTabSize=Number(TotTab.innerHTML); TabInd=tr.cells[9]; TabIndSize=(TabInd.innerHTML);
\echo     if(TotTabSize > 5000000000 ) { TotTab.classList.add("lime"); TotTab.title = bytesToSize(TotTabSize) + "\nBig Table, Consider Partitioning, Archive+Purge"; 
\echo     } else TotTab.title=bytesToSize(TotTabSize);
\echo     if( TabIndSize > 2*TotTabSize && TotTabSize > 2000000 ){ TabInd.classList.add("warn"); TabInd.title="Indexes of : " + bytesToSize(TabIndSize-TotTabSize) + " is " + ((TabIndSize-TotTabSize)/TotTabSize).toFixed(2) + "x of Table " + bytesToSize(TotTabSize) + "\n Total : " + bytesToSize(TabIndSize)
\echo     } else TabInd.title=bytesToSize(TabIndSize); 
\echo     if (TabIndSize > 10000000000) TabInd.classList.add("lime");
\echo     if (tr.cells[13].innerText / obj.dbts.f4 > 12){ tr.cells[13].classList.add("warn");  tr.cells[13].title="Too frequent vacuum runs : " + Math.round(tr.cells[13].innerText / obj.dbts.f4) + "/day"; }
\echo     if (tr.cells[15].innerText > 10000) { 
\echo       tr.cells[15].title=bytesToSize(Number(tr.cells[15].innerText)); 
\echo       if (tr.cells[15].innerText > 10737418240) tr.cells[15].classList.add("warn")
\echo       else tr.cells[15].classList.add("lime")
\echo     }
\echo     aged(tr.cells[10]);
\echo     aged(tr.cells[16]);
\echo     aged(tr.cells[17]);
\echo     if (tr.cells[18].innerText / obj.dbts.f4 > 262144 ){ 
\echo       tr.cells[18].classList.add("lime"); 
\echo       tr.cells[18].title="High Utilization : " + bytesToSize(Math.round(tr.cells[18].innerText * 8192 / obj.dbts.f4)) + "/day"; 
\echo       if(tr.cells[19].innerText < 40 ){ tr.cells[19].classList.add("warn"); tr.cells[19].title="Poor cache hit ratio, Results in high DiskReads"; }
\echo       else if (tr.cells[19].innerText < 70) tr.cells[19].classList.add("lime");
\echo      }
\echo   }
\echo const endTime = new Date().getTime();
\echo console.log("time taken for checktabs :" + (endTime - startTime));
\echo }
\echo function checkdbs(){
\echo   const trs=document.getElementById("dbs").rows
\echo   const len=trs.length;
\echo   let aborts=[]; 
\echo   let strtmp=""; 
\echo   trs[0].cells[6].title="Average Temp generation Per Day"; trs[0].cells[7].title="Average Temp generation Per Day"; trs[0].cells[9].title="autovacuum_freeze_max_age=" + autovacuum_freeze_max_age.toLocaleString("en-US");
\echo   for(var i=1;i<len;i++){
\echo     tr=trs[i];
\echo     if(obj.dbts !== null && tr.cells[0].innerHTML == obj.dbts.f1) tr.cells[0].classList.add("lime");
\echo     if(tr.cells[3].innerHTML > 4000){ tr.cells[3].classList.add("warn"); tr.cells[3].title = "High number of transaction aborts/rollbacks. Please inspect PostgreSQL logs"; 
\echo      aborts.push(tr.cells[0].innerHTML)
\echo      }
\echo     [7,8].forEach(function(num) {  if (tr.cells[num].innerText > 1048576) { if(tr.cells[num].classList.length < 1) tr.cells[num].classList.add("lime"); tr.cells[num].title=bytesToSize(tr.cells[num].innerText) } });
\echo     if(tr.cells[7].innerHTML > 50000000000) {  
\echo       tr.cells[7].classList.remove("lime"); tr.cells[7].classList.add("warn"); 
\echo       let str = " temp file generation per day!. It can cause I/O performance issues." 
\echo       let param = params.find(p => p.param === "log_temp_files");
\echo       if ( param["val"] == -1 ) { 
\echo         param["suggest"] = "'100MB'"; 
\echo         str += "Consider setting log_temp_files=" + param["suggest"] + " to collect the problematic SQL statements to PostgreSQL logs";
\echo       }else{
\echo         str += "log_temp_files is already enabled, Analyze the PostgreSQL logs to check the problematic SQL statements";
\echo       }
\echo       evalParam("log_temp_files");
\echo       if (strtmp != "") strtmp+= ","
\echo       strtmp +=  tr.cells[7].title +"/day on "+tr.cells[0].innerHTML; 
\echo       tr.cells[7].title += str;
\echo     }
\echo     totdb=totdb+Number(tr.cells[8].innerText);
\echo     aged(tr.cells[9]);
\echo   }
\echo   if (aborts.length >0) 
\echo    strfind += "<li>High number of transaction aborts/rollbacks in databases : <b>" + aborts.toString() + "</b>, please inspect PostgreSQL logs for more details</li>" ; 
\echo   if (strtmp != "") strfind += "<li>High temp file generation : <b>" + strtmp + "</b></li>"; 
\echo }
\echo function checkextn(){
\echo   const tab=document.getElementById("tblextn");
\echo   tab.caption.innerHTML="<span>Extensions</span> in '" + obj.dbts.f1 + "' DB" 
\echo   const trs=tab.rows
\echo   const len=trs.length;
\echo   let riskyExtn=[];
\echo   if (len > 4) strfind += "<li><b>"+ (len-1).toString() +" Additional Extensions found.</b> Extensions can cause considerable overhead and performance degradataion. <a href='"+ docurl +"extensions.html'>Details</a></li>"
\echo   for(var i=1;i<len;i++){
\echo     tr=trs[i];
\echo     if (meta.riskyExtn.includes(tr.cells[1].innerHTML)){ tr.cells[1].classList.add("warn"); tr.cells[1].title = "Risky to use in mission critical systems without support aggrement. Crashes are reported" ; }
\echo     else if (!meta.commonExtn.includes(tr.cells[1].innerHTML)) tr.cells[1].classList.add("lime");
\echo   }
\echo }
\echo function checkusers(){
\echo   tab=document.getElementById("tblusr");
\echo   tab.caption.innerHTML="<span>Users/Roles</span>  and connections"
\echo   const trs=tab.rows
\echo   let supr=0;
\echo   for (var i=1;i<trs.length;i++){
\echo     tr=trs[i];
\echo     if(tr.cells[2].innerText == "t"){
\echo       tr.cells[2].classList.add("lime");
\echo       tr.cells[2].title =  "Super User"
\echo       supr++;
\echo     }
\echo     if(tr.cells[5].innerText == "MD5"){
\echo       tr.cells[5].classList.add("warn");
\echo       tr.cells[5].title="Consider switching to SCRAM for better security whever possible"
\echo     }
\echo   }
\echo   if (supr > 2 ) strfind += "<li>There are <b>" + supr + " Super user accounts</b>, consider this from the security standpoint</li>"
\echo }
\echo function checkhba(){
\echo   tab=document.getElementById("tblhba");
\echo   tab.caption.innerHTML="<span>HBA rules</span> analysis for security"
\echo   const trs=tab.rows
\echo   for (var i=1;i<trs.length;i++){
\echo     tr=trs[i];
\echo     if (!["::1","127.0.0.1","","samehost"].includes(tr.cells[4].innerText.trim()) && tr.cells[8].innerText.trim() != "reject" ){
\echo       if(tr.cells[7].innerText == "IPv4"){
\echo         if(tr.cells[5].innerText < 24){ 
\echo           tr.cells[5].classList.add("warn");
\echo           tr.cells[5].title="Avoid keeping the subnet mask wide open"
\echo         } else if(tr.cells[5].innerText < 32) tr.cells[5].classList.add("lime")
\echo         if(tr.cells[8].innerText == "md5"){
\echo           tr.cells[8].classList.add("warn");
\echo           tr.cells[8].title="Consider switching to SCRAM (scram-sha-256) for better security whever possible"
\echo         }else if(tr.cells[8].innerText == "trust"){
\echo           tr.cells[8].classList.add("warn");
\echo           tr.cells[8].title="Avoid blindly trusting connection from outside"
\echo         }
\echo       }
\echo       if(tr.cells[4].innerText == "all"){
\echo           tr.cells[4].classList.add("warn");
\echo           tr.cells[4].title="Avoid allowing connetions from all addresses"
\echo       } else tr.cells[4].classList.add("lime")
\echo     }
\echo   }
\echo }
\echo const getCellValue = (tr, idx) => tr.children[idx].innerText || tr.children[idx].textContent;
\echo const comparer = (idx, asc) => (a, b) => ((v1, v2) =>   v1 !== '''''' && v2 !== '''''' && !isNaN(v1) && !isNaN(v2) ? v1 - v2 : v1.toString().localeCompare(v2))(getCellValue(asc ? a : b, idx), getCellValue(asc ? b : a, idx));
\echo document.querySelectorAll(''''th'''').forEach(th => th.addEventListener(''''click'''', (() => {
\echo   const table = th.closest(''''table'''');
\echo   th.style.cursor = "progress";
\echo   var el=document.createElement("div");
\echo   el.setAttribute("id", "cur");
\echo   if (this.asc) el.textContent = "⬆";
\echo   else el.textContent = "⬇";
\echo   th.appendChild(el);
\echo   setTimeout(() => { el.remove();},1000);
\echo   setTimeout(function (){
\echo   Array.from(table.querySelectorAll(''''tr:nth-child(n+2)'''')).sort(comparer(Array.from(th.parentNode.children).indexOf(th), this.asc = !this.asc)).forEach(tr => table.appendChild(tr) );
\echo   setTimeout(function(){th.style.cursor = "pointer";},10);
\echo   },50);
\echo })));
\echo function dbsdtls(th){
\echo   let o=JSON.parse(th.cells[1].innerText);
\echo   let str="";
\echo   if(th.cells[0].classList.contains("lime")) str = "<br/>(pg_gather connected)";
\echo   return "<b>" + th.cells[0].innerText + "</b>" + str + "<br/> Inserts per day : " + o.f1 + "<br/>Updates per day : " + o.f2 + "<br/>Deletes per day : " 
\echo    + o.f3 + "<br/>Stats Reset : " + o.f4 + "<br/>DB oid(dbid) :" + o.f5 + "<br/>Multi Txn Id Age :" + o.f6  ;
\echo }
\echo function tabdtls(th){
\echo   let o=JSON.parse(th.cells[1].innerText);
\echo   let vac=th.cells[13].innerText;
\echo   let ns=obj.ns.find(el => el.nsoid === JSON.parse(th.cells[2].innerText).toString());
\echo   let str=""
\echo   if (o.f11 == "r") str += "<br/>Inheritance Partition of : " + o.f10;
\echo   if (o.f11 == "p") str += "<br/>Native Partition of : " + o.f10;
\echo   if (o.f6 !== null) str += "<br/>Total Indexes: " + o.f6;
\echo   if (o.f7 !== null) str += "<br/>Unused Indexes: " + o.f7;
\echo   if (o.f8 > 0) str += "<br/>Primary key: Exists";
\echo   else str += "<br/>No Primary key ";
\echo   if (o.f9-o.f8 > 0) str += "<br/>Unique keys (than PK): " + (o.f9-o.f8);
\echo   if (obj.dbts.f4 < 1) obj.dbts.f4 = 1;
\echo   if (vac > 0) str +="<br />Vacuums / day : " + Number(vac/obj.dbts.f4).toFixed(1);
\echo   str += "<br/>Inserts / day : " + Math.round(o.f2/obj.dbts.f4);
\echo   str += "<br/>Updates / day : " + Math.round(o.f3/obj.dbts.f4);
\echo   str += "<br/>Deletes / day : " + Math.round(o.f4/obj.dbts.f4);
\echo   str += "<br/>HOT.updates / day : " + Math.round(o.f4/obj.dbts.f4);
\echo   str += "<br>Rel.filename : " + o.f12;
\echo   if (o.f13 < 16384) str += "<br>Tablespace : pg_default"; 
\echo   else{
\echo     let tbsp = obj.tbsp.find(el => el.tsoid === JSON.parse(o.f13).toString()); 
\echo     str += "<br>Tablespace : " + o.f13 + " (" + tbsp.tsname + " : " + tbsp.location + ")"; 
\echo   }
\echo   if (o.f14 !== null ) str += "<br>Current Settings : " + o.f14;
\echo   if(o.f3 > 0 || vac/obj.dbts.f4 > 50){
\echo     str += "<br><b><u>RECOMMENDATIONS : </u></b>"
\echo   if (o.f3 > 0) str += "<br/>FILLFACTOR :" + Math.round(100 - 20*o.f3/(o.f3+o.f2)+ 20*o.f3*o.f5/((o.f3+o.f2)*o.f3));
\echo   if (vac/obj.dbts.f4 > 50) { 
\echo     let threshold = Math.round((Math.round(o.f3/obj.dbts.f4) + Math.round(o.f4/obj.dbts.f4))/48); 
\echo     if (threshold < 500) threshold = 500;
\echo     str += "<br/>AUTOVACUUM : autovacuum_vacuum_threshold = "+ threshold +", autovacuum_analyze_threshold = " + threshold
\echo   }}
\echo   return "<b>" + th.cells[0].innerText + "</b><br/>OID : " + o.f1 + "</b><br/>Schema : " + ns.nsname + str;
\echo }
\echo function sessdtls(th){
\echo   let o=JSON.parse(th.cells[1].innerText); let str="";
\echo   if (o.f1 !== null) str += "Database :" + o.f1 + "<br/>";
\echo   if (o.f2 !== null && o.f2.length > 1 ) str += "Application :" + o.f2 + "<br/>";
\echo   if (o.f3 !== null) str += "Client Host :" + o.f3 + "<br/>";
\echo   if (o.f4 != null) str += "Communication :" + o.f4 + "<br/>";
\echo   if (o.f5 != null) str += "Workers :" + o.f5 + "<br/>";
\echo   if (typeof o.f6 != "undefined") str += ''''<div class="warn">'''' + o.f6 + "<div>";
\echo   if (str.length < 1) str+="Independent/Background process";
\echo   return str;
\echo }
\echo function userdtls(tr){
\echo if(tr.cells[1].innerText.length > 2){
\echo   let o=JSON.parse(tr.cells[1].innerText); let str="<b><u>Connections per DB by user '"+tr.cells[0].innerText+"'</u></b><br>";
\echo   for(i=0;i<o.length;i++){
\echo     str += (i+1).toString() + ". Database:" + o[i].f1 + " Active:" + o[i].f2 + ", IdleInTrans:" + o[i].f3  + ", Idle:" + o[i].f4 +  " <br>";
\echo   }
\echo   return str
\echo } else return "No connections"
\echo }
\echo function dbcons(tr){
\echo if(tr.cells[1].innerText.length > 2){
\echo   let o=JSON.parse(tr.cells[1].innerText); let str="<b><u>User connections to DB \'"+ tr.cells[0].innerText +"'</u></b><br>";
\echo   for(i=0;i<o.length;i++){
\echo     str += (i+1).toString() + ". User:" + o[i].f1 + " Active:" + o[i].f2 + ", IdleInTrans:" + o[i].f3  + ", Idle:" + o[i].f4 +  " <br>";
\echo   }
\echo   return str
\echo } else return "No connections"
\echo }
\echo document.querySelectorAll(".thidden tr td:first-child").forEach(td => td.addEventListener("mouseover", (() => {
\echo   tr=td.parentNode;
\echo   tab=tr.closest("table");
\echo   var el=document.createElement("div");
\echo   el.setAttribute("id", "dtls");
\echo   el.setAttribute("align","left");
\echo   if(tab.id=="dbs") el.innerHTML=dbsdtls(tr);
\echo   if(tab.id=="tabInfo") el.innerHTML=tabdtls(tr);
\echo   if(tab.id=="tblsess") el.innerHTML=sessdtls(tr);
\echo   if(tab.id=="tblusr") el.innerHTML=userdtls(tr);
\echo   if(tab.id=="tblcs") el.innerHTML=dbcons(tr);
\echo   tr.cells[2].appendChild(el);
\echo })));
\echo document.querySelectorAll(".thidden tr td:first-child").forEach(td => td.addEventListener("dblclick", (() => {
\echo   navigator.clipboard.writeText(td.parentNode.cells[2].children[0].innerText);
\echo   flash("Details copied to clipboard");
\echo })));
\echo document.querySelectorAll(".thidden tr td:first-child").forEach(td => td.addEventListener("mouseout", (() => {
\echo   td.parentNode.cells[2].innerHTML=td.parentNode.cells[2].firstChild.textContent;
\echo })));
\echo let elem=document.getElementById("bottommenu")
\echo elem.onmouseover = function() { document.getElementById("menu").style.display = "block"; }
\echo elem.onclick = function() { document.getElementById("menu").style.display = "none"; }
\echo elem.onmouseout = function() { document.getElementById("menu").style.display = "none"; }
\echo document.querySelectorAll("#tblsess tr td:nth-child(6) , #tblstmnt tr td:nth-child(2)").forEach(td => td.addEventListener("dblclick", (() => {
\echo   if (td.title){
\echo   navigator.clipboard.writeText(td.title).then(() => {  
\echo     flash("SQL text is copied to clipboard");
\echo    });
\echo }
\echo })));
\echo function checkindex(){
\echo tab=document.getElementById("IndInfo")
\echo tab.caption.innerHTML="<span>Indexes</span> in '" + obj.dbts.f1 + "' DB" 
\echo trs=tab.rows;
\echo for (let tr of trs) {
\echo   if(tr.cells[4].innerText == 0) {tr.cells[4].classList.add("warn"); tr.cells[4].title="Unused Index"}
\echo   tr.cells[5].title=bytesToSize(Number(tr.cells[5].innerText));
\echo   if(tr.cells[5].innerText > 2000000000) tr.cells[5].classList.add("lime");
\echo   if(tr.cells[6].innerText > 262144 && tr.cells[6].innerText/tr.cells[4].innerText > 50 ) {
\echo     if (tr.cells[4].innerText > 0 ){
\echo      tr.cells[6].title="Each Index scan had to fetch " + Math.round(tr.cells[6].innerText/tr.cells[4].innerText) + " pages on average. Expensive Index";
\echo     }else tr.cells[6].title="Unused indexes. But causing fetches without any benefit"; 
\echo     tr.cells[6].classList.add("warn");
\echo     if (tr.cells[7].innerText < 50 ){tr.cells[7].classList.add("warn");tr.cells[7].title="Poor Cache Hit";}
\echo     else if (tr.cells[7].innerText < 80 ) {tr.cells[7].classList.add("lime");tr.cells[7].title="Indexes with less cache hit can cause considerable I/O"; }
\echo   }
\echo }
\echo }
\echo function checkdbtime(){
\echo tab=document.getElementById("tableConten")
\echo tab.caption.innerHTML="<span>DB Server Time</span> - Wait-events, CPU time and Delays (<a href="+docurl+"waitevents.html>Reference</a>)"
\echo trs=tab.rows;
\echo let tempstr=""
\echo if (trs.length > 1){ 
\echo   maxevnt=Number(trs[1].cells[1].innerText);
\echo   for (let tr of trs) {
\echo    evnts=tr.cells[1];
\echo    if (evnts.innerText*1500/maxevnt > 1) evnts.innerHTML += ''''<div style="display:inline-block;width:'+ Number(evnts.innerText)*1500/maxevnt + 'px; border: 7px outset brown; border-width:7px 0; margin:0 5px;box-shadow: 2px 2px grey;">'''';
\echo    if (tr.cells[0].innerText == "CPU" && tr.cells[1].innerText > 100)   tempstr = "CPU usage is equivalent to " + (evnts.innerText*1.2/2000).toFixed(1) + " CPU cores (approx). "
\echo   }
\echo   el=document.createElement("tfoot");
\echo   el.innerHTML = "<th colspan='2'>"+ tempstr +" </th>";
\echo   tab.appendChild(el);
\echo }else {
\echo   tab.tBodies[0].innerHTML="No Wait Event information or CPU usage information is available, Probably the PostgreSQL is completely idle or data collection failed"
\echo }
\echo }
\echo function checksess(){
\echo tab=document.getElementById("tblsess")
\echo tab.caption.innerHTML=''''<span>Sessions</span>''''
\echo trs=tab.rows;
\echo for (let tr of trs){
\echo  pid=tr.cells[0]; sql=tr.cells[5]; xidage=tr.cells[8]; stime=tr.cells[10];
\echo  if(xidage.innerText > 20) xidage.classList.add("warn");
\echo  if (blokers.indexOf(Number(pid.innerText)) > -1){ pid.classList.add("high"); pid.title="Blocker"; 
\echo    tr.cells[1].innerText = updateJson( tr.cells[1].innerText , "f6", "Blocker")
\echo  };
\echo  if (blkvictims.indexOf(Number(pid.innerText)) > -1) { 
\echo    pid.classList.add("warn"); 
\echo    tr.cells[1].innerText = updateJson( tr.cells[1].innerText , "f6", "Victim of Blocker: " + obj.victims.find(el => el.f1 == pid.innerText).f2.toString())
\echo   };
\echo   if(DurationtoSeconds(stime.innerText) > 300 && tr.cells[7].innerText.length > 3) stime.classList.add("warn");
\echo  if (sql.innerText.length > 100 && !sql.innerText.startsWith("**") ){ 
\echo   sql.title = sql.innerText; 
\echo   sql.innerText = sql.innerText.substring(0, 100); 
\echo  };
\echo }}
\echo function checkstmnts(){
\echo let tab= document.getElementById("tblstmnt");
\echo tab.caption.innerHTML = "<span>Top Statements</span>"
\echo if(tab.rows.length < 2) 
\echo  tab.tBodies[0].innerHTML="No pg_stat_statements or pg_stat_monitor info found"
\echo else{
\echo  trs=tab.rows;
\echo  setTitles(trs[0],["Weighted Dense Ranking. 1 has the highest impact","SQL Statement","SQL workload / Total workload %","Number of execution of the statement",
\echo  "Avg. execution time of the statement (ms)","Average Reads (Blocks)","Cache Hit %","Avg. Dirtied Pages","Avg. Written Pages","Avg. Temp Read","Avg. Temp Write"]);
\echo   for (let tr of trs){
\echo  sql=tr.cells[1];
\echo  if (sql.innerText.length > 10 ){ sql.title = sql.innerText; sql.innerText = sql.innerText.substring(0, 100); }
\echo  let cel=tr.cells[6];
\echo  if ( cel.innerText.trim() != "" && cel.innerText < 50) cel.classList.add("warn");
\echo  cel=tr.cells[9];
\echo  if (cel.innerText > 12800) cel.classList.add("lime");
\echo  cel=tr.cells[10];
\echo  if (cel.innerText > 12800) cel.classList.add("lime");
\echo }}}
\echo function setTitles(tr,tiltes){
\echo   for(i=0;i<tiltes.length;i++) tr.cells[i].title=tiltes[i];
\echo }
\echo function checkchkpntbgwrtr(){
\echo tab=document.getElementById("tblchkpnt")
\echo tab.caption.innerHTML=''''<span>BGWriter & Checkpointer</span>''''
\echo trs=tab.rows;
\echo setTitles(trs[0],["Forced Checkpoint; Checkpoint triggered by xlog/wal; Need to adjust the max_wal_size","Average Minutes between Checkpoints","Average Write time of a checkpoint",
\echo "Average Disk sync time of a checkpoint","","","","","","","","Dirty buffers cleaned by Checkpointer","Dirty buffers cleaned by BGWriter","Dirty buffers cleaned by Session backends",
\echo "Percentage of bgwriter runs results in a halt","Percentage of bgwriter halts are due to hitting on bgwriter_lru_maxpages limit","Number of days before stats have been reset"]);
\echo if (trs.length > 1){
\echo   tr=trs[1]
\echo   if (tr.cells[0].innerText > 10){
\echo     tr.cells[0].classList.add("high"); tr.cells[0].title="More than 10% of forced checkpoints is not desirable, increase max_wal_size";
\echo   }
\echo   if(tr.cells[1].innerText < 10 ){
\echo     tr.cells[1].classList.add("high"); tr.cells[1].title="checkpoints are too frequent. consider checkpoint_timeout=1800";
\echo   }
\echo   if(tr.cells[11].innerText > 50){
\echo     tr.cells[11].classList.add("high"); tr.cells[11].title="Checkpointer is taking high load of cleaning dirty buffers";
\echo   }
\echo   if(tr.cells[13].innerText > tr.cells[12].innerText){  
\echo     tr.cells[12].classList.add("high"); tr.cells[12].title="Bgwriter should be cleaning more pages than backends.";
\echo     if (tr.cells[13].innerText > 30){ tr.cells[13].classList.add("high"); tr.cells[13].title="too many dirty pages cleaned by backends"; 
\echo     strfind += "<li>High <b>memory pressure</b>. Consider increasing RAM and shared_buffers</li>"; }  
\echo     if(tr.cells[12].innerText < 20){ 
\echo       tr.cells[12].classList.add("high"); tr.cells[12].title+="Bgwriter is not efficient";
\echo       if(tr.cells[14].innerText > 30){
\echo         tr.cells[14].classList.add("high"); tr.cells[14].title="bgwriter could run more frequently. reduce bgwriter_delay";
\echo       }
\echo       if(tr.cells[15].innerText > 10){
\echo         let param = params.find(p => p.param === "bgwriter_lru_maxpages");
\echo         param["suggest"] = Math.ceil((parseInt(param["val"]) + tr.cells[15].innerText/15*100)/100)*100;
\echo         evalParam("bgwriter_lru_maxpages");
\echo         tr.cells[15].classList.add("high"); tr.cells[15].title="bgwriter halts too frequently. increase bgwriter_lru_maxpages";
\echo       }
\echo     }
\echo   }
\echo   if (tr.cells[16].innerText.trim() == "" || tr.cells[16].innerText < 1 ){
\echo     tr.cells[16].classList.add("high"); tr.cells[16].title="sufficient bgwriter stats are not available";
\echo     document.getElementById("tblchkpnt").classList.add("high");
\echo     document.getElementById("tblchkpnt").title = "Sufficient bgwriter stats are not available. This could happen if data is collected immediately after the stats reset or a crash. At least one day of stats are required to do meaningful calculations";
\echo   }
\echo   if( tr.cells[16].innerText > 45 ){
\echo     tr.cells[16].classList.add("high"); tr.cells[16].title="Statistics of long-term avarage won't be helpful. Please consider resetting. 1 week is ideal";
\echo   }
\echo }}
\echo function checkiostat(){
\echo tab=document.getElementById("tbliostat")
\echo tab.caption.innerHTML=''''<span>IO Statistics</span>''''
\echo if (tab.rows.length > 1){
\echo }else  tab.tBodies[0].innerHTML="IO statistics is available for PostgreSQL 16 and above"
\echo }
\echo tab=document.getElementById("tblreplstat")
\echo tab.caption.innerHTML="<span>Replication</span>"
\echo if (tab.rows.length > 1){
\echo   for(var i=1;i<tab.rows.length;i++){
\echo     row=tab.rows[i];
\echo     [4,5,6,7,16,17].forEach(function(num){ cell=row.cells[num]; cell.title=bytesToSize(Number(cell.innerText),1024); 
\echo      if(cell.innerText > 104857600){
\echo       cell.classList.add("warn");
\echo      }else{
\echo       cell.classList.add("lime");
\echo      }
\echo     });
\echo     [14,15].forEach(function(num){  if(row.cells[num].innerText > 20) row.cells[num].classList.add("warn"); });
\echo     if (row.cells[13].innerText == "f" || row.cells[2].innerText == "") {
\echo       row.cells[8].classList.add("high");
\echo       row.cells[8].title="Abandoned replication slot";
\echo       document.getElementById("finditem").innerHTML += "<li> Abandoned replication slot : <b>" +  row.cells[8].innerText + "</b> found. This can cause unwanted WAL retention" ;
\echo     }
\echo   }
\echo }else{
\echo   tab.tBodies[0].innerHTML="No Replication data found"
\echo }
\echo document.onkeyup = function(e) {
\echo   if (e.altKey && e.which === 73) document.getElementById("topics").scrollIntoView({behavior: "smooth"});
\echo }
\echo </script>
\echo </html>
