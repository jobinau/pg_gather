# **Partitioning in PostgreSQL \- Things to remember**

Partitioning of tables requires architectural planning and maintenance planning. It's a serious architectural and design decision, not a reactive measure. The partitioned schema needs to be well tested with specific number and size of partitions.  Overdoing or wrongly partitioning can result in more damage than anything useful.

1. Ensure that most of the SQL statements are running with proper partition pruning. This often requires the partition key to be appearing as the filtering condition (WHERE clause) of the SQL. Without proper partition pruning, the performance degradation and failures are often reported.  
2. Periodically evaluate to archive older partitions from the OLTP systems to preferably Warehouse systems. If older partitions which are not used any more can be moved to another table if moving to the Warehouse system is not an option. Please consider the PostgreSQL feature DETACH and ATTACH for such partition maintenance. Its important to keep the number of partitions constant throughout the lifespan of a database.

## **Implication on `max_locks_per_transaction`**

PostgreSQL’s internal shared lock table is prepared considering value of the parameter max\_locks\_per\_transaction As the [documentation](https://www.postgresql.org/docs/current/runtime-config-locks.html#GUC-MAX-LOCKS-PER-TRANSACTION) says:  
 *The shared lock table has space for max\_locks\_per\_transaction objects (e.g., tables) per server process or prepared transaction*  
 This means :

```
size of the shared lock table  = max_locks_per_transaction × (max_connections + max_prepared_transactions).
```

This shared lock table is shared with all transactions. Not for individual transactions. This is mentioned in the doc:  
 *This parameter limits the **average number** of object locks used by each transaction; **individual transactions can lock more objects as long as the locks of all transactions fit in the lock table**.*

In PostgreSQL, a partitioned table (the parent) and its partitions (the children) are treated as distinct relations (individual entries in the pg\_class system catalog). When a query targets a partitioned table, PostgreSQL must acquire an AccessShareLock (for SELECT) or RowExclusiveLock (for DML) on the parent table, and subsequently on every individual partition it expects to read or write to. Furthermore, indexes are also separate relations. If an execution plan requires reading an index, a lock is taken on that index as well.

The default value of 64 is generally sufficient on the assumption that there won’t be many SQL concurrently running which tries to acquire locks on many partitions. But this assumption goes wrong if the partition pruning is not happening properly and there are high concurrency.

Here is a simple math: Assume that SQL query a parent table with 100 partitions and each partition has 2 indexes.

* 1 lock for the parent table  
* 100 locks for the partitions  
* 200 locks for the indexes  
* A total of 301 locks are required for that query.

Since the lock table size is fixed in shared memory at instance startup, PostgreSQL cannot dynamically allocate more memory for locks on the fly. When the global pool fills up, it throws error like

```
ERROR: OutOfMemory - out of shared memory
HINT: You might need to increase max_locks_per_transaction. 
```

So we should be adjusting the value of parameter considering all these factors.

### **Importance of Plan time pruning**

If the planner can prune partitions (plan time pruning) it will only acquire locks on the parent and the specific partition(s) matching the criteria, However If the planner cannot determine the exact partitions at planning time (e.g., joining against another table, or using volatile functions), it must lock all partitions just in case, even if executor-time pruning later discards them.

### **Impact of query parallelism**

If the planner decides to use parallel execution, The Leader spawns additional parallel workers. Even though they are working on the exact same query, each parallel worker is a distinct operating system process with its own internal state (PGPROC). To safely execute its portion of the plan, every worker must reconstruct the execution tree and open the relations (tables, partitions, and indexes) it has been assigned. When a worker opens a partition, it must request an AccessShareLock on it. In summary, each parallel worker acts as an independent backend process and will acquire its own separate locks on the tables and partitions it interacts with, subsequently this will result in a multiplying effect on the lock consumption.

Its a good idea to reduce the parallelism if query involves large number of partitions, using `max_parallel_workers_per_gather`, `parallel_setup_cost`, or like `ALTER TABLE t1 SET (parallel_workers = 1)`;

### **Impact of Joins**

When partitioned tables are joined with other tables, amplification of lock consumption need to be expected, because both tables and partitions need to be locked. But the actual lock depends on the phase of the query execution

1. Planner locks - lock everything in the Query tree   
2. Executor locks - lock only what's in the PlannedStmt (what's actually used). If the join conditions allow the executor to figure out which partitions are needed dynamically on the fly (e.g., looking up a row in the partitioned table based on a value from the driving table), PostgreSQL tries to defer locking those partitions until they are actually accessed. 

The “Partition Wise Join” feature of PostgreSQL may help to reduce the locks required. For example, a parallel hash join might require every worker to scan the entirety of the table to build a shared hash table, meaning every worker locks every partition of the table. But a Partition Wise Join with parallel execution can create separate join nodes for each partition pair (A1+B1, A2+B2). The worker needs to acquire locks only on the partition pair.

### **Fast-path lock**

PostgreSQL does have an optimization called “fast-path” locking, where a backend can track a small number of weak locks locally using an array within the process without touching the shared memory pool. However, this limit is hardcoded to 16 locks per backend (Prior to PG18). We will get the performance benefit of fast-path locking if the number of partitions/objects involved are less than 16\. It is common to see many of the Partitioned tables exceed this limit and resulting in performance degradation.

Here is an excellent presentation on improvements in Fast-Path lock and memory allocator configuration (MALLOC_TOP_PAD_):  
[Fast-path locking improvements in PG18 (PGConf.dev 2025)](https://youtu.be/iCmUhS9XYI0)

PostgreSQL commit : [https://git.postgresql.org/gitweb/?p=postgresql.git;a=commitdiff;h=c4d5cb71d](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commitdiff;h=c4d5cb71d)

This improvement in PostgreSQL brings two benefits. The effective default value of fast-path locks are no longer hardcoded. Instead derived from the max\_locks\_per\_transaction. So it become user adjustable and since the default value of max\_locks\_per\_transaction is 64, the default behaviour is much better. So if the database has lot of partitions, upgrading to PostgreSQL 18 is beneficial.

## **Other impacts of over partitioning.**

### Query Planning Time

Planning time grows roughly linearly with the number of partitions (or remaining partitions after pruning). The panner need to consider bigger volume of metadata

### Memory Consumption

Each partition touched by a query requires its metadata (from pg\_class, pg\_attribute, etc.) to be loaded into the session’s local memory. With many partitions and many concurrent sessions, overall server memory usage can grow significantly over time

### Lock Manager concurrency

high partition counts can cause heavy contention on the Lock Manager (LWLock: lock\_manager or similar wait events).

### Maintenance and Operational Overhead

Partitions are like regular tables internally, As the schema size increases, meta data also increases, often results in bloated catalog. Beware of overall catalog size, a big catalog have cluster-wide performance impact. As the database objects increases,s the vacuum overhead, statistics maintenance, Index maintenance etc also increases. So partitioning is not a substitution for implementation of data retention policies (Archival and Purging), but it is complimentary \- Partitioning table helps the implementation of data retention policy.

### Query execution overhead.

The Append node in the query plan needs to concatenate results from many sub-plans. This can lead to degraded performance if the number of partitions participating is high.

