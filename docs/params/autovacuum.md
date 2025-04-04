# autovacuum
Autovacuum is essential for any healthy PostgreSQL Instance. Please don't disable it unless there are unavoidable reasons for doing so.  
Moreover, disabling the autovacuum needs to be done only temporarily when it is essential.

## Why autovacuum is essential
1. Clean up dead tuples to create space for new tuples.  
If the cleanup of dead tuples is not happening continuously, new tuples will have to allocate more blocks. This is generally called Bloating. Table bloats result in Index bloat also. This could result in unexpected plan changes and degradation of SQL performance.
2. Freeze operation
 Freezing of sufficiently old tuples is important for perventing the system running into wraparound conditons. Frozen tuples are important for the SQL performance because it is visible for all SQLs. no need to do any further checks.
3. Helps to avoid aggressive vacuums  
 Unless the Freeze operation is done in time and the age reaches `autovacuum_freeze_max_age`, Aggressive mode vacuums might start in the system, which could potentially block other concurrent sessions and generally cause a much higher load on the system.
4. Index maintenance.  
 Autovacuum is responsible for Pending List Maintenance of GIN indexes. Autovacuum triggers the periodic merging of this pending list into the main index structure, which is controlled by the `gin_pending_list_limit` configuration.
Moreover, autovacuum reduces the chance of index bloat for other types of indexes.
5. Updating Statistics  
 Autovacuum is reponsible for keeping the Table and index statistics up-to-date. These statistics are used by the query planner, which helps the optimizer make better decisions about query execution plans
6. Updating the Visibility Map
 autovacuum maintains the visibility map, which tracks which blocks contain only tuples visible to all transactions. This intern helps future vacuum operations and speeds up by identifying blocks which don't have to be scanned. This visibility map information is very important for index-only scans, which improve the SQL performance.

 ## Summary
 Autovacuum is an essential background worker which does many housekeeping jobs. Without which many troubles are expected down the line. Avoid disabling it.
 Additional supplementary vacuum jobs that run on off-peak times are also recommended. This could help reduce autovacuum activities at peak times.