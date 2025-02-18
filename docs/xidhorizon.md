# TransactionID Snapshot Horizon.
Long-running transactions are problematic for any ACID-compliant database system. The system needs to track the snapshot of every currently running transaction, and PostgreSQL is no different.

Under the main header information presented in pg_gather report, The "Oldest xid ref" is the oldest/earliest transaction ID (txid) still active. This is the oldest xid horizon which PostgreSQL is currently tracking. All earlier transactions than this will either be committed and visible or rolled back and dead.

## Dangers of long-running transactions.
1. Uncommitted transactions can cause contention in the system, resulting in overall slow performance.
2. They commonly cause concurrency issues, system blocking, sometimes hanging sessions, and even database outages.
3. Vacuum cannot clean up dead tuples generated after the oldest xmin reference, resulting in poor query performance and reducing the chance of Index-only scans.
4. Tables and indexes are more prone to bloating as the vacuum becomes inefficient.