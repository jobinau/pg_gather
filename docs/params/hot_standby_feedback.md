# hot_standby_feedback
This parameter MUST be `on` if the standby is used for executing SQL statements. Else, query cancellation due to conflict should be expected.

## Suggestion
It is highly recommended to keep this parameter `on` if the standby is used for SQL statements.  
Again, it is recommended to keep the same value on both Primary and Standby.  
Along with the parameters `max_standby_archive_delay` and `max_standby_streaming_delay`, this parameter can allow a long-running SQL statement on the standby to wait before applying changes and acknowledging the replication position to the primary.  
This can prevent the primary from cleaning up tuple versions which are required on the standby side.

## Caution
If the values of `max_standby_archive_delay` and `max_standby_streaming_delay` are high, the primary could end up holding old tuple versions, preventing autovacuum / vacuum from cleaning them up. This may potentially result in bloat on the primary.