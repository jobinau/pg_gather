# Partitioning in PostgreSQL

Partitioning of tables requires archtectural planning and maintenance planning. Its a serious architectural and design decision, Not a reactive measure.
One should make sure the following
1. Ensure that most of the SQL statements are running with proper partition pruning. This often requires the partition key to be appearing as the filtering condition (WHERE clause) of the SQL. Without proper parition pruning, the performance degradation and failures are often reported.
2. Periodicaly evaluate to archive older partitions from the OLTP systems to preferably Warehouse systems. If older partitions which are not used any more can be moved to another table if moving to Warehouse system is not an option.
 Please consider the PostgreSQL feature DETACH and ATTACH for such partition maintenance.

## Implication on max_locks_per_transaction
PostgreSQL's internal shared lock table is prepared considering value of the parameter `max_locks_per_transaction`
As the [documentation](https://www.postgresql.org/docs/current/runtime-config-locks.html#GUC-MAX-LOCKS-PER-TRANSACTION) says:  
*The shared lock table has space for max_locks_per_transaction objects (e.g., tables) per server process or prepared transaction*  
This means :  
```
size of the shared lock table  = max_locks_per_transaction × (max_connections + max_prepared_transactions).
```
This shared lock table is shared with all transactions. Not for individual transactions. This is mentioned in the doc:  
*This parameter limits the **average number** of object locks used by each transaction; **individual transactions can lock more objects as long as the locks of all transactions fit in the lock table**.*

In PostgreSQL, a partitioned table (the parent) and its partitions (the children) are treated as distinct relations (individual entries in the `pg_class` system catalog). When a query targets a partitioned table, PostgreSQL must acquire an `AccessShareLock` (for SELECT) or `RowExclusiveLock` (for DML) on the parent table, and subsequently on every individual partition it expects to read or write to.
Furthermore, indexes are also separate relations. If an execution plan requires reading an index, a lock is taken on that index as well.

The default value of `64` is generally sufficient on the assumption that there won't be many SQL concurrently running which tries to aquire lock on many partitions. But this assumption goes wrong if the partition pruning is not happening properly and there are high concurrency.

Here is a simple math: Assume that SQL query a parent table with 100 partitions and each partition has 2 indexes.
* 1 lock for the parant table
* 100 locks for the partitions
* 200 locks for the indexes
* Total 301 locks are quired for that query.

Since the lock table size is fixed in shared memory at instance startup, PostgreSQL cannot dynamically allocate more memory for locks on the fly. When the global pool fills up, it throws error like
```
ERROR: OutOfMemory - out of shared memory
HINT: You might need to increase max_locks_per_transaction. 
```
So we should be adjusting the value of parameter considering all these factors. 

### Importance of Plan time pruning
If the planner can prune partitions (plan time pruning) it will only acquire locks on the parent and the specific partition(s) matching the criteria, However If the planner cannot determine the exact partitions at planning time (e.g., joining against another table, or using volatile functions), it must lock all partitions just in case, even if executor-time pruning later discards them.

### Impact of query parallelism
If the planner decides to use parallel execution, The Leader spawns additional parallel wokers. Even though they are working on the exact same query, each parallel worker is a distinct operating system process with its own internal state (PGPROC). To safely execute its portion of the plan, every worker must reconstruct the execution tree and open the relations (tables, partitions, and indexes) it has been assigned. When a worker opens a partition, it must request an `AccessShareLock` on it. In summary, each parallel worker acts as an independent backend process and will acquire its own separate locks on the tables and partitions it interacts with, subsequently this will result in multiplying effect on the lock consumption.

### Fast-path lock
PostgreSQL does have an optimization called "fast-path" locking, where a backend can track a small number of weak locks locally without touching the shared memory pool. However, this limit is hardcoded to 16 locks per backend. So we must be careful if the table is having many partitions to be considered for a query execution.

## Query Planning Time
Planning time grows roughly linearly with the number of partitions (or remaining partitions after pruning). The panner need to consider bigger volume of metadata 

## Memory Consumption
Each partition touched by a query requires its metadata (from pg_class, pg_attribute, etc.) to be loaded into the session's local memory. With many partitions and many concurrent sessions, overall server memory usage can grow significantly over time

## Lock Manager concurrency
high partition counts can cause heavy contention on the Lock Manager (LWLock: lock_manager or similar wait events).

## Maintenance and Operational Overhead
Partitions are like regular tables internally, As the schema size increases, meta data also increases, often results in bloated catalog. Beware of overall catalog size, a big catalog have cluster-wide performance impact.
As the database objects increases,s the vacuum overhead, statistics maintaintenance, Index maintenance etc also increases. So partitioning is not a substituion for implimentation of data retention policies (Archival and Purging), but it is complimentory - Partitioning table helps the implimentation of data retention policy.

## Query execution overhead.
The Append node in the query plan need to concatenates results from many sub-plans. This can lead to degraded perforance if the number of partitions participating in high.
