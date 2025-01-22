# parallel_leader_participation

By default, the leader of the parallel execution participates in the execution of plan nodes under "Gather" by collecting data from underlying tables/partitions, just like any parallel worker. Meanwhile, the leader process needs to perform additional work, such as collecting data from each parallel worker and " gathering" it in a single place.  
However, for an OLAP / DCS system, it would be better to have the leader process dedicated only to gathering the data from workers. This would be helpful if the following conditions are met

* The host machine has a sufficiently high number of CPUs
* There is not much concurrency, but few bulk SQLs are executed
* Tables participating in SQL are partitioned.
* The data is too big to fit into memory.

## Reference :
https://kmoppel.github.io/2025-01-22-dont-forget-about-postgres-parallel-leader-participation/
