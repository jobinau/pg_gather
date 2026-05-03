# synchronous_standby_names
Parameter to specify the synchronous standbys.
Each Session participating in Synchronous commit will wait for an acknowledgement from standby side.

## Consequences
1. Poor performance. Generally network will be the biggest performance bottleneck. especially for high velocity OLTP workload.
2. Poor thoughput and concurrency. Since each sessions takes much longer
3. Connection explosion.
4. Stalls. 

## Additional References
following are recommended for detailed understanding.  
1. [Sync Replication is Not Actually Sync Replication](https://ardentperf.com/2025/10/27/explaining-ipcsyncrep-postgres-sync-replication-is-not-actually-sync-replication/)
2. 