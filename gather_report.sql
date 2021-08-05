\set QUIET 1
\echo <html><meta charset="utf-8" />
\echo <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js"></script>
\echo <style>
\echo table, th, td { border: 1px solid black; border-collapse: collapse; }
\echo th {background-color: #d2f2ff;}
\echo tr:nth-child(even) {background-color: #d2e2ff;}
\echo th { cursor: pointer;}
\echo .warn { font-weight:bold; background-color: #FAA }
\echo .lime { font-weight:bold}
\echo .lineblk {float: left; margin:5px }
\echo </style>
\H
\pset footer off 
\echo <h1>pg_gather Report <b id="busy" class="warn"> Loading... </b></h1>
\pset tableattr 'class="lineblk"'
SELECT (SELECT count(*) > 1 FROM pg_srvr WHERE connstr ilike 'You%') AS conlines \gset
\if :conlines
  \echo "There is serious problem with the data. Please make sure that all tables are dropped and recreated as part of importing data (gather_schema.sql) and there was no error"
  "SOMETHING WENT WRONG WHILE IMPORTING THE DATA. PLEASE MAKE SURE THAT ALL TABLES ARE DROPPED AND RECREATED AS PART OF IMPORTING";
  \q
\endif
SELECT  UNNEST(ARRAY ['Collected At','Collected By','PG build', 'PG Start','In recovery?','Client','Server','Last Reload','Current LSN']) AS pg_gather,
        UNNEST(ARRAY [collect_ts::text,usr,ver, pg_start_ts::text ||' ('|| collect_ts-pg_start_ts || ')',recovery::text,client::text,server::text,reload_ts::text,current_wal::text]) AS "Report Version V9"
FROM pg_gather;
SELECT replace(connstr,'You are connected to ','') "pg_gather Connection and PostgreSQL Server info" FROM pg_srvr; 
\pset tableattr 'id="dbs"'
SELECT datname DB,xact_commit commits,xact_rollback rollbacks,tup_inserted+tup_updated+tup_deleted transactions, blks_hit*100/blks_fetch  hit_ratio,temp_files,temp_bytes,db_size,age FROM pg_get_db where blks_fetch != 0;
\pset tableattr off

\echo <button id="tog" style="display: block;clear: both">[+]</button>
\echo <div id="divins" style="display:none">
\echo <h2>Manual input about host resources</h2>
\echo <p>You may input CPU and Memory in the host machine / vm which will be used for analysis</p>
\echo  <label for="cpus">CPUs</label>
\echo  <input type="number" id="cpus" name="cpus" value="8">
\echo  <label for="mem">Memory in GB</label>
\echo  <input type="number" id="mem" name="mem" value="32">
\echo </div>
\echo <h2 id="topics">Go to Topics</h2>
\echo <ol>
\echo <li><a href="#indexes">Index Info</a></li>
\echo <li><a href="#parameters">Parameter settings</a></li>
\echo <li><a href="#extensions">Extensions</a></li>
\echo <li><a href="#activiy">Session Summary</a></li>
\echo <li><a href="#time">Database Time</a></li>
\echo <li><a href="#sess">Session Details</a></li>
\echo <li><a href="#blocking">Blocking Sessions</a></li>
\echo <li><a href="#statements" title="pg_get_statements">Top 10 Statements</a></li>
\echo <li><a href="#bgcp" >Background Writer and Checkpointer</a></li>
\echo <li><a href="#findings">Important Findings</a></li>
\echo </ol>
\echo <h2>Tables Info</h2>
\echo <p><b>NOTE : Rel size</b> is the  main fork size, <b>Tot.Tab size</b> includes all forks and toast, <b>Tab+Ind size</b> is tot_tab_size + all indexes</p>
\pset footer on
\pset tableattr 'id="tabInfo"'
SELECT c.relname "Name",c.relkind "Kind",r.relnamespace "Schema",r.blks,r.n_live_tup "Live tup",r.n_dead_tup "Dead tup", CASE WHEN r.n_live_tup <> 0 THEN  ROUND((r.n_dead_tup::real/r.n_live_tup::real)::numeric,4) END "Dead/Live",
r.rel_size "Rel size",r.tot_tab_size "Tot.Tab size",r.tab_ind_size "Tab+Ind size",r.rel_age,r.last_vac "Last vacuum",r.last_anlyze "Last analyze",r.vac_nos,
ct.relname "Toast name",rt.tab_ind_size "Toast+Ind" ,rt.rel_age "Toast Age",GREATEST(r.rel_age,rt.rel_age) "Max age"
FROM pg_get_rel r
JOIN pg_get_class c ON r.relid = c.reloid AND c.relkind NOT IN ('t','p')
LEFT JOIN pg_get_toast t ON r.relid = t.relid
LEFT JOIN pg_get_class ct ON t.toastid = ct.reloid
LEFT JOIN pg_get_rel rt ON rt.relid = t.toastid; 
\pset tableattr
\echo <a href="#topics">Go to Topics</a>
\echo <h2 id="indexes">Index Info</h2>
\pset tableattr 'id="IndInfo"'
SELECT ct.relname AS "Table", ci.relname as "Index",indisunique,indisprimary,numscans,size
  FROM pg_get_index i 
  JOIN pg_get_class ct on i.indrelid = ct.reloid and ct.relkind != 't'
  JOIN pg_get_class ci ON i.indexrelid = ci.reloid;
\pset tableattr 
\echo <a href="#topics">Go to Topics</a>
\echo <h2 id="parameters">Parameters & settings</h2>
\pset tableattr 'id="params"'
SELECT * FROM pg_get_confs;
\pset tableattr
\echo <a href="#topics">Go to Topics</a>
\echo <h2 id="extensions">Extensions</h2>
SELECT ext.oid,extname,rolname as owner,extnamespace,extrelocatable,extversion FROM pg_get_extension ext
JOIN pg_get_roles on extowner=pg_get_roles.oid; 
\echo <a href="#topics">Go to Topics</a>
\echo <h2 id="activiy">Session Summary</h2>
\pset footer off
 SELECT d.datname,state,COUNT(pid) 
  FROM pg_get_activity a LEFT JOIN pg_get_db d on a.datid = d.datid
    WHERE state is not null GROUP BY 1,2 ORDER BY 1; 
\echo <a href="#topics">Go to Topics</a>
\echo <h2 id="time">Database time</h2>
\pset tableattr 'id="tableConten" name="waits"'
SELECT COALESCE(wait_event,'CPU') "Event", count(*)::text FROM pg_pid_wait GROUP BY 1 ORDER BY count(*) DESC;
--session waits 
\echo <a href="#topics">Go to Topics</a>
\pset tableattr
\echo <h2 id="sess" style="clear: both">Session Details</h2>
SELECT * FROM (
  WITH w AS (SELECT pid,wait_event,count(*) cnt FROM pg_pid_wait GROUP BY 1,2 ORDER BY 1,2),
  g AS (SELECT collect_ts FROM pg_gather)
  SELECT a.pid,a.state, left(query,60) "Last statement", g.collect_ts - backend_start "Connection Since",  g.collect_ts - query_start "Statement since",g.collect_ts - state_change "State since", string_agg( w.wait_event ||':'|| w.cnt,',') waits 
  FROM pg_get_activity a 
   LEFT JOIN w ON a.pid = w.pid
   LEFT JOIN (SELECT pid,sum(cnt) tot FROM w GROUP BY 1) s ON a.pid = s.pid
   LEFT JOIN g ON true
  WHERE a.state IS NOT NULL
  GROUP BY 1,2,3,4,5,6) AS sess
  WHERE waits IS NOT NULL OR state != 'idle'; 
\echo <a href="#topics">Go to Topics</a>
\echo <h2 id="blocking" style="clear: both">Blocking Sessions</h2>
SELECT * FROM pg_get_block;
\echo <a href="#topics">Go to Topics</a>
\echo <h2 id="statements" style="clear: both">Top 10 Statements</h2>
\echo <p>Statements consuming highest database time. Consider information from pg_get_statements for other criteria</p>
select query,total_time,calls from pg_get_statements order by 2 desc limit 10;
\echo <a href="#topics">Go to Topics</a>
\echo <h2 id="bgcp" style="clear: both">Background Writer and Checkpointer Information</h2>
\echo <p>Efficiency of Background writer and Checkpointer Process</p>
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
round(100.0*maxwritten_clean/(min_since_reset*60000 / delay.setting::numeric),2)   "Bgwriter halts per runs(%)",
coalesce(round(100.0*maxwritten_clean/(nullif(buffers_clean,0)/ lru.setting::numeric),2),0)  "Bgwriter halts due to LRU hit (%)"
FROM pg_get_bgwriter
CROSS JOIN 
(SELECT 
    round(extract('epoch' from (select collect_ts from pg_gather) - stats_reset)/60)::numeric min_since_reset,
    buffers_checkpoint + buffers_clean + buffers_backend total_buffers,
    checkpoints_timed+checkpoints_req tot_cp 
    FROM pg_get_bgwriter) AS bg
JOIN pg_get_confs delay ON delay.name = 'bgwriter_delay'
JOIN pg_get_confs lru ON lru.name = 'bgwriter_lru_maxpages'; 
\echo <a href="#topics">Go to Topics</a>

\echo <h2 id="findings" style="clear: both">Important Findings</h2>
\pset format aligned
\pset tuples_only on
WITH W AS (SELECT COUNT(*) AS val FROM pg_get_activity WHERE state='idle in transaction')
SELECT CASE WHEN val > 0 
  THEN 'There are '||val||' idle in transaction session(s) please check <a href= "#blocking" >blocking sessions</a> also<br>' 
  ELSE 'No idle in transactions <br>' END 
FROM W; 
\echo <a href="#topics">Go to Topics</a>
\echo <script type="text/javascript">
\echo $(function() { $("#busy").hide(); });
\echo $("input").change(function(){  alert("Number changed"); }); 
\echo $("#tog").click(function(){
\echo         $("#divins").toggle("slow",function(){
\echo         if($("#divins").is(":visible")) $("#tog").text("[-]"); 
\echo         else $("#tog").text("[+]"); 
\echo     }) });
\echo function bytesToSize(bytes,divisor = 1000) {
\echo   const sizes = ["B","KB","MB","GB","TB"];
\echo   if (bytes == 0) return "0B";
\echo   const i = parseInt(Math.floor(Math.log(bytes) / Math.log(divisor)), 10);
\echo   if (i === 0) return bytes + sizes[i];
\echo   return (bytes / (divisor ** i)).toFixed(1) + sizes[i]; 
\echo }
\echo autovacuum_freeze_max_age = 0; //Number($("#params td:contains('autovacuum_freeze_max_age')").parent().children().eq(1).text());
\echo function checkpars(){   //parameter checking
\echo $("#params tr").each(function(){
\echo   switch($(this).children().eq(0).text()) {
\echo     case "autovacuum_max_workers" :
\echo       console.log($(this).children().eq(1).text());
\echo       break;
\echo     case "autovacuum_vacuum_cost_limit" :
\echo       console.log($(this).children().eq(1).text());
\echo       break;
\echo     case "autovacuum_freeze_max_age" :
\echo       autovacuum_freeze_max_age = Number($(this).children().eq(1).text());
\echo       break;
\echo     case "deadlock_timeout":
\echo       $(this).children().eq(1).addClass("lime").prop("title",$(this).children().eq(2).text());
\echo       break;
\echo     case "effective_cache_size":
\echo       $(this).children().eq(1).addClass("lime").prop("title",bytesToSize($(this).children().eq(1).text()*8*1024,1024));
\echo       break;
\echo     case "maintenance_work_mem":
\echo       $(this).children().eq(1).addClass("lime").prop("title",bytesToSize($(this).children().eq(1).text()*1024,1024));
\echo       break;
\echo     case "work_mem":
\echo       $(this).children().eq(1).addClass("lime").prop("title",bytesToSize($(this).children().eq(1).text()*1024,1024));
\echo       break;
\echo     case "shared_buffers":
\echo       $(this).children().eq(1).addClass("lime").prop("title",bytesToSize($(this).children().eq(1).text()*8*1024,1024));
\echo       break;
\echo     case "max_connections":
\echo       $(this).children().eq(1).addClass("lime").prop("title",$(this).children().eq(1).text());
\echo       if($(this).children().eq(1).text() > 500) $(this).children().eq(1).addClass("warn");
\echo       break;
\echo     case "max_wal_size":
\echo       $(this).children().eq(1).addClass("lime").prop("title",bytesToSize($(this).children().eq(1).text()*1024*1024,1024));
\echo       if($(this).children().eq(1).text() < 10240) $(this).children().eq(1).addClass("warn");
\echo       break;
\echo     case "random_page_cost":
\echo       if($(this).children().eq(1).text() > 1.2) $(this).children().eq(1).addClass("warn");
\echo       break;
\echo     case "server_version":
\echo       $(this).children().eq(1).addClass("lime");
\echo       break;
\echo   }
\echo });
\echo }
\echo checkpars();
\echo $("#tabInfo tr").each(function(){
\echo     $(this).find("td:nth-child(11),td:nth-child(18)").each(function(){ // Age >  autovacuum_freeze_max_age
\echo     if( Number($(this).html()) > autovacuum_freeze_max_age )
\echo         $(this).addClass("warn").prop("title", "Age :" + Number($(this).html().trim()).toLocaleString("en-US") + "\n autovacuum_freeze_max_age=" + autovacuum_freeze_max_age.toLocaleString("en-US") );
\echo     });
\echo     TotTab = $(this).children().eq(8);
\echo     TotTabSize = Number(TotTab.html());
\echo     if( TotTabSize > 5000000000 ) TotTab.addClass("lime").prop("title", bytesToSize(TotTabSize) + "\nBig Table, Consider Partitioning, Archive+Purge" );
\echo     else TotTab.prop("title",bytesToSize(TotTabSize));
\echo     TabInd = $(this).children().eq(9);
\echo     TabIndSize = Number(TabInd.html());
\echo     if(TabIndSize > TotTabSize*2 && TotTabSize > 2000000 )   //Tab above 20MB and with Index bigger than Tab
\echo       TabInd.addClass("warn").prop("title", "Indexes of : " + bytesToSize(TabIndSize-TotTabSize) + " is " + ((TabIndSize-TotTabSize)/TotTabSize).toFixed(2) + "x of Table " +  bytesToSize(TotTabSize) + "\n Total : " + bytesToSize(TabIndSize));
\echo     else  TabInd.prop("title",bytesToSize(TabIndSize));
\echo     if (TabIndSize > 10000000000) TabInd.addClass("lime");  //Tab+Ind > 10GB
\echo });
\echo //Inspect database level info
\echo $("#dbs tr").each(function(){
\echo   $(this).find("td:nth-child(7),td:nth-child(8)").each(function(){
\echo     if( Number($(this).html()) > 1048576 )  //more than 1 MB
\echo       $(this).addClass("lime").prop("title",bytesToSize(Number($(this).html())));
\echo   });
\echo   //console.log($(this).children().eq(8).html());
\echo   if (Number($(this).children().eq(8).html()) > 400000000) $(this).children().eq(8).addClass("warn").prop("title", "Age :" + Number($(this).children().eq(8).html()).toLocaleString("en-US"));
\echo });
\echo const getCellValue = (tr, idx) => tr.children[idx].innerText || tr.children[idx].textContent;
\echo const comparer = (idx, asc) => (a, b) => ((v1, v2) =>   v1 !== '''''' && v2 !== '''''' && !isNaN(v1) && !isNaN(v2) ? v1 - v2 : v1.toString().localeCompare(v2))(getCellValue(asc ? a : b, idx), getCellValue(asc ? b : a, idx));
\echo document.querySelectorAll(''''th'''').forEach(th => th.addEventListener(''''click'''', (() => {
\echo   const table = th.closest(''''table'''');
\echo   th.style.cursor = "progress";
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
\echo // var misParam ={ miMargen : 0.80, separZonas : 0.05, tituloGraf : "Database Time", tituloEjeX : "Event",  tituloEjeY : "Count", nLineasDiv : 10,
\echo // mysColores :[
\echo //               ["rgba(93,18,18,1)","rgba(196,19,24,1)"],  //red
\echo //               ["rgba(171,115,51,1)","rgba(251,163,1,1)"], //yellow
\echo //             ],
\echo //    anchoLinea : 2, };
\echo //  obtener_datos_tabla_convertir_en_array(''''tableConten'''',graficarBarras,''''chart'''',''''750'''',''''480'''',misParam,true);
\echo </script>
\echo </html>
