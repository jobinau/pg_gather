# min_wal_size
This parameter determines how many WAL files need to be retained for recycling rather than removed.
PostgreSQL will try to avoid the usage of the `pg_wal` directory falling below this limit by preserving old WAL segment files.
WAL file recycling reduces the overhead and fragmentation at the filesystem level.
The biggest advantage of a sufficiently big `min_wal_size` is that it can ensure that there is sufficient space reserved for `pg_wal`.

## Recommendation
Generally, we recommend half the size of the `max_wal_size`.