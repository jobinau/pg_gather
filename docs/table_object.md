# Tables and Objects in a Database
A PostgreSQL Database can typically contain different types of objects  

1. Tables, where data is stored
2. Toasts, which acts as extension to tables
3. Indexes, which are associated with tables and their columns
4. Native Partitioned table, which contains only the defenitions
5. Materialized Views
6. Sequnces
7. composite types
8. Foregin tables 
   etc..

Having too many objects in a single database increases the metadata, which adversily impact the overall database performance and response.
Less that thousand database objects are most ideal.

# Get the list of objects and their details from pg_gather data
Please run the following query on the database where the pg_gather data is imported
```
SELECT c.relname "Name",c.relkind "Kind",r.relnamespace "Schema",r.blks,r.n_live_tup "Live tup",r.n_dead_tup "Dead tup", CASE WHEN r.n_live_tup <> 0 THEN  ROUND((r.n_dead_tup::real/r.n_live_tup::real)::numeric,4) END "Dead/Live",
r.rel_size "Rel size",r.tot_tab_size "Tot.Tab size",r.tab_ind_size "Tab+Ind size",r.rel_age,r.last_vac "Last vacuum",r.last_anlyze "Last analyze",r.vac_nos,
ct.relname "Toast name",rt.tab_ind_size "Toast+Ind" ,rt.rel_age "Toast Age",GREATEST(r.rel_age,rt.rel_age) "Max age"
FROM pg_get_rel r
JOIN pg_get_class c ON r.relid = c.reloid AND c.relkind NOT IN ('t','p')
LEFT JOIN pg_get_toast t ON r.relid = t.relid
LEFT JOIN pg_get_class ct ON t.toastid = ct.reloid
LEFT JOIN pg_get_rel rt ON rt.relid = t.toastid
ORDER BY r.tab_ind_size DESC;
```
