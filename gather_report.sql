\set QUIET 1
\echo <script type="text/javascript" src="http://mozigo.risko.org/js/graficarBarras.js"></script>
\echo <script type="text/javascript" src="http://mozigo.risko.org/js/tabla2array.js"></script>
\echo <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js"></script>
\echo <style>
\echo table, th, td { border: 1px solid black; border-collapse: collapse; }
\echo th {background-color: #d2f2ff;}
\echo tr:nth-child(even) {background-color: #d2e2ff;}
\echo th { cursor: pointer;}
\echo .warn { font-weight:bold; background-color: #FAA }
\echo .lime { font-weight:bold}
\echo </style>
\H
\echo <h2>Connection and Server</h2>
SELECT replace(connstr,'You are connected to ','') "Connection / Server info" FROM pg_srvr;
\echo <div>
\echo <h2>Your Input about host resrouces </h2>
\echo <p>You may input CPU and Memory in the host server which will be used for analysis</p>
\echo  <label for="cpus">CPUs</label>
\echo  <input type="number" id="cpus" name="cpus" value="8">
\echo  <label for="mem">Memory in GB</label>
\echo  <input type="number" id="mem" name="mem" value="32">
\echo </div>
\echo <h2 id="topics">Go to Topics</h2>
\echo <ol>
\echo <li><a href="#parameters">Parameter settings</a></li>
\echo <li><a href="#findings">Important findings</a></li>
\echo <li><a href="#activiy">Session Summary</a></li>
\echo <li><a href="#time">Database time</a></li>
\echo <li><a href="#sess">Session Timing</a></li>
\echo <li><a href="#blocking">Blocking Sessions</a></li>
\echo <li><a href="#findings">Important Findings</a></li>
\echo </ol>
\echo <h2>Tables Info</h2>
\echo <p><b>NOTE : Rel size</b> is the  main fork size, <b>Tot.Tab size</b> includes all forks and toast, <b>Tab+Ind size</b> is tot_tab_size + all indexes</p>
\pset tableattr 'id="tabInfo"'
SELECT c.relname "Name",c.relkind "Kind",r.relnamespace "Schema",r.blks,r.n_live_tup "Live tup",r.n_dead_tup "Dead tup", CASE WHEN r.n_live_tup <> 0 THEN  ROUND((r.n_dead_tup::real/r.n_live_tup::real)::numeric,4) END "Dead/Live",
r.rel_size "Rel size",r.tot_tab_size "Tot.Tab size",r.tab_ind_size "Tab+Ind size",r.rel_age,r.last_vac "Last vacuum",r.last_anlyze "Last analyze",r.vac_nos,
ct.relname "Toast name",rt.tab_ind_size "Toast+Ind" ,rt.rel_age "Toast Age",GREATEST(r.rel_age,rt.rel_age) "Max age"
FROM pg_get_rel r
JOIN pg_get_class c ON r.relid = c.reloid AND c.relkind <> 't'
LEFT JOIN pg_get_toast t ON r.relid = t.relid
LEFT JOIN pg_get_class ct ON t.toastid = ct.reloid
LEFT JOIN pg_get_rel rt ON rt.relid = t.toastid; 
\pset tableattr
\echo <a href="#topics">Go to Topics</a>
\echo <h2 id="parameters">Parameters & settings</h2>
\pset tableattr 'id="params"'
SELECT * FROM pg_get_confs;
\pset tableattr
\echo <a href="#topics">Go to Topics</a>
\echo <h2 id="activiy">Session Summary</h2>
SELECT d.datname,state,COUNT(pid) 
  FROM pg_get_activity a LEFT JOIN pg_get_db d on a.datid = d.datid
    WHERE state is not null GROUP BY 1,2 ORDER BY 1;; 
\echo <a href="#topics">Go to Topics</a>
\echo <h2 id="time">Database time</h2>
\echo <canvas id="chart" width="800" height="480" style="border: 1px solid black; float:right; width:75% ">Canvas is not supported</canvas>
\pset tableattr 'id="tableConten" name="waits"'
WITH ses AS (SELECT COUNT (*) as tot, COUNT(*) FILTER (WHERE state is not null) working FROM pg_get_activity),
    waits AS (SELECT wait_event ,count(*) cnt from pg_pid_wait group by wait_event)
  SELECT 'CPU' "Event", working*2000 - (SELECT sum(cnt) FROM waits) "Count" FROM ses
  UNION ALL
  SELECT wait_event "Event", cnt "Count" FROM waits;
  --session waits 
\echo <a href="#topics">Go to Topics</a>
\pset tableattr
\echo <h2 id="sess" style="clear: both">Session Timing</h2>
WITH w AS (SELECT pid,wait_event,count(*) cnt FROM pg_pid_wait GROUP BY 1,2 ORDER BY 1,2)
SELECT a.pid,2000 - s.tot cpu,string_agg( w.wait_event ||':'|| w.cnt,',') waits FROM pg_get_activity a 
    JOIN w ON a.pid = w.pid
    JOIN (SELECT pid,sum(cnt) tot FROM w GROUP BY 1) s ON a.pid = s.pid
WHERE a.state IS NOT NULL
GROUP BY 1,2; 
\echo <a href="#topics">Go to Topics</a>

\echo <h2 id="blocking" style="clear: both">Blocking Sessions</h2>
SELECT * FROM pg_get_block;
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
\echo $("input").change(function(){  alert("Number changed"); }); 
\echo function bytesToSize(bytes) {
\echo   const sizes = ["B","KB","MB","GB","TB"];
\echo   if (bytes == 0) return 'n/a';
\echo   const i = parseInt(Math.floor(Math.log(bytes) / Math.log(1000)), 10);
\echo   if (i === 0) return bytes + sizes[i];
\echo   return (bytes / (1000 ** i)).toFixed(1) + sizes[i]; 
\echo }
\echo //Following line breaks the AWK script, because there is single quote within double quote
\echo autovacuum_freeze_max_age = Number($("#params td:contains('autovacuum_freeze_max_age')").parent().children().eq(1).text());
\echo console.log("autovacuum_freeze_max_age :"+ autovacuum_freeze_max_age);
\echo //##Analyze Table Info values
\echo $("#tabInfo tr").each(function(){
\echo     $(this).find("td:nth-child(11),td:nth-child(18)").each(function(){
\echo     //Check Table, TOAST and Max Age and compare with autovacuum_freeze_max_age
\echo     if( Number($(this).html()) > autovacuum_freeze_max_age ){
\echo         $(this).addClass("warn").prop("title", "Age is :" + Number($(this).html().trim()).toLocaleString("en-US") + ". Meanwhile, \n autovacuum_freeze_max_age=" + autovacuum_freeze_max_age.toLocaleString("en-US") );
\echo     }});
\echo     TotTab = $(this).children().eq(8);
\echo     TotTabSize = Number(TotTab.html());
\echo     if( TotTabSize > 2000000000 ){
\echo       TotTab.addClass("lime").prop("title", bytesToSize(TotTabSize) + "\nBig Table, Consider Partitioning, Archive+Purge" );
\echo     }
\echo     TabInd = $(this).children().eq(9);
\echo     TabIndSize = Number(TabInd.html());
\echo     if(TabIndSize > TotTabSize*2 && TotTabSize > 2000000 ){   //Table size above 20MB and Index size is greater than table size
\echo       TabInd.addClass("warn").prop("title", "Total Index Size : " + bytesToSize(TabIndSize-TotTabSize) + " is " + ((TabIndSize-TotTabSize)/TotTabSize).toFixed(2) + " Times the size of table of " + 
\echo           bytesToSize(TotTabSize) + "\n Total : " + bytesToSize(TabIndSize));
\echo     }
\echo });
\echo $("#tabInfo tr td:nth-child(9),td:nth-child(10)").each(function(){
\echo     if( $(this).text().trim() > 2000000000 ){
\echo         //$(this).addClass("lime").prop("title", Number($(this).text().trim()).toLocaleString("en-US") );
\echo     }
\echo });
\echo  const getCellValue = (tr, idx) => tr.children[idx].innerText || tr.children[idx].textContent;
\echo  const comparer = (idx, asc) => (a, b) => ((v1, v2) =>   v1 !== '''''' && v2 !== '''''' && !isNaN(v1) && !isNaN(v2) ? v1 - v2 : v1.toString().localeCompare(v2))(getCellValue(asc ? a : b, idx), getCellValue(asc ? b : a, idx));
\echo  document.querySelectorAll(''''th'''').forEach(th => th.addEventListener(''''click'''', (() => {
\echo      const table = th.closest(''''table'''');
\echo      Array.from(table.querySelectorAll(''''tr:nth-child(n+2)''''))
\echo          .sort(comparer(Array.from(th.parentNode.children).indexOf(th), this.asc = !this.asc))
\echo          .forEach(tr => table.appendChild(tr) );
\echo  })));

\echo $(''''<thead></thead>'''').prependTo(''''#tableConten'''').append($(''''#tableConten tr:first''''));
\echo  var misParam ={ miMargen : 0.80, separZonas : 0.05, tituloGraf : "Database Time", tituloEjeX : "Event",  tituloEjeY : "Count", nLineasDiv : 10,
\echo  mysColores :[
\echo                ["rgba(93,18,18,1)","rgba(196,19,24,1)"],  //red
\echo                ["rgba(171,115,51,1)","rgba(251,163,1,1)"], //yellow
\echo              ],
\echo     anchoLinea : 2, };
\echo    obtener_datos_tabla_convertir_en_array(''''tableConten'''',graficarBarras,''''chart'''',''''750'''',''''480'''',misParam,true);
\echo </script>

