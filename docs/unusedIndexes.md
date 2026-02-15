# Unused Indexes

Unused indexes cause severe penalties in the system: It slow down DML operations for no benefit, They consume more memory, They Cause more IO, Generate more WAL, and Autovacuum will have more work to do. 

## From pg_gather

Following SQL statement can be used against the database where the pg_gather data is imported.

```
SELECT  ns.nsname AS "Schema",ci.relname as "Index", ct.relname AS "Table", ptab.relname "TOAST of Table",
indisunique as "UK?",indisprimary as "PK?",numscans as "Scans",size,ci.blocks_fetched "Fetch",ci.blocks_hit*100/nullif(ci.blocks_fetched,0) "C.Hit%", to_char(i.lastuse,'YYYY-MM-DD HH24:MI:SS') "Last Use"
 FROM pg_get_index i
 JOIN pg_get_class ct ON i.indrelid = ct.reloid
 JOIN pg_get_ns ns ON ct.relnamespace = ns.nsoid
 JOIN pg_get_class ci ON i.indexrelid = ci.reloid
 LEFT JOIN pg_get_toast tst ON ct.reloid = tst.toastid
 LEFT JOIN pg_get_class ptab ON tst.relid = ptab.reloid
 WHERE tst.relid IS NULL OR ptab.reloid IS NOT NULL
 ORDER BY size DESC;
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
OR more detailed (TOAST and TOAST index)
```
SELECT n.nspname AS schema,t.relname "table", c.relname as index, tst.relname "TOAST",
tst.oid "TOAST ID 1",
tstind.relid "TOAST ID 2",
tstind.indexrelname "TOAST Index",  
tstind.indexrelid "TOST INDEX relid",
i.indisunique, i.indisprimary,pg_stat_user_indexes.idx_scan "Index usage", tstind.idx_scan "Toast index usage"
    FROM pg_stat_user_indexes
    JOIN pg_index i USING (indexrelid)
    JOIN pg_class c ON i.indexrelid = c.oid
    JOIN pg_class t ON i.indrelid = t.oid
    JOIN pg_namespace n ON c.relnamespace = n.oid
    LEFT JOIN pg_class tst ON t.reltoastrelid = tst.oid
    LEFT JOIN pg_stat_all_indexes tstind ON tst.oid = tstind.relid;
```

## Unused Index in a Cluster
Indexes which are not used on Primary might be used on Standbies / Replicas.
pg_gather history schema can be used for conducting a detailed study.
Following steps can be performed on the database where final analysis and report generation is done.
### Step 1. Create history schema, if not existing
```
psql -f 
```
### Step 2. Import/download the data collection from standby (Just like single instance)
```
psql -X -f gather_schema.sql -f standby1.tsv
```

### Step 3. MERGE the index information to the history schema
```SQL
MERGE INTO history.pg_get_index AS target
USING pg_get_index AS source
ON target.indexrelid = source.indexrelid
WHEN MATCHED THEN
    UPDATE SET
        lastuse = GREATEST(source.lastuse, target.lastuse),
        numscans = COALESCE(target.numscans, 0) + COALESCE(source.numscans, 0),
        collect_ts = NOW()
WHEN NOT MATCHED THEN
    INSERT (collect_ts, indexrelid, indrelid, indisunique, indisprimary, indisvalid, numscans, size, lastuse)
    VALUES ( NOW(), source.indexrelid, source.indrelid, source.indisunique, source.indisprimary, source.indisvalid,
        COALESCE(source.numscans, 0), source.size,    source.lastuse
    );
```
### Step 4. Do steps 2 and 3 for every standby.

### Step 5. Import/Download the data collection from Primary (Just like single instance)
```
psql -X -f gather_schema.sql -f primary.tsv
```
### Step 6. MERGE the index information from history schema back
```SQL
MERGE INTO pg_get_index AS target
USING history.pg_get_index AS source
ON target.indexrelid = source.indexrelid
WHEN MATCHED THEN
    UPDATE SET
        numscans = COALESCE(target.numscans, 0) + COALESCE(source.numscans, 0),
        lastuse = GREATEST(source.lastuse, target.lastuse)
WHEN NOT MATCHED THEN
    INSERT ( indexrelid, indrelid, indisunique, indisprimary, indisvalid, numscans, size, lastuse )
    VALUES ( source.indexrelid, source.indrelid, source.indisunique, source.indisprimary, source.indisvalid, 
    COALESCE(source.numscans, 0), source.size, source.lastuse
    );
```
### Step 7. Generate the pg_gather report as usual
```
psql -X -f gather_report.sql > out.html
```
