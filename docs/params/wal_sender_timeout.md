# wal_sender_timeout

This parameter specifies the maximum time (in milliseconds) that a replication connection can remain inactive before the server terminates it. This helps the primary detect when a standby is disconnected due to crash or network failure.

- **Default**: 60000 ms (60 seconds)
- **Value 0**: Disables timeout (connection waits indefinitely)
- **Impact**: Terminates only the WAL sender process, not the replication slot
- **Shutdown consideration**: There could be cascading effect as explained below.

## Why it is important
There could be cascading effect for this parameter.For example, The checkpointer will wait for all WAL senders to finish. However, a graceful shutdown will wait for checkpointer to finish first. So if there is no timeout happening, it could lead to shutdown taking too long. 