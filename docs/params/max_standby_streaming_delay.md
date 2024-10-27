# max_standby_streaming_delay
WAL applied on standby can be delayed by the amount of time specified in this parameter. The default is 30 seconds (30000 ms). PostgreSQL will hold the WAL apply if there is a conflicting statement already running on the standby side. This parameter comes into effect when WAL is **fetched though streaming replication from primary**. 

# Suggessions:
One should  increase this parameter if there are long-running statements on the standby side and frequent problems of statement cancellation due to conflicts. However, that comes with a cost of replication delay, if there is a conflict. These two requirements put opposite considerations into this parameter.
One common strategy is to divide the sessions connecting to the standby side into multiple standby nodes, so that statements with longer duration are redirected to one standby and Statements that need to see near real-time data are redirected to another standby. The standby where long-running statements can have a bigger value for this parameter.
Unless such strategies are used, the same value for this parameter and [max_standby_archive_delay](./max_standby_archive_delay.md) is a common practice.
It is not recommended that this parameter have too big a value. Instead, statements that are taking too long to complete should be investigated for tuning.