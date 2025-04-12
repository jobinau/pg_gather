# TransactionID Snapshot Horizon.
Long-running transactions are problematic for any ACID-compliant database system because the system needs to track the snapshot of data to which every currently running transaction refers. PostgreSQL is no different and is expected to have many types of troubles if there are long-running transactions or statements.

## How to check

Under the main Head information presented at the top of the pg_gather report, the "Oldest xid ref" is the oldest/earliest transaction ID (txid) that is still active. This is the oldest xid horizon which PostgreSQL is currently tracking. All earlier transactions than this will either be committed and visible or rolled back and dead.

Again under "Sessions" details, Details like each sessions, the statment they are running and the xid age of the snapshot each of those sessions are refering, duration of the statement etc will be displayed.

## Dangers of long-running transactions.
1. Uncommitted transactions can cause contention in the system, resulting in overall slow performance.
2. They commonly cause concurrency issues, system blocking, sometimes hanging sessions, and even database outages.
3. Vacuum/autovacuum won't be able to clean up dead tuples generated after the oldest xmin reference, which results ub poor query performance and reduces the chance of Index-only scans.
5. System may reach high xid age and possibliy wraparound stages if the vacuum/autovacuum is not able to clean up old tuples. Systems with long running sessions.  
   Wraparound prevention autovacuum (aggressive mode autovacuum) is frequently reported in systems which has long-running transactions
6. Tables and indexes are more prone to bloating as the vacuum becomes inefficient.