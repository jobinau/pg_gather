# Extensions 
PostgreSQL extensions can add additional functionality to PostgreSQL  
However, they may come with a considerable Performance overhead; Extensions are not free of cost.  
The overhead of extensions could vary according to the workload.

## Sample Benchmark results.
Even the widely used extensions like `pg_stat_statements` are reported to cause severe performance degradation on specific workloads.  
[How pg_stat_statements Causes High-concurrency Performance Issues](https://www.alibabacloud.com/blog/postgresql-v12-how-pg-stat-statements-causes-high-concurrency-performance-issues_597790)  
[pg_stat_statement can cause significant degradation for fast SELECT workload](https://www.linkedin.com/posts/samokhvalov_postgresql-activity-7211431755403210752-bUNx/)  


## Stability/Availability issues
Many incidents were reported about Bugs and other run-time problems of extensions causing database outages. If an extension crashes, the session also crashes. PostgreSQL has no option than restarting. 

## Security issues
Extensions has access to data and can cause vulnarabilities and security issues.
Extensions which links to external libraries or uses network are considered more risky.

## Summary.
Be aware of the overhead, stability & availability issues, and security issues the extensions can cause.  
Use extensions wherever and whenever it is unavoidable for business purpose.
DROP them whenever not needed.

