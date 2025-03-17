# Bloated Tables
Table bloat can affect the performance of individual SQL statements as well as the entire database. This is because PostgreSQL needs to scan and fetch more pages to process an SQL statement.
A bloat beyond 20% need to be considered serious.

# How do I get the List
pg_gather report, which presents the list of bloated tables? Just sort by "Bloat%' column

## From pg_gather backend
following SQL might help
```
SELECT c.relname || CASE WHEN inh.inhrelid IS NOT NULL THEN ' (part)'
 WHEN c.relkind != 'r' THEN ' ('||c.relkind||')'
 ELSE '' END "Name",
 n.nsname "Schema", 
 CASE  WHEN r.blks > 999  AND r.blks > tb.est_pages THEN (r.blks-tb.est_pages)*100/r.blks
 ELSE NULL END "Bloat%",
 r.n_live_tup "Live", r.n_dead_tup "Dead",  
 CASE WHEN r.n_live_tup <> 0 THEN ROUND((r.n_dead_tup::real/r.n_live_tup::real)::numeric,1) END "D/L",
 r.rel_size "Rel size",  r.tot_tab_size "Tot.Tab size", r.tab_ind_size "Tab+Ind size"
FROM pg_get_rel r
JOIN pg_get_class c ON r.relid = c.reloid AND c.relkind NOT IN ('t', 'p')
JOIN pg_get_ns n ON r.relnamespace = n.nsoid
LEFT JOIN pg_tab_bloat tb ON r.relid = tb.table_oid
LEFT JOIN pg_get_inherits inh ON r.relid = inh.inhrelid
WHERE r.blks > 999 AND r.blks > tb.est_pages AND (r.blks-tb.est_pages)*100/nullif(r.blks,0) > 20;
```

## Directly from the database.
Getting information directly from the database is more reliable, and more investigation is possible.
Please consider using the SQL script :
https://github.com/jobinau/pgsql-bloat-estimation/blob/master/table/table_bloat.sql

# How to Fix
If the table is already bloated, recovering and releasing the space back to storage is highly recommended.
There are generally two options for that.
### Using VACUUM FULL
This is a built-in feature of PostgreSQL that rebuilds the entire table and its indexes. During this operation, the table will be locked exclusively. So avoid doing this without a proper maintenance window.  
Proper `statement_timeout` settings should allow us to do this for small tables (a few MBs). For example: 
```
SET statement_timeout = '10s';
VACUUM FULL pg_get_class;
```
### Using pg_repack
If the table is big and getting a maintenance window is not allowed, Or if the application cannot afford to have an exclusive lock on the table which remains until the completion of maintenance. Then consider using the pg_repack extension.  
Refer: https://reorg.github.io/pg_repack/

# How to Avoid
Table bloat can be avoided to certain extent with the following
1. **Adjust the FILLFACTOR at the table level**  
Please refer to the details at table level in the pg_gather report. Sufficient free space per page helps on HOT (Heap Only Tuple) update
2. **Adjust the vacuum settings per table**  
Please refer to the details at table level in the pg_gather report
3. **Reduce the number of indexes on the table**  
Reduce the number of indexes, especially getrid of unused and rarely used indexes. Indexes can prevent HOT updates.  Please avoid indexing the column which is frequently updated.
4. **Have supplementary vacuum job scheduled on off-peak times**  
This ensures that the vacuum workers are free enough during the peak time to take care of the autovacuum of tables, which requires attention.  
 Refer : https://github.com/jobinau/pgscripts/blob/main/vacuumjob.sql

 