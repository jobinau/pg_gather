# Unused Indexes

Unused indexes cause severe penalties in the system: It slow down DML operations for no benefit, They consume more memory, They Cause more IO, Generate more WAL, and Autovacuum will have more work to do. 

## From pg_gather

Following SQL statement can be used against the database where the pg_gather data is imported.

```
SELECT ns.nsname AS "Schema", ct.relname AS "Table", ci.relname as "Index",indisunique as "UK?",indisprimary as "PK?",numscans as "Scans",size,ci.blocks_fetched "Fetch",ci.blocks_hit*100/nullif(ci.blocks_fetched,0) "C.Hit%", to_char(i.lastuse,'YYYY-MM-DD HH24:MI:SS') "Last Use"
  FROM pg_get_index i 
  JOIN pg_get_class ct on i.indrelid = ct.reloid and ct.relkind != 't'
  JOIN pg_get_ns ns ON ct.relnamespace = ns.nsoid
  JOIN pg_get_class ci ON i.indexrelid = ci.reloid
WHERE numscans = 0;
```

## From database 
Following SQL statement can be used agains the target database 
```
SELECT n.nspname AS schema,relid::regclass as table, indexrelid::regclass as index, indisunique, indisprimary
    FROM pg_stat_user_indexes
    JOIN pg_index i USING (indexrelid)
    JOIN pg_class c ON i.indexrelid = c.oid
    JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE idx_scan = 0;
```