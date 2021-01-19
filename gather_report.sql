--\pset border 2
\echo <style>
\echo table, th, td { border: 1px solid black; border-collapse: collapse; }
\echo th {background-color: #d2f2ff;}
\echo tr:nth-child(even) {background-color: #d2e2ff;}
\echo th { cursor: pointer;}
\echo </style>
\H
\echo <h2>Connection and Server</h2>
SELECT replace(connstr,'You are connected to ','') "Connection / Server info" FROM pg_srvr;
\echo <h2 id="topics">Go to Topics</h2>
\echo <ol>
\echo <li><a href="#parameters">Parameter settings</a></li>
\echo <li><a href="#findings">Important findings</a></li>
\echo </ol>
\echo <h2>Tables Info</h2>
\echo <p><b>NOTE : Rel size</b> is the  main fork size, <b>Tot.Tab size</b> includes all forks and toast, <b>Tab+Ind size</b> is tot_tab_size + all indexes</p>
SELECT c.relname "Name",c.relkind "Kind",r.relnamespace "Schema",r.blks,r.n_live_tup "Live tup",r.n_dead_tup "Dead tup",
   r.rel_size "Rel size",r.tot_tab_size "Tot.Tab size",r.tab_ind_size "Tab+Ind size",r.rel_age,r.last_vac "Last vacuum",r.last_anlyze "Last analyze",r.vac_nos,
   ct.relname "Toast name",rt.tab_ind_size "Toast+Ind" ,rt.rel_age "Toast Age",GREATEST(r.rel_age,rt.rel_age) "Max age"
  FROM pg_get_rel r
  JOIN pg_get_class c ON r.relid = c.reloid AND c.relkind <> 't'
  LEFT JOIN pg_get_toast t ON r.relid = t.relid
  LEFT JOIN pg_get_class ct ON t.toastid = ct.reloid
  LEFT JOIN pg_get_rel rt ON rt.relid = t.toastid;
\echo <a href="#topics">Go to Topics</a>
\echo <h2 id="parameters">Parameters & settings</h2>
SELECT * FROM pg_get_confs;
\echo <a href="#topics">Go to Topics</a>
\echo <h2 id="findings">Important Findings</h2>
\echo <a href="#topics">Go to Topics</a>
\echo <script type="text/javascript">
\echo  const getCellValue = (tr, idx) => tr.children[idx].innerText || tr.children[idx].textContent;
\echo  const comparer = (idx, asc) => (a, b) => ((v1, v2) =>   v1 !== '''''' && v2 !== '''''' && !isNaN(v1) && !isNaN(v2) ? v1 - v2 : v1.toString().localeCompare(v2))(getCellValue(asc ? a : b, idx), getCellValue(asc ? b : a, idx));
\echo  document.querySelectorAll(''''th'''').forEach(th => th.addEventListener(''''click'''', (() => {
\echo      const table = th.closest(''''table'''');
\echo      Array.from(table.querySelectorAll(''''tr:nth-child(n+2)''''))
\echo          .sort(comparer(Array.from(th.parentNode.children).indexOf(th), this.asc = !this.asc))
\echo          .forEach(tr => table.appendChild(tr) );
\echo  })));
\echo  </script>
  
