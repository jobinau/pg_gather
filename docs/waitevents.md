# PostgreSQL Wait Events
This page lists the major wait events which generally appears on pg_gather report and their implications  
Please refer to PostgreSQL documentation [here](https://www.postgresql.org/docs/current/monitoring-stats.html#WAIT-EVENT-ACTIVITY-TABLE) onwards for additional wait-events and details.

## BufferContent
Write sessions aquring lock on buffers. Happens when there is too much concurrency.
Solution: 
1. Reduce the number of connections. Multiplex large number of application connection over few database connections using transaction level pooling.
2. Reduce the size of the table (Archive / Purge) to fit in to memory
3. Partition the table.
4. Reduce the data integrity checks in the database side including foreign keys, check contraints and triggers

## BufferIO
buffer I/O. Backends will be trying to clear the Buffers. High value indicates that there is not sufficient `shared_buffers`. Generally it is expected to have assoicated `DataFileRead` also

## BufferMapping
This indicates the heavy activity in shared_buffers. Loading or removing pages from shared_buffers requires exclusive lock on the page. Each session also can put a shared lock on the page.
High BufferMapping can indicate that big working-set-of-data by each session which the system is struggling to accomodate. Excesssive indexes and bloated indexes and unpartitioned huge tables are the common reasons.

## BufferPin
An open cursor or frequent HOT updates could be holding BufferPins on Buffer pages. Buffer pinning can prevent VACUUM FREEZE operation on those pages.

## BuffileWrite
This waitevent occurs when PostgreSQL needs to write data to temporary files on disk as part of SQL execution. 
This typically happens when operations require more memory than the work_mem parameter allows, causing the system to spill data to disk.
From SQL tuning perspective,  We need to check whether large amount of data is pulled into memory for sort and join operations. Good filtering conditions are important.

For Further reading: [IO:BufFileRead and IO:BufFileWrite](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/apg-waits.iobuffile.html)

## BufFileRead
This waitevent happens when temporary files generated for SQL execution are read back to memory. Generally this happens after BuffileWrite.
PostgreSQL is Reading from buffered Temporary Files. All sorts of temporary files including the one used for sort and hashjoins, parallel execution, And files used by single sessions (refer: buffile.c) can be responsible for this. Query tuning effort is suggestable.

## ClientRead
Waiting to read/hear from the client/application. Two reasons generally cause high values for this wait-event
### 1. Network : 
The communication channel between the database and the application/client may have low bandwith or high latency. For example, there could be too many network hops. Many of the Cloud, Virtualization, Containerization, Firewall, and Routing (sometimes multi-layer routing) are found to cause high network latency. Latency has nothing to do with network bandwidth. Even a very high bandwidth connection can have high latency and affect the database performance.  
   The network related waits within the trasactions are generally accounted as "ClientRead"
### 2. Application response: 
The application side might be taking too long to respond to the database. For example, a transaction in progress might not be sending a COMMIT or ROLLBACK fast enough after sending the DML to the database server. 
This "ClientRead" wait-event combined with "idle-in-transaction" can cause contention in the server. 

## Net/Delay*
This is the Time elapsed by the session without doing anything. Multiple things can cause this.
1. High network latency.  
Not every "Network/Delay" won't always result in "ClientRead" because the network delay can affect select statements also, which are independent of the transaction block. 
2. poolers/proxies 
Connection poolers/proxies standing in between the application server and the database can cause delays. 
3. Application design 
When the Application becomes too chatty, database sessions start spending more time waiting for communication. 
4. Processing time at application side 
For example, the Application sends the first SELECT statement, then takes a delay before sending the next SELECT statement. 
5. Overloaded servers - Waiting for scheduling 
OS scheduler can give only smaller chunk of time as the host machine gets overloaded. Moreover There could be significant delay between two schedules.  This leads to a situation that connection/session waiting for execution. 

## ClientWrite
Waiting to write data to client/application, Generally caused by application retriving large amount of data at ones.

## CPU
Time spend in the computation. Divide the wait event count by 2000 to get approximate CPU core saturation by PostgreSQL.

## DataFileRead
The page required is not there in the shared buffers and waiting to fetch it. High percentage of waits can indicate poor cacheing.

## DataFilePrefetch
This wait event indicates:  
1. PostgreSQL is performing read-ahead operations to prefetch data blocks from disk into shared buffers before they're actually needed
2. The system is waiting for these asynchronous I/O operations to finish
3. It's part of PostgreSQL's optimization to reduce I/O wait times for subsequent queries
### When It Occurs
This wait typically happens during:  
1. Large sequential scans
2. Index scans that will need many blocks
3. Operations where PostgreSQL predicts future block needs
### Performance Implications
Some DataFilePrefetch waits are normal and indicate the prefetch system is working,However, Excessive waits might suggest:
1. Slow storage subsystem
2. Need to tune shared_buffers or maintenance_work_mem
3. High concurrent I/O load

## OidGen / OidGenLock
Waiting to allocate a new OID. Ideally it should be really fast.
If it takes time, It may indicates that  address space contention (32bit)
Reperted that toast chucks which uses oid, when runs out of available oids, this wait event appears.


## LockManager
The LockManager wait event indicates that a process is waiting to access the lock manager's shared memory structure. This structure holds all the locks in the database and is protected by a lightweight lock (LWLock). When multiple sessions try to acquire locks simultaneously, they must access this shared structure, and contention can arise

High LockManager waits might indicate that there are SQL statements which fast-path lock is not possible because they are using more than 16 tables or indexes. Which is common when partitioned tables are used.  If the situation is very severe, upgrading to PG 18+ would be the best solution. Because PG18 uses a variable size array in shared memory. fast-path locks for a backend scales with max_locks_per_transaction (default 64 slots)



### Causes
1. High Concurrency: A large number of concurrent sessions trying to acquire locks simultaneously can overwhelm the lock manager. This is especially problematic if the number of concurrent (Active and Idle-in-Transaction) sessions exceeds the number of CPU cores.
2. Complex Queries and Table Partitions: Queries that involve multiple partitions or indexes can acquire many locks. For example, querying a heavily partitioned table without proper partition pruning can result in numerous non-fast-path lock
3. Connection Storms: Applications or connection pool software that create additional connections when the database is slow can exacerbate the problem

### Resolution
1. Optimize Queries: Ensure that queries are optimized to minimize the number of locks required. This includes using partition pruning and avoiding unnecessary joins
2. Manage Transactions: Reduce the scope of transactions to decrease the number of locks acquired
3. Connection Pooling: Use connection pooling to limit the number of concurrent connections connections hitting the database - Connection queueing.
4. Index Management: Remove unnecessary indexes to reduce locking overhead
5. Hardware Scaling: Scale up the hardware resources, such as increasing the number of CPU cores

## SubtransBuffer
The wait event occurs when a PostgreSQL backend process (of connection) is waiting to access or modify the subtransaction buffer, typically due to contention or resource limitations. This is part of the system’s transaction management infrastructure
If some application logic is using subtransactions (nested transactions), Every session need to check the Subtransaction buffer to check the visibility of each tuple. This could considerably slowdown the performance.

### Causes:
 * Concurrency: Multiple transactions are simultaneously creating or rolling back subtransactions, leading to contention for the subtransaction buffer.
 * Heavy Use of Subtransactions: Applications that heavily use SAVEPOINT, nested transactions, or exception handling in PL/pgSQL can increase the likelihood of this wait event.
 * Buffer Management: The subtransaction buffer is managed in shared memory, and contention may arise if the buffer is undersized or if there’s significant activity.
 * System Load: High system load or I/O contention can indirectly exacerbate waits for internal buffers like pg_subtrans.

### Problem and Fix : 
If you’re seeing frequent and high SubtransBuffer waits, it’s a sign to investigate application logic and transaction patterns rather than just tuning database parameters

## SubtransSLRU
This wait event occurs when a backend process is waiting to access or modify the subtransaction SLRU buffer, typically due to contention or I/O delays.
Subtransaction metadata, including parent transaction IDs and status, is stored in the pg_subtrans SLRU, a disk-based structure that tracks subtransaction relationships.
SLRU (Simple Least Recently Used) is a caching mechanism in PostgreSQL for managing certain control data structures (like pg_subtrans, pg_clog, or pg_multixact). The SubtransSLRU specifically refers to the buffer used for subtransaction data.

### Causes
* Heavy Subtransaction Usage: Applications or functions that create many subtransactions (e.g., via nested SAVEPOINT commands or error handling in loops) can overload the subtransaction system.
* High Concurrency:Many concurrent transactions performing subtransaction operations can lead to contention on the SLRU buffer.
* I/O Bottlenecks: Slow disk I/O, especially on systems with high transaction rates, can cause delays when the SLRU buffer needs to read or write to disk.

### Problem and Fix:
From PostgreSQL 16 onwards we can findout the PID of the session causing the subtransaction and overflow using a query as follows:
```
SELECT
    pg_stat_get_backend_pid(bid) AS pid,
    s.subxact_count,
    s.subxact_overflowed,
    pg_stat_get_backend_activity(bid) AS query
FROM
    pg_stat_get_backend_idset() AS bid
JOIN LATERAL pg_stat_get_backend_subxact(bid) AS s ON TRUE
WHERE s.subxact_count > 0 OR s.subxact_overflowed;
```
This wait event is closely related to `SubtransBuffer` wait event, which refers to waits on the in-memory subtransaction buffer in shared memory. In contrast, `SubtransSLRU` involves the disk-based SLRU structure (`pg_subtrans`) used for persistent subtransaction data.


## transactionid
Session waiting for other session to complete the transaction. (Session is blocked). The transactionid wait event in PostgreSQL occurs when a backend process is blocked while waiting for a specific transaction to complete. This is one of the more serious wait events that can significantly impact database performance.
For example, Updating the same rows of a table from multiple sessions can lead to this situation.
This waitevent indicates that:
1. One transaction is waiting for another transaction to finish (commit or abort)
2. There is direct transaction ID dependency between sessions
3. This typically involves row-level locking scenarios where MVCC (Multi-Version Concurrency Control) can't resolve the conflict

### Common Causes
1. Lock Contention: When Transaction A holds locks that Transaction B needs  
    Example: Long-running UPDATE blocking another UPDATE/DELETE on same rows
2. Foreign Key Operations: When checking referential integrity during updates/deletes
3. Prepared Transactions: Waiting for a prepared transaction (2PC) to commit/rollback
4. Serializable Isolation Level: In SERIALIZABLE isolation, waiting for a potentially conflicting transaction to complete
5. VACUUM Operations: When VACUUM is blocked by long-running transactions

#### Performance Implications
1. More severe than tuple waits as it involves entire transactions rather than individual rows
2. Can lead to transaction chains where multiple sessions wait in sequence

Often indicates:
1. Long-running transactions holding locks
2. Application logic issues (transactions staying open too long)
3. Insufficient vacuuming leading to transaction ID wraparound prevention


## tuple
This wait event indicates that a session is:
1. Waiting to read or modify a specific row in a table
2. Blocked by another transaction that has locked that row
3. Typically involved in row-level locking scenarios

### Common Scenarios
The "tuple" wait event appears in these situations:
1. Row Lock Contention: When one transaction has locked a row (with SELECT FOR UPDATE, UPDATE, DELETE, etc.) and another transaction tries to access the same row.
2. Foreign Key Checks: When checking referential integrity during updates/deletes.
3. Serializable Isolation Level: In serializable transactions detecting potential serialization anomalies.

### Performance Implications
Frequent "tuple" waits indicate row-level lock contention in your application. This is different from table-level locks (which show as "relation" waits). While some tuple waits are normal, excessive waits suggest:
1. Long-running transactions holding locks
2. Hot rows that many transactions try to modify
3. Inefficient application logic causing unnecessary lock retention

### Suggessions
1. Shorten transaction duration (especially those modifying data)
2. Re-evaluate indexes and use appropriate indexes to reduce lock scope. Be very careful about this.
3. Review isolation levels - consider READ COMMITTED instead of SERIALIZABLE
4. Implement application-level retry logic for contended rows
5. Use SELECT FOR UPDATE SKIP LOCKED if appropriate for your use case

## WALInsertLock
Consider increasing the `wal_buffers`. Upto 64MB max.

## WalReceiverMain
Receiver is waiting for new data to arrive

## WalReceiverWaitStart
Walreceiver is waiting for startup process to set the lsn and timeline

## WalSenderMain
WAL Sender process is just waiting in the main loop. Ignorable

## WalSenderWriteData  
Generally observed with Logical replication as the cause of replication lag.
This Waitevent indicates that the WAL sender process is waiting for sending the data because the socket is not ready. In other words, walsender has pending data in the output buffer and are waiting to write data to a client (subscriber)
This Could be due to high network latency or poor bandwidth.

## WalSenderWaitForWAL
WAL Sender process is waiting for the WAL to be flushed. The WAL sender sleeps for sometime and wakes up if scoket is available.
This wait-event is seen in logical replication.

## WalWriteLock
This is a lock to be held by a PostgreSQL process, if it need to write WAL buffers to disk (XLogWrite or XLogFlush).  
Big value indicates large number of process trying to do heavy writing to WAL. 
Suggessions:
Have a high bandwith, low latency storage for pg_wal directory
Avoid `wal_level = logical` unless it is essentail.
Improve the connection pooling there by reduce the connections.
Automatic vacuum after Bulk data loading can cause this. So add a supplimentory `VACUUM (FREEZE,ANALYZE) TBL` also on the table bulk data loading is performed.

## ReorderBufferWrite
`logical_decoding_work_mem` is filled and writing the buffer's contents to storage.
This can result in lag in logical replication.

### Causes
* **Very Large/Bulk Transactions:** single transaction modifying large number of rows.
 Reorder buffer won't be able to hold large number of transactions until they commit due to it size.
* **Long-Running Transactions:** Buffer need to hold the details until the transaction commits, even though other transactions commits in between.
* **High/Spike concurrent changes** if rate of change is higher than logical decoding can process, it can lead to spill file generation.
* **Insufficient `logical_decoding_work_mem`**

### Additional References
1. [Blog by Robins](https://www.thatguyfromdelhi.com/2025/05/taming-reorderbufferwrite-boost-logical.html)
