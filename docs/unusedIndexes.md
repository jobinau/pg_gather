# Unused Indexes

Unused indexes cause severe penalties in the system: They slow down DML operations for no benefit, they consume more memory, they cause more IO, they generate more WAL, and autovacuum will have more work to do.

## Before you drop anything

Index usage counters answer only one question: *"was this index scanned since the statistics were last reset?"*. Please verify the following before treating a zero-scan index as droppable.

1. **Check the observation window.** A counter of `0` on statistics reset an hour ago proves nothing. On the source database, check `SELECT stats_reset FROM pg_stat_database WHERE datname = current_database();` and compare it with the server start time. The window should cover a full business cycle, including weekly/monthly/quarterly batch jobs and reporting.
2. **Primary Key and Unique indexes enforce constraints.** They will show `0` scans when the constraint is only used for enforcing uniqueness, but dropping them changes data integrity. See [Primary Key and Unique Key](pkuk.md).
3. **Indexes on the referenced side of a Foreign Key** are needed for the FK check and for `ON DELETE`/`ON UPDATE` actions, and these lookups are not always visible in the scan counters.
4. **REPLICA IDENTITY.** An index used as `REPLICA IDENTITY USING INDEX` is required for logical replication of `UPDATE`/`DELETE`.
5. **Standbys have their own counters.** Please see [Unused Index in a Cluster](#unused-index-in-a-cluster) below.
6. **Invalid indexes** are never used by the planner, so they always appear unused. They are a different problem, addressed in [Invalid Indexes](InvalidIndexes.md).
7. **Capture the DDL first.** `SELECT pg_get_indexdef(indexrelid);` on the source database, so that the index can be recreated if the drop turns out to be wrong. `DROP INDEX CONCURRENTLY` avoids blocking on a busy system.

## From pg_gather

Following SQL statement can be used against the database where the pg_gather data is imported.

```sql
SELECT ns.nsname AS "Schema", ci.relname AS "Index", ct.relname AS "Table", ptab.relname AS "TOAST of Table",
       i.indisunique AS "UK?", i.indisprimary AS "PK?", i.indisvalid AS "Valid?",
       i.numscans AS "Scans", pg_size_pretty(i.size) AS "Size",
       ci.blocks_fetched AS "Fetch",
       round(ci.blocks_hit * 100.0 / nullif(ci.blocks_fetched, 0), 1) AS "C.Hit%",
       to_char(i.lastuse, 'YYYY-MM-DD HH24:MI:SS') AS "Last Use"
 FROM pg_get_index i
 JOIN pg_get_class ct ON i.indrelid = ct.reloid
 JOIN pg_get_ns ns ON ct.relnamespace = ns.nsoid
 JOIN pg_get_class ci ON i.indexrelid = ci.reloid
 LEFT JOIN pg_get_toast tst ON ct.reloid = tst.toastid
 LEFT JOIN pg_get_class ptab ON tst.relid = ptab.reloid
 WHERE (tst.relid IS NULL OR ptab.reloid IS NOT NULL) --Drops TOAST indexes of catalog tables
   AND i.numscans = 0                                 --Remove this line to list every index
 ORDER BY i.size DESC;
```

Notes on the output:

* `Scans` is the number of index scans, `Last Use` is the timestamp of the last scan. **`Last Use` is available only if the data was collected from PostgreSQL 16 or above**, it will be `NULL` for older versions.
* `Fetch` and `C.Hit%` come from the block statistics of the index. A high `Fetch` count on a `0` scan index means the index is being read and cached without ever serving a query, which is pure overhead.
* A TOAST index is listed with the parent table in the `TOAST of Table` column. TOAST indexes cannot be dropped, they are listed for accounting the space and cache they consume.
* pg_gather does not collect the index definition. Please use `pg_get_indexdef()` on the source database for the DDL.

Total space that can be reclaimed, excluding constraint backing indexes:

```sql
SELECT count(*) AS "Unused Indexes", pg_size_pretty(sum(i.size)) AS "Reclaimable"
 FROM pg_get_index i
 JOIN pg_get_class ct ON i.indrelid = ct.reloid
 JOIN pg_get_ns ns ON ct.relnamespace = ns.nsoid
 LEFT JOIN pg_get_toast tst ON ct.reloid = tst.toastid
 LEFT JOIN pg_get_class ptab ON tst.relid = ptab.reloid
 WHERE (tst.relid IS NULL OR ptab.reloid IS NOT NULL)
   AND i.numscans = 0 AND NOT i.indisprimary AND NOT i.indisunique;
```

Since `pg_index` is per database, a pg_gather collection covers only the database it was executed against. Please repeat the collection for every database of interest.

## From database
Following SQL statement can be used against the target database
```sql
SELECT n.nspname AS schema, relid::regclass as table, indexrelid::regclass as index, indisunique, indisprimary,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
    FROM pg_stat_user_indexes
    JOIN pg_index i USING (indexrelid)
    JOIN pg_class c ON i.indexrelid = c.oid
    JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;
```
OR more detailed (TOAST and TOAST index)
```sql
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
There could be Indexes which are not used on Primary side of a cluster, But might be used on Standbies / Replicas. So special attention should be taken for dropping such indexes
pg_gather facilitates such cluster wide analysis by collating data from all instances of a cluster. Strongly suggest waching the following explanation and demo.
[![IMAGE ALT TEXT HERE](https://img.youtube.com/vi/dKBFpVhJXD0/0.jpg)](https://youtu.be/dKBFpVhJXD0?t=180)
Following steps can be performed on the database where final analysis and report generation is done.

> **Important**
> * This works because a physical standby shares the same OIDs as its primary. Do **not** merge collections from a logical replica or from an unrelated cluster, the `indexrelid` values will not refer to the same indexes.
> * Collect from all the instances of the cluster around the same time, and collect from the **same database name** on every instance.
> * The merge **adds up** the scan counts. Merging the same collection twice will double count, so each collection file must be merged exactly once. If in doubt, start over from Step 1, which recreates the history schema from scratch.
> * `gather_schema.sql` drops and recreates the working tables on every import. That is expected, the accumulated data lives in the `history` schema until Step 6.

After each import (Step 2 and Step 5), the collection can be confirmed to be from the same cluster with:
```sql
SELECT systemid, timeline, recovery, ver FROM pg_gather;
```
`systemid` must be identical for all instances of the cluster, `recovery` will be `true` on the standbys and `false` on the primary.

### Step 1. Create history schema, if not existing
```
psql -f history_schema.sql
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
This step is to be executed only **once**, and only after every standby is merged into the history schema in Step 3.

### Step 7. Generate the pg_gather report as usual
```
psql -X -f gather_report.sql > out.html
```
The unused index list of the generated report now reflects the usage across the entire cluster. An index that still shows `0` scans is not used by the primary nor by any of the standbys.
