# autovacuum_max_workers
Very rarely this parameter requires a value bigger than 3 (the default).  
As the number of autovacuum wokers increases,  each worker will get a smaller share of `autovacuum_vacuum_cost_limit`. effectively the autovcuum workers starts running slower.  
Please avoid changing this parameter without analysis by an expert.  
Consider a bigger value for `autovacuum_vacuum_cost_limit` only on those cases where schema is extreamly big or there are too many active databases in the instance, where we might see autovacuum workers continuosly running back to back on different tables, even after all the autovacuum tuning efforts.

## Other negative effect of bigger value of autovacuum_max_workers
1. As the workers increases, each worker runs slower and takes more time to complete. This leads to autovacuum workers refereing to snapshot (old xmin reference).  
   Autovacuum workers are like regular PostgreSQL sessions, constraint by the visibility rules as per the MVCC.  
   Effectively a long running autovacuum worker has same effect as any long running session. It can cause bloat.  
   Autovacuum wokers themself causing bloat would be an anti-pattern, but frequently reported case.
2. Autovacuum woker uses a snaphsot (xmin reference) to work on tables. So autovacuum woker has only visiblity to those records which are created at the begining, when the autovacuum worker started. The Autovauum worker cann't see the dead tuples created later. This means an autovacuum worker becomes ineffective in cleaning up old records if it takes longer duration.
3. Each autovacuum woker can allocate `maintenance_work_mem` amount of memory. This can result in high memory presure on the server and cause poor performance or even outage.

## Supplimentory jobs
Scheduling supplimentory autovacuum jobs is highy recommended on highly active database systems due to many of its advantages and limitations of built-in autovacuum algorithm
