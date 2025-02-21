# min_wal_size
This parameter specifies how much of the WAL files need to be retained for recycling.
WAL file recycling reduces the overhead and fragmentation at the filesystem level.

## Recommendation
Generally, we recommend half the size of the `max_wal_size`.