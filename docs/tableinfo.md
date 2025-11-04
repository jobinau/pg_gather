 ## Table Level Informations as a Single Query
 It might be needed to extract the table level information displayed in the HTML report using custom queries. Please conside using the following template SQL for it. You may comment out unwanted fields.
 ```SQL
SELECT
    c.relname "Table",   -- Table name
    r.relid, -- OID of the table
    n.nsname "Schema", -- Namespacename/Schema of the table
    CASE  WHEN inh.inhrelid IS NOT NULL THEN ' Partition of ' || inhp.relname
          WHEN c.relkind != 'r' THEN ' (' ||c.relkind||')'
          ELSE 'Table (Regular)'
    END "Kind of Relation",  -- Type/Kind of relation, other than regular table
    r.n_tup_ins,  -- Number of inserted tuples from the last stats reset
    r.n_tup_upd,  -- Number of updated tuples from the last stats reset
    r.n_tup_del,  -- Number of deleted tuples from the last stats reset
    r.n_tup_hot_upd,  -- Number of HOT updated tuples from the last stats reset
    isum.totind,  -- Total number of indexes on the table
    isum.ind0scan,  -- Number of indexes never scanned since last stats reset
    isum.pk,  -- Number of primary key indexes on the table
    isum.uk,  -- Number of unique indexes on the table
    inhp.relname AS parent_table,  -- Parent table name if partition
    inhp.relkind AS parent_kind,  -- Parent table kind if partition
    c.relfilenode,  -- File node number
    c.reltablespace,  -- Tablespace OID
    ts.tsname "Tablespace", -- Tablespace name
    c.reloptions,  -- Relation level options specified
    CASE  WHEN r.blks > 999 AND r.blks > tb.est_pages THEN (r.blks-tb.est_pages)*100/r.blks
        ELSE NULL
    END "Bloat%",  --Approximate Bloat on the table
    r.n_live_tup "Live", -- Number of live tuples in the table
    r.n_dead_tup "Dead", -- Number of dead tuples in the table
    CASE  WHEN r.n_live_tup <> 0 THEN Round((r.n_dead_tup::real/r.n_live_tup::real)::numeric,1)  END "Dead/Live", -- Ratio of dead to live tuples
    r.rel_size "Rel size",-- Size of the table (without toast) in bytes
    r.tot_tab_size "Tot.Tab size", -- Size of the table (including toast) in bytes
    r.tab_ind_size "Tab+Ind size", --Size of the table (including toast and indexes) in bytes
    r.rel_age "Rel. Age", -- Age of the table in transaction ids
    To_char(r.last_vac,'YYYY-MM-DD HH24:MI:SS') "Last vacuum", -- Last vacuum date
    To_char(r.last_anlyze,'YYYY-MM-DD HH24:MI:SS') "Last analyze", -- Last analyze date
    r.vac_nos "Vaccs", -- Number of times the table has been vacuumed since last
    ct.relname "Toast name", --Name of the TOAST table associated 
    rt.tab_ind_size "Toast + Ind" , -- Size of the TOAST table (including indexes) in bytes
    rt.rel_age "Toast Age", -- Age of the TOAST table in transaction ids
    Greatest(r.rel_age,rt.rel_age) "Max age", -- Maximum Age we need to consider of the table with the TOAST table, in transaction ids 
    c.blocks_fetched "Fetch", -- Number of block fetches from the table, since the last stats reset
    c.blocks_hit*100/NULLIF(c.blocks_fetched,0) "C.Hit%", --Cache hit percentage of the table
    To_char(r.lastuse,'YYYY-MM-DD HH24:MI:SS') "Last Use" -- When was the table used for the last time
FROM      pg_get_rel r
JOIN      pg_get_class c ON r.relid = c.reloid AND c.relkind NOT IN ('t','p')
LEFT JOIN pg_get_toast t ON r.relid = t.relid
LEFT JOIN pg_get_class ct ON t.toastid = ct.reloid
LEFT JOIN pg_get_rel rt ON rt.relid = t.toastid
LEFT JOIN pg_tab_bloat tb ON r.relid = tb.table_oid
LEFT JOIN pg_get_inherits inh ON r.relid = inh.inhrelid
LEFT JOIN pg_get_class inhp ON inh.inhparent = inhp.reloid
LEFT JOIN pg_get_ns n ON r.relnamespace = n.nsoid
LEFT JOIN pg_get_tablespace ts ON c.reltablespace = ts.tsoid
LEFT JOIN
          (  SELECT   Count(indexrelid) totind,
                      Count(indexrelid)filter( WHERE numscans=0 )   ind0scan,
                      count(indexrelid) filter (WHERE indisprimary) pk,
                      count(indexrelid) filter (WHERE indisunique)  uk,
                      indrelid
            FROM     pg_get_index
            GROUP BY indrelid ) AS isum  -- Index summary grouped by table
          ON isum.indrelid = r.relid
ORDER BY  r.tab_ind_size DESC limit 10; 
```