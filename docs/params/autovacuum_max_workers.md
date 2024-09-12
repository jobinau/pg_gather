# autovacuum_max_workers
This parameter rarely requires a value bigger than 3 (the default).  
As the number of autovacuum workers increases, each worker will get a smaller share of `autovacuum_vacuum_cost_limit`. Effectively, the autovacuum workers will start running slower.  
Please consider changing this parameter setting only with an expert's analysis.  
Consider a bigger value for `autovacuum_max_workers` in those cases where the schema is extremely big OR There are too many active databases in the instance, where we might see autovacuum workers continuously running back to back on different tables, even after all the autovacuum tuning efforts.

## Other negative effect of bigger value of autovacuum_max_workers
1. As the number of workers increases, each worker runs slower and takes more time to complete. This situation leads to autovacuum workers referring to old snapshots (old Xmin reference).   Autovacuum workers are like regular PostgreSQL sessions, which are constraint by the visibility rules as per the MVCC.  
 Effectively, a long-running autovacuum worker has the same effect as any long-running session. It can cause bloat.  
 Autovacuum workers themself causing bloat would be an anti-pattern but frequently reported case.
2. Each autovacuum worker uses a snapshot (xmin reference) to work on tables. So autovacuum woker has  visiblity only to those records which are existing as when the autovacuum worker started. The Autovauum worker cann't see the dead tuples created later. This means an autovacuum worker becomes ineffective in cleaning up dead tuples if it takes longer duration.
3. Each autovacuum woker can allocate `maintenance_work_mem` amount of memory. This can result in high memory presure on the server and cause poor performance or even outage.

## Supplimentory vacuum jobs
Scheduling supplimentory autovacuum jobs is highy recommended on highly active database systems due to many of its advantages and limitations of built-in autovacuum algorithm
The built-in Autovacuum considers the Dead tuples (Number and Ratio) as the basis of scheduling the autovacuum workers on a table. Other criterias like age of table is ignored by autovacuum.
Another major disadvantage of autovacuum is that, there is high chance of autovacuum workers starting during the peak times because of the DDL changes. All these limitations can be addressed using a scheduled vacuum job running in the off peak hours.
As an added benefit, It reduces the chance that the same table becoming candidate for autovacuum again during the peak hours.
Sample SQL script is available here : https://github.com/jobinau/pgscripts/blob/main/vacuumjob.sql . This script is widely used in many enviroments and found to address the problems discussed above.
For example, This script can be scheduled as follows
```
20 11 * * * /full/path/to/psql -X -f /path/to/vacuumjob.sql > /tmp/vacuumjob.out 2>&1
```


