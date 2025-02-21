# max_wal_size
This is the maximum size the `pg_wal` directory is allowed to grow. This is soft limit given to PostgreSQL so that PostgreSQL can plan for checkpointing sufficiently early to avoid the space consumption going above this limit.
The default is 1GB., which is too small for any production system.

## Recommendation
Ideally there should be sufficinet space for holding atleast 1 hour worth WAL files. So Wal generation need to be monitored before deciding on the value fo `max_wal_size`.  
Smaller sizes may trigger forced checkpoints much earlier.
Poorly tuned systems may experience back-to-back checkpointing and associated instability. So consider giving bigger size for `max_wal_size` to handle occational spikes in WAL generation.


