
# TransactionID Snapshot Horizon.

PostgreSQL  need to track Old transaction IDs due to MVCC (ACID compliance). Its perfectly OK to see the transaction ID horizons going to hundreds of xids. However if it increases to large number it will have serious concequnces. For example, Long-running transactions are problematic for any ACID-compliant database system because the system needs to track the snapshot of data to which every currently running transaction refers.

## Common causes
PostgreSQL may keep refering to very old xmin reference to verious underlying reasons. Major ones are
1. Long-Running Active Transactions (Primary Node)  
   Any traditional application query or bulk job that remains active for a prolonged period pins the xmin horizon to its own transaction start time. Because PostgreSQL uses Multi-Version Concurrency Control (MVCC), an active transaction must be able to see a consistent snapshot of the data from the exact moment it started. As long as it lives, VACUUM cannot sweep away any tuples modified or deleted after that transaction's start XID.
2. "Idle in Transaction" Backends  
   A close relative to the first reason, but often more insidious because it isn't actively consuming CPU. An application opens a transaction block (BEGIN), executes a fast query, and then forgets to issue a COMMIT or ROLLBACK while keeping the connection alive.
3. Abandoned or Stale Replication Slots (Physical & Logical)  
   Replication slots are explicitly designed to protect data from being vacuumed or dropped before a replica can consume it. If a standby node crashes, gets disconnected, or is permanently decommissioned without dropping its slot, the primary node continues safeguarding that old state indefinitely.
   * **Physical Slots:** If `hot_standby_feedback = on` is enabled on the standby, it sends its oldest active transaction snapshot back to the primary. If that standby is lagging or hangs, it stalls the primary’s data xmin.
   * **Logical Slots:** Stalls system catalogs. If logical replication stops (e.g., due to an unapplied DDL schema mismatch on the subscriber), the catalog_xmin stops moving. This blocks VACUUM from cleaning up dead tuples inside system catalog tables.
4. Long-Running Transactions on Standby Nodes (via Hot Standby Feedback)  
   When you use physical streaming replication and want to completely eliminate read-conflict errors (where a VACUUM on the primary destroys a tuple a reader on the standby is currently querying), you turn on `hot_standby_feedback = on`.
   This config causes the standby node to constantly report its own xmin horizon back to the primary. Consequently, if a user fires up a massive analytical query or leaves an idle in transaction session open on the replica, that replica forces the primary to hold the xmin horizon.  
5. Abandoned or Orphaned Prepared Transactions (2PC)  
   When applications use Two-Phase Commit (PREPARE TRANSACTION), the transaction state is detached from the active database session and written directly to disk so it can survive a server crash. If an application issues a PREPARE but the coordinator crashes before sending the final COMMIT PREPARED or ROLLBACK PREPARED, that transaction remains permanently frozen in an uncommitted state. It will sit there indefinitely, pinning the xmin horizon and blocking autovacuum cluster-wide until it is manually handled.

## How to check

Under the main Head information presented at the top of the pg_gather report, the "Oldest xid ref" is the oldest/earliest transaction ID (txid) that is still active. This is the oldest xid horizon which PostgreSQL is currently tracking. This gives the high level view.

Details of old xid references will be available in the corresponding sections in the report. For example, under "Sessions" details, Details like each sessions, the statment they are running and the xid age of the snapshot each of those sessions are refering, duration of the statement etc will be displayed. Replication related xid age information is available under replication section in the report.


## Dangers of high xmin horizon.
1. High xmin horizon (old xmin reference) cause contention in the system, resulting in overall slow performance.
2. They commonly cause concurrency issues, blocking, sometimes hanging sessions, and even database outages.
3. Vacuum/autovacuum won't be able to clean up dead tuples generated after the oldest xmin reference, results in poor query performance and reduces the chance of Index-only scans.
4. System may reach high xid age and possibliy wraparound stages if the vacuum/autovacuum is not able to clean up old tuples. Systems with long running sessions.  
   Wraparound prevention autovacuum (aggressive mode autovacuum) is frequently reported in systems which has long-running transactions
5. Tables and indexes are more prone to bloating as the vacuum becomes inefficient.