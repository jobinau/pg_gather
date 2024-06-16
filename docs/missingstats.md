# Tables missing statistics

Missing Statistics on tables can result in poor execution planning. 
Generally Statistics will be collected by autovacuum runs or explicit ANALYZE command.
But in rare conditions, There could be tables without any statics leading to poor query planning.

## Tables without statistics (From pg_gather data)
Following query can be executed on the database where pg_gather data is imported.

```
SELECT nsname "Schema" , relname "Table",n_live_tup "Tuples"
FROM pg_get_class c LEFT JOIN pg_get_ns n ON c.relnamespace = n.nsoid
   JOIN pg_get_rel r ON c.reloid = r.relid AND relkind='r' AND r.n_live_tup != 0
WHERE NOT EXISTS (select table_oid from pg_tab_bloat WHERE table_oid=c.reloid) 
AND nsname <> ALL (ARRAY['pg_catalog'::name, 'information_schema'::name]);
```

## Tables without statistics  (Directly from catalog)
Following query can be executed on the *target database* to get the list of tables for which stats need to be collected using ANALYZE
```
SELECT c.oid,nspname "Schema",relname "Table",pg_stat_get_live_tuples(c.oid) "Tuples" 
FROM pg_class c
JOIN pg_namespace as n ON relkind = 'r' AND n.oid = c.relnamespace 
  AND n.nspname <> ALL (ARRAY['pg_catalog'::name, 'information_schema'::name])
WHERE NOT EXISTS (SELECT starelid FROM pg_statistic WHERE starelid=c.oid)
  AND pg_stat_get_live_tuples(c.oid) != 0;
```
