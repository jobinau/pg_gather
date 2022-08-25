\set QUIET 1
\echo <!DOCTYPE html>
\echo <html><meta charset="utf-8" />
\echo <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>
\echo <style>
\echo table, th, td { border: 1px solid black; border-collapse: collapse; padding: 2px 4px 2px 4px;}
\echo th {background-color: #d2f2ff;cursor: pointer; }
\echo tr:nth-child(even) {background-color: #eef8ff}
\echo tr:hover { background-color: #FFFFCA}
\echo caption { font-size: larger }
\echo .warn { font-weight:bold; background-color: #FAA }
\echo .high { border: 5px solid red;font-weight:bold}
\echo .lime { font-weight:bold}
\echo .lineblk {float: left; margin:0 9px 4px 0 }
\echo .bottomright { position: fixed; right: 0px; bottom: 0px; padding: 5px; border : 2px solid #AFAFFF; border-radius: 5px;}
\echo #cur { font: 5em arial; position: absolute; color:brown; animation: vanish 0.8s ease forwards; }
\echo @keyframes vanish { from { opacity: 1;} to {opacity: 0;} }
\echo summary {  padding: 1rem; font: bold 1.2em arial;  cursor: pointer } 
\echo </style>
\H
\pset footer off 
SET max_parallel_workers_per_gather = 0;

\echo <h1>
\echo   <svg width="10em" viewBox="0 0 140 80">
\echo     <path fill="none" stroke="#000000" stroke-linecap="round" stroke-width="2"  d="m 21.2,46.7 c 1,2 0.67,4 -0.3,5.1 c -1.1,1 -2,1.5 -4,1 c -10,-3 -4,-25 -4 -25 c 0.6,-10 8,-9 8 -9 s 7,-4.5 11,0.2 c 1.2,1.4 1.7,3.3 1.7,5.17 c -0.1,3 3,7 -2,10 c-2,2 -1,5 -8,5.5 m -2 -12 c 0,0 -1,1 -0.2,0.2 m -4 12 c 0,0 0,10 -12,11"/>
\echo     <text x="30" y="50" style="font:25px arial">g_gather</text>
\echo     <text x="75" y="62" style="fill:red; font:15px arial">Report</text>
\echo    </svg>
\echo    <b id="busy" class="warn"> Loading... </b>
\echo </h1>
\pset tableattr 'class="lineblk"'
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
SELECT  UNNEST(ARRAY ['Collected At','Collected By','PG build', 'PG Start','In recovery?','Client','Server','Last Reload','Current LSN']) AS pg_gather,
        UNNEST(ARRAY [CONCAT(collect_ts::text,' (',TZ.val,')'),usr,ver, pg_start_ts::text ||' ('|| collect_ts-pg_start_ts || ')',recovery::text,client::text,server::text,reload_ts::text,current_wal::text]) AS "Report-v15"
FROM pg_gather LEFT JOIN TZ ON TRUE 
UNION
SELECT  'Connection', replace(connstr,'You are connected to ','') FROM pg_srvr ) a WHERE "Report-v15" IS NOT NULL ORDER BY 1;
\pset tableattr 'id="dbs"'
SELECT datname "DB Name",xact_commit "Commits",xact_rollback "Rollbacks",tup_inserted+tup_updated+tup_deleted "Transactions", CASE WHEN blks_fetch > 0 THEN blks_hit*100/blks_fetch ELSE NULL END  "Cache hit ratio",temp_files "Temp Files",temp_bytes "Temp Bytes",db_size "DB size",age "Age" FROM pg_get_db;
\pset tableattr off

\echo <div>
\echo <details style="clear: left; width: fit-content;">
\echo   <summary>Tune PostgreSQL Parameters (beta)</summary>
\echo   <label for="cpus">CPUs:
\echo   <input type="number" id="cpus" name="cpus" value="0">
\echo   </label>
\echo   <label for="mem" style="padding-left: 3em;">Memory(GB):
\echo   <input type="number" id="mem" name="mem" value="0">
\echo  </label>
\echo  <p style="border: 2px solid blue; border-radius: 5px; padding: 1em;">Please input the CPU and Memory available on the host machine for evaluating the current parameter settings<br />
\echo   Please see the tooltip against Parameters for recommendations based on calculations. Please seek expert advice</p>
\echo </details>
\echo </div>
\echo <h2 id="topics">Sections</h2>
\echo <ol>
\echo <li><a href="#tables">Tables</a></li>
\echo <li><a href="#indexes">Indexes</a></li>
\echo <li><a href="#parameters">Parameters / Settings</a></li>
\echo <li><a href="#extensions">Extensions</a></li>
\echo <li><a href="#activiy">Sessions Summary</a></li>
\echo <li><a href="#time">Database Time</a></li>
\echo <li><a href="#sess">Session Details</a></li>
\echo <li><a href="#blocking">Blocking Sessions</a></li>
\echo <li><a href="#statements" title="pg_get_statements">Top 10 Statements</a></li>
\echo <li><a href="#replstat">Replications</a></li>
\echo <li><a href="#bgcp" >BGWriter & Checkpointer</a></li>
\echo <li><a href="#findings">Findings</a></li>
\echo </ol>
\echo <div class="bottomright">
\echo   <a href="#topics">Sections (Alt+I)</a>
\echo </div>
\echo <h2 id="tables">Tables</h2>
\echo <p><b>NOTE : Rel size</b> is the  main fork size, <b>Tot.Tab size</b> includes all forks and toast, <b>Tab+Ind size</b> is tot_tab_size + all indexes, *Bloat estimates are indicative numbers and they can be inaccurate<br />
\echo Objects other than tables will be marked with their relkind in brackets</p>
\pset footer on
\pset tableattr 'id="tabInfo" style="display:none"'
SELECT c.relname || CASE WHEN c.relkind != 'r' THEN ' ('||c.relkind||')' ELSE '' END || CASE WHEN r.blks > 999 AND r.blks > tb.est_pages THEN ' ('||(r.blks-tb.est_pages)*100/r.blks||'% bloat*)' ELSE '' END "Name" ,
r.relnamespace "Schema",r.n_live_tup "Live tup",r.n_dead_tup "Dead tup", CASE WHEN r.n_live_tup <> 0 THEN  ROUND((r.n_dead_tup::real/r.n_live_tup::real)::numeric,4) END "Dead/Live",
r.rel_size "Rel size",r.tot_tab_size "Tot.Tab size",r.tab_ind_size "Tab+Ind size",r.rel_age,to_char(r.last_vac,'YYYY-MM-DD HH24:MI:SS') "Last vacuum",to_char(r.last_anlyze,'YYYY-MM-DD HH24:MI:SS') "Last analyze",r.vac_nos,
ct.relname "Toast name",rt.tab_ind_size "Toast+Ind" ,rt.rel_age "Toast Age",GREATEST(r.rel_age,rt.rel_age) "Max age"
FROM pg_get_rel r
JOIN pg_get_class c ON r.relid = c.reloid AND c.relkind NOT IN ('t','p')
LEFT JOIN pg_get_toast t ON r.relid = t.relid
LEFT JOIN pg_get_class ct ON t.toastid = ct.reloid
LEFT JOIN pg_get_rel rt ON rt.relid = t.toastid
LEFT JOIN pg_tab_bloat tb ON r.relid = tb.table_oid
ORDER BY r.tab_ind_size DESC LIMIT 10000; 
\pset tableattr
\echo <h2 id="indexes">Indexes</h2>
\pset tableattr 'id="IndInfo"'
SELECT ct.relname AS "Table", ci.relname as "Index",indisunique as "UK?",indisprimary as "PK?",numscans as "Scans",size
  FROM pg_get_index i 
  JOIN pg_get_class ct on i.indrelid = ct.reloid and ct.relkind != 't'
  JOIN pg_get_class ci ON i.indexrelid = ci.reloid
ORDER BY size DESC LIMIT 10000;
\pset tableattr 
\echo <h2 id="parameters">Parameters & settings</h2>
\pset tableattr 'id="params"'
SELECT s.*,string_agg(f.sourcefile ||' - '|| f.setting,chr(10)) As "Other locations" FROM pg_get_confs s
LEFT JOIN pg_get_file_confs f ON s.name = f.name AND  s.source <> f.sourcefile
GROUP BY 1,2,3,4 ORDER BY 1; 
\pset tableattr
\echo <h2 id="extensions">Extensions</h2>
SELECT ext.oid,extname,rolname as owner,extnamespace,extrelocatable,extversion FROM pg_get_extension ext
JOIN pg_get_roles on extowner=pg_get_roles.oid; 
\echo <h2 id="activiy">Session Summary</h2>
\pset footer off
\pset tableattr 'id="tblss"'
 SELECT d.datname,state,COUNT(pid) 
  FROM pg_get_activity a LEFT JOIN pg_get_db d on a.datid = d.datid
    WHERE state is not null GROUP BY 1,2 ORDER BY 1; 
\echo <h2 id="time">Database time</h2>
\pset tableattr 'id="tableConten" name="waits"'
\C 'Wait Events and CPU info'
SELECT COALESCE(wait_event,'CPU') "Event", count(*)::text FROM pg_pid_wait GROUP BY 1 ORDER BY count(*) DESC;
\C
--session waits 
\echo <h2 id="sess" style="clear: both">Session Details</h2>
\pset tableattr 'id="tblsess"' 
SELECT * FROM (
  WITH w AS (SELECT pid,COALESCE(wait_event,'CPU') wait_event,count(*) cnt FROM pg_pid_wait GROUP BY 1,2 ORDER BY 1,2),
  g AS (SELECT MAX(state_change) as ts,MAX(GREATEST(backend_xid::text::bigint,backend_xmin::text::bigint)) mx_xid FROM pg_get_activity)
  SELECT a.pid,a.state, CASE query WHEN '' THEN '**'||backend_type||' process**' ELSE left(query,60) END "Last statement", g.ts - backend_start "Connection Since", g.ts - xact_start "Transaction Since", g.mx_xid - backend_xmin::text::bigint "xmin age",
   g.ts - query_start "Statement since",g.ts - state_change "State since", string_agg( w.wait_event ||':'|| w.cnt,',') waits 
  FROM pg_get_activity a 
   LEFT JOIN w ON a.pid = w.pid
   LEFT JOIN (SELECT pid,sum(cnt) tot FROM w GROUP BY 1) s ON a.pid = s.pid
   LEFT JOIN g ON true
  WHERE a.state IS NOT NULL
  GROUP BY 1,2,3,4,5,6,7,8 ORDER BY 6 DESC NULLS LAST) AS sess
WHERE waits IS NOT NULL OR state != 'idle'; 
\echo <h2 id="blocking" style="clear: both">Blocking Sessions</h2>
\pset tableattr 'id="tblblk"'
SELECT * FROM pg_get_block; 
\echo <h2 id="statements" style="clear: both">Top 10 Statements</h2>
\pset tableattr 'id="tblstmnt"'
\C 'Statements consuming highest database time. Consider information from pg_get_statements for other criteria'
select query,total_time,calls from pg_get_statements order by 2 desc limit 10; 
\C 
\echo <h2 id="replstat" style="clear: both">Replication Status</h2>
\pset tableattr 'id="tblreplstat"'
SELECT  usename AS "Replication User",client_addr AS "Replica Address",state,
sent_offset - (write_offset - (sent_lsn - write_lsn) * 255 * 16 ^ 6 ) AS "Transmission Lag (Byte)",
sent_offset - (flush_offset - (sent_lsn - flush_lsn) * 255 * 16 ^ 6 ) AS "Flush Ack Lag (Byte)",
sent_offset - (replay_offset - (sent_lsn - replay_lsn) * 255 * 16 ^ 6 ) AS "Replay at Replica Lag (Byte)"
FROM ( SELECT usename,client_addr,state,
   ('x' || lpad(split_part(sent_lsn::TEXT,   '/', 1), 8, '0'))::bit(32)::bigint AS sent_lsn,
   ('x' || lpad(split_part(write_lsn::TEXT,   '/', 1), 8, '0'))::bit(32)::bigint AS write_lsn,
   ('x' || lpad(split_part(flush_lsn::TEXT,   '/', 1), 8, '0'))::bit(32)::bigint AS flush_lsn,
   ('x' || lpad(split_part(replay_lsn::TEXT, '/', 1), 8, '0'))::bit(32)::bigint AS replay_lsn,
   ('x' || lpad(split_part(sent_lsn::TEXT,   '/', 2), 8, '0'))::bit(32)::bigint AS sent_offset,
   ('x' || lpad(split_part(write_lsn::TEXT,   '/', 2), 8, '0'))::bit(32)::bigint AS write_offset,
   ('x' || lpad(split_part(flush_lsn::TEXT,   '/', 2), 8, '0'))::bit(32)::bigint AS flush_offset,
   ('x' || lpad(split_part(replay_lsn::TEXT, '/', 2), 8, '0'))::bit(32)::bigint AS replay_offset
FROM pg_replication_stat ) AS g;

\echo <h2 id="bgcp" style="clear: both">Background Writer and Checkpointer Information</h2>
\echo <p>Efficiency of Background writer and Checkpointer Process</p>
\pset tableattr 'id="tblchkpnt"'
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
round(100.0*maxwritten_clean/(min_since_reset*60000 / delay.setting::numeric),2)   "Bgwriter halts (%) per runs (**1)",
coalesce(round(100.0*maxwritten_clean/(nullif(buffers_clean,0)/ lru.setting::numeric),2),0)  "Bgwriter halt (%) due to LRU hit (**2)"
FROM pg_get_bgwriter
CROSS JOIN 
(SELECT 
    round(extract('epoch' from (select collect_ts from pg_gather) - stats_reset)/60)::numeric min_since_reset,
    buffers_checkpoint + buffers_clean + buffers_backend total_buffers,
    checkpoints_timed+checkpoints_req tot_cp 
    FROM pg_get_bgwriter) AS bg
JOIN pg_get_confs delay ON delay.name = 'bgwriter_delay'
JOIN pg_get_confs lru ON lru.name = 'bgwriter_lru_maxpages'; 
\echo <p>**1 What percentage of bgwriter runs results in a halt, **2 What percentage of bgwriter halts are due to hitting on <code>bgwriter_lru_maxpages</code> limit</p>
\echo <h2 id="findings" style="clear: both">Important Findings</h2>
\echo <ol id="finditem">
\pset format aligned
\pset tuples_only on
WITH W AS (SELECT COUNT(*) AS val FROM pg_get_activity WHERE state='idle in transaction')
SELECT CASE WHEN val > 0 
  THEN '<li>There are '||val||' idle in transaction session(s) please check <a href= "#blocking" >blocking sessions</a> also</li>' 
  ELSE '<li>No idle in transactions. Which is good </li>' END 
FROM W; 
WITH W AS (SELECT count(*) AS val from pg_get_rel r JOIN pg_get_class c ON r.relid = c.reloid AND c.relkind NOT IN ('t','p'))
SELECT CASE WHEN val > 10000
  THEN '<li>There are <b>'||val||' tables!</b> in this database, Only the biggest 10000 will be listed in this report under <a href= "#tabInfo" >Tables Info</a>. Please use query No. 10. from the analysis_quries.sql for full details </li>'
  ELSE NULL END
FROM W;
WITH W AS (select count(*) AS val from pg_get_index i join pg_get_class ct on i.indrelid = ct.reloid and ct.relkind != 't')
SELECT CASE WHEN val > 10000
  THEN '<li>There are <b>'||val||' indexes!</b> in this database, Only biggest 10000 will be listed in this report under <a href= "#indexes" >Index Info</a>. Please use query No. 11. from the analysis_quries.sql for full details </li>'
  ELSE NULL END
FROM W;
WITH W AS (
SELECT string_agg(cnf.name ||'='||cnf.setting||' (Default:'||T.setting||')',',') as val FROM pg_get_confs cnf
JOIN
(VALUES ('block_size','8192'),('max_identifier_length','63'),('max_function_args','100'),('max_index_keys','32'),('segment_size','131072'),('wal_block_size','8192'),('wal_segment_size','16777216')) AS T (name,setting)
ON cnf.name = T.name and cnf.setting != T.setting
)
SELECT CASE WHEN LENGTH(val) > 1
  THEN '<li>Detected Non-Standard Compile-time parameter changes <b>'||val||' </b>. Custom Compilation is not fully supported and prone to bugs </li>'
  ELSE NULL END
FROM W;
WITH W AS (
SELECT count(*) cnt FROM pg_get_confs WHERE source IS NOT NULL )
SELECT CASE WHEN cnt < 1
  THEN 'Couldn''t detect values from configuration files. Possibly corrupt Parameter file(s)'
  ELSE NULL END
FROM W;
SELECT 'ERROR :'||error ||': '||name||' with setting '||setting||' in '||sourcefile FROM pg_get_file_confs WHERE error IS NOT NULL;

\echo </ol>
\echo <div id="analdata" hidden>
\pset format unaligned
--Ability to pass SQL ananlysis to report 
SELECT to_jsonb(r) FROM
(SELECT 
  (SELECT count(*) from pg_get_rel r JOIN pg_get_class c ON r.relid = c.reloid AND c.relkind NOT IN ('t','p')) AS tabs,
  (SELECT to_jsonb(ROW(COUNT(*),COUNT(*) FILTER (WHERE CONN < interval '15 minutes' ) )) FROM 
  (WITH g AS (SELECT MAX(state_change) as ts FROM pg_get_activity)
  SELECT pid,g.ts - backend_start CONN
    FROM pg_get_activity
    LEFT JOIN g ON true
    WHERE EXISTS (SELECT pid FROM pg_pid_wait WHERE pid=pg_get_activity.pid)
    AND backend_type='client backend') cn) AS cn,
  (select count(*) from pg_get_class where relkind='p') as ptabs,
  (SELECT  to_jsonb(ROW(count(*) FILTER (WHERE state='active' AND state IS NOT NULL), 
   count(*) FILTER (WHERE state='idle in transaction'), count(*) FILTER (WHERE state='idle'),
   count(*) FILTER (WHERE state IS NULL), count(*) FILTER (WHERE leader_pid IS NOT NULL) , count(*)))
  FROM pg_get_activity) as sess
) r;

\echo </div>
\echo <script type="text/javascript">
\echo obj={};
\echo autovacuum_freeze_max_age = 0;
\echo totdb=0;
\echo totCPU=0;
\echo totMem=0;
\echo document.addEventListener("DOMContentLoaded", () => {
\echo obj=JSON.parse($("#analdata").html());
\echo checkpars();
\echo checktabs();
\echo checkdbs();
\echo checkfindings();
\echo });
\echo window.onload = function() {
\echo   document.getElementById("tabInfo").style="display:table";
\echo   document.getElementById("busy").style="display:none";
\echo };
\echo function checkfindings(){
\echo   if (obj.cn.f1 > 0){
\echo     str=obj.cn.f2 + " out of " + obj.cn.f1 + " connection in use are new. "
\echo     if (obj.cn.f2/obj.cn.f1 > 0.7 ){
\echo       str=str+"<b> Poor Connection Persistence.</b> Please improve connection pooling"
\echo     } else {
\echo       str=str+"Good connection Persistence."
\echo     }
\echo     $("#finditem").append("<li>"+ str +"</li>")
\echo   }
\echo   if (obj.ptabs > 0){
\echo     $("#finditem").append("<li>"+ obj.ptabs +" Natively partitioned tables found. Tables section could contain partitions</li>")
\echo   }
\echo   //Add footer to database details table at the top
\echo   var el=document.createElement("tfoot");
\echo   el.innerHTML = "<th colspan='9'>Total DB size : "+ bytesToSize(totdb) +"</th>";
\echo   dbs=document.getElementById("dbs");
\echo   dbs.appendChild(el);
\echo   //Add footer to Sessions Summary table
\echo   el=document.createElement("tfoot");
\echo   el.innerHTML = "<th colspan='3'>Active: "+ obj.sess.f1 +", Idle-in-transaction: " + obj.sess.f2 + ", Idle: " + obj.sess.f3 + ", Background: " + obj.sess.f4 + ", Workers: " + obj.sess.f5 + ", Total: " + obj.sess.f6 + "</th>";
\echo   tblss=document.getElementById("tblss");
\echo   tblss.appendChild(el);
\echo }
\echo document.getElementById("cpus").addEventListener("change", (event) => {
\echo   totCPU = event.target.value;
\echo   checkpars();
\echo });
\echo document.getElementById("mem").addEventListener("change", (event) => {
\echo   totMem = event.target.value;
\echo   checkpars();
\echo });
\echo function bytesToSize(bytes,divisor = 1000) {
\echo   const sizes = ["B","KB","MB","GB","TB"];
\echo   if (bytes == 0) return "0B";
\echo   const i = parseInt(Math.floor(Math.log(bytes) / Math.log(divisor)), 10);
\echo   if (i === 0) return bytes + sizes[i];
\echo   return (bytes / (divisor ** i)).toFixed(1) + sizes[i]; 
\echo }
\echo function DurationtoSeconds(duration){
\echo     const [hours, minutes, seconds] = duration.split(":");
\echo     return Number(hours) * 60 * 60 + Number(minutes) * 60 + Number(seconds);
\echo };
\echo function checkpars(){
\echo   const startTime =new Date().getTime();
\echo   trs=document.getElementById("params").rows
\echo   for(var i=1;i<trs.length;i++){
\echo     tr=trs[i]; nm=tr.cells[0]; val=tr.cells[1];
\echo     switch(nm.innerText){
\echo       case "autovacuum" :
\echo         if(val.innerText != "on") { val.classList.add("warn"); val.title="Autovacuum must be on" }
\echo         break;
\echo       case "autovacuum_max_workers" :
\echo         if(val.innerText > 3) { val.classList.add("warn"); val.title="Worker slows down as the number of workers increases" }
\echo         break;
\echo       case "autovacuum_vacuum_cost_limit" :
\echo         if(val.innerText > 800 || val.innerText == -1 ) { val.classList.add("warn"); val.title="Consider a value less than 800" }
\echo         break;
\echo       case "autovacuum_freeze_max_age" :
\echo         autovacuum_freeze_max_age = Number(val.innerText);
\echo         if (autovacuum_freeze_max_age > 800000000) val.classList.add("warn");
\echo         break;
\echo       case "deadlock_timeout":
\echo         val.classList.add("lime");
\echo         break;
\echo       case "effective_cache_size":
\echo         val.classList.add("lime"); val.title=bytesToSize(val.innerText*8192,1024);
\echo         break;
\echo       case "maintenance_work_mem":
\echo         val.classList.add("lime"); val.title=bytesToSize(val.innerText*1024,1024);
\echo         break;
\echo       case "work_mem":
\echo         val.classList.add("lime"); val.title=bytesToSize(val.innerText*1024,1024);
\echo         if(val.innerText > 98304) val.classList.add("warn");
\echo         break;
\echo       case "shared_buffers":
\echo         val.classList.add("lime"); val.title=bytesToSize(val.innerText*8192,1024);
\echo         if( totMem > 0 && ( totMem < val.innerText*8*0.2/1048576 || totMem > val.innerText*8*0.3/1048576 ))
\echo           { val.classList.add("warn"); val.title="Approx. 25% of available memory is recommended, current value of " + bytesToSize(val.innerText*8192,1024) + " appears to be off" }
\echo         break;
\echo       case "max_connections":
\echo         val.title="Avoid value exceeding 10x of the CPUs"
\echo         if( totCPU > 0 ){
\echo           if(val.innerText > 10 * totCPU) { val.classList.add("warn"); val.title="If there is only " + totCPU + " CPUs value above " + 10*totCPU + " Is not recommendable for performance and stability" }
\echo           else { val.classList.remove("warn"); val.classList.add("lime"); val.title="Current value is good" }
\echo         } else if (val.innerText > 500) val.classList.add("warn")
\echo         else val.classList.add("lime")
\echo         break;
\echo       case "max_wal_size":
\echo         val.classList.add("lime"); val.title=bytesToSize(val.innerText*1024*1024,1024);
\echo         if(val.innerText < 10240) val.classList.add("warn");
\echo         break;
\echo       case "random_page_cost":
\echo         if(val.innerText > 1.2) val.classList.add("warn");
\echo         break;
\echo       case "server_version":
\echo         val.classList.add("lime");
\echo         break;
\echo     }
\echo   }
\echo const endTime = new Date().getTime();
\echo console.log("time taken :" + (endTime - startTime));
\echo }
\echo function aged(cell){
\echo  if(cell.innerHTML > autovacuum_freeze_max_age){ cell.classList.add("warn"); cell.title =  Number(cell.innerText).toLocaleString("en-US") + "\n autovacuum_freeze_max_age=" + autovacuum_freeze_max_age.toLocaleString("en-US"); }
\echo }
\echo function checktabs(){
\echo   const startTime =new Date().getTime();
\echo   const trs=document.getElementById("tabInfo").rows
\echo   const len=trs.length;
\echo   for(var i=1;i<len;i++){
\echo   //TODO : trs.forEach (convert the for loop to forEach if possible)
\echo     tr=trs[i]; let TotTab=tr.cells[6]; TotTabSize=Number(TotTab.innerHTML); TabInd=tr.cells[7]; TabIndSize=(TabInd.innerHTML);
\echo     if(TotTabSize > 5000000000 ) { TotTab.classList.add("lime"); TotTab.title = bytesToSize(TotTabSize) + "\nBig Table, Consider Partitioning, Archive+Purge"; 
\echo     } else TotTab.title=bytesToSize(TotTabSize);
\echo     //Tab above 20MB and with Index bigger than Tab
\echo     if( TabIndSize > 2*TotTabSize && TotTabSize > 2000000 ){ TabInd.classList.add("warn"); TabInd.title="Indexes of : " + bytesToSize(TabIndSize-TotTabSize) + " is " + ((TabIndSize-TotTabSize)/TotTabSize).toFixed(2) + "x of Table " + bytesToSize(TotTabSize) + "\n Total : " + bytesToSize(TabIndSize)
\echo     } else TabInd.title=bytesToSize(TabIndSize); 
\echo     //Tab+Ind > 10GB
\echo     if (TabIndSize > 10000000000) TabInd.classList.add("lime");
\echo     aged(tr.cells[8]);
\echo     aged(tr.cells[14]);
\echo     aged(tr.cells[15]);
\echo   }
\echo const endTime = new Date().getTime();
\echo console.log("time taken for checktabs :" + (endTime - startTime));
\echo }
\echo function checktabs1(){
\echo $("#tabInfo tr").each(function(){
\echo     $(this).find("td:nth-child(9),td:nth-child(16)").each(function(){ // Age >  autovacuum_freeze_max_age, count column from 1
\echo     if( Number($(this).html()) > autovacuum_freeze_max_age )
\echo         $(this).addClass("warn").prop("title", "Age :" + Number($(this).html().trim()).toLocaleString("en-US") + "\n autovacuum_freeze_max_age=" + autovacuum_freeze_max_age.toLocaleString("en-US") );
\echo     });
\echo     TotTab = $(this).children().eq(6);   //counting from 0
\echo     TotTabSize = Number(TotTab.html());
\echo     if( TotTabSize > 5000000000 ) TotTab.addClass("lime").prop("title", bytesToSize(TotTabSize) + "\nBig Table, Consider Partitioning, Archive+Purge" );
\echo     else TotTab.prop("title",bytesToSize(TotTabSize));
\echo     TabInd = $(this).children().eq(7);  //counting from 0
\echo     TabIndSize = Number(TabInd.html());
\echo     if(TabIndSize > TotTabSize*2 && TotTabSize > 2000000 )   //Tab above 20MB and with Index bigger than Tab
\echo       TabInd.addClass("warn").prop("title", "Indexes of : " + bytesToSize(TabIndSize-TotTabSize) + " is " + ((TabIndSize-TotTabSize)/TotTabSize).toFixed(2) + "x of Table " +  bytesToSize(TotTabSize) + "\n Total : " + bytesToSize(TabIndSize));
\echo     else  TabInd.prop("title",bytesToSize(TabIndSize));
\echo     if (TabIndSize > 10000000000) TabInd.addClass("lime");  //Tab+Ind > 10GB
\echo });
\echo }
\echo function checkdbs(){
\echo $("#dbs tr").each(function(){
\echo   $tr=$(this).children();
\echo   if ($tr.eq(7).html() > 0 ) { 
\echo    totdb=totdb+Number($tr.eq(7).html());
\echo    if($tr.eq(6).html() > 1048576 ) $tr.eq(6).addClass("lime").prop("title",bytesToSize(Number($tr.eq(6).html())));
\echo    if($tr.eq(7).html() > 1048576 ) $tr.eq(7).addClass("lime").prop("title",bytesToSize(Number($tr.eq(7).html())));
\echo    if (Number($tr.eq(8).html()) > autovacuum_freeze_max_age ) $tr.eq(8).addClass("warn").prop("title", "Age :" + Number($tr.eq(8).html()).toLocaleString("en-US"));
\echo   }
\echo });
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
\echo $("#IndInfo tr").each(function(){
\echo   Scans = $(this).children().eq(4);
\echo   if(Number(Scans.html()) == 0 ) Scans.addClass("warn").prop("title","Unused Index");
\echo   IndSz = $(this).children().eq(5);
\echo   IndSz.prop("title", bytesToSize(IndSz.html()));
\echo   if (Number(IndSz.html()) > 2000000000)  IndSz.addClass("lime");
\echo });
\echo maxevnt = Number($("#tableConten tr").eq(1).children().eq(1).text());
\echo $("#tableConten tr").each(function(){
\echo   evnts = $(this).children().eq(1);
\echo   if (Number(evnts.html()) > 0 )  evnts.append(''''<div style="display:inline-block;width:' + Number(evnts.html())*1500/maxevnt + 'px; border: 7px outset brown">'''');
\echo });
\echo let blokers = []
\echo let blkvictims = []
\echo $("#tblblk tr").each(function(){
\echo   victim =$(this).children().eq(0).text();
\echo   blkr =$(this).children().eq(9).text();
\echo   if (victim > 0) blkvictims.push(victim);
\echo   if (blkr > 0) blokers.push(blkr);
\echo });
\echo $("#tblsess tr").each(function(){
\echo   pid = $(this).children().eq(0);
\echo   stime = $(this).children().eq(7);
\echo   xidage = $(this).children().eq(5);
\echo   if (xidage.text() > 20) xidage.addClass("warn");
\echo   if (blokers.indexOf(pid.text()) > -1){ 
\echo      pid.addClass("warn").prop("title","Blocker")
\echo      if (blkvictims.indexOf(pid.text()) == -1) pid.addClass("high");
\echo   };
\echo   if(DurationtoSeconds(stime.text()) > 300) stime.addClass("warn").prop("title","Busy");
\echo });
\echo if ($("#tblblk tr").length < 2){
\echo   $("#tblblk").remove();
\echo   $("#blocking").text("No Blocking Sessions Found");
\echo }
\echo if ($("#tblstmnt tr").length < 2){
\echo   $("#tblstmnt").remove();
\echo   $("#statements").text("pg_stat_statements info is not available");
\echo }
\echo if ($("#tblchkpnt tr").length > 1){
\echo   row=$("#tblchkpnt tr").eq(1)
\echo   if (row.children().eq(0).text() > 10){
\echo     row.children().eq(0).addClass("high").prop("title","More than 10% of forced checkpoints is not desirable, increase max_wal_size");
\echo   }
\echo   if(row.children().eq(1).text() < 10 ){
\echo     row.children().eq(1).addClass("high").prop("title","checkpoints are too frequent. consider checkpoint_timeout=1800");
\echo   }
\echo   if(row.children().eq(13).text() > 25){
\echo     row.children().eq(13).addClass("high").prop("title","too many dirty pages cleaned by backends");
\echo     if(row.children().eq(12).text() < 30){
\echo       row.children().eq(12).addClass("high").prop("title","bgwriter is not efficient");
\echo       if(row.children().eq(14).text() < 30){
\echo         row.children().eq(14).addClass("high").prop("title","bgwriter could run more frequently. reduce bgwriter_delay");
\echo       }
\echo       if(row.children().eq(15).text() > 30){
\echo         row.children().eq(15).addClass("high").prop("title","bgwriter halts too frequently. increase bgwriter_lru_maxpages");
\echo       }
\echo     }
\echo   }
\echo }
\echo tab=document.getElementById("tblreplstat")
\echo if (tab.rows.length > 1){
\echo   for(var i=1;i<tab.rows.length;i++){
\echo     row=tab.rows[i]
\echo     for(var j=3;j<6;j++){
\echo       cell=row.cells[j]; cell.classList.add("lime")
\echo       cell.title=bytesToSize(Number(cell.innerText),1024)
\echo    }
\echo   }
\echo }else{
\echo   tab.remove()
\echo   h2=document.getElementById("replstat")
\echo   h2.innerText="No Replication found"
\echo }
\echo $(document).keydown(function(event) {
\echo     if (event.altKey && event.which === 73)
\echo     {
\echo       $("#topics").get(0).scrollIntoView();
\echo       e.preventDefault();
\echo     }
\echo });
\echo </script>
\echo </html>
