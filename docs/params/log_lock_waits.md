# log_lock_waits
Incidents/cases where a session need to wait more than `deadlock_timeout` must be logged.  
long waits are often causes poor performance and concurrency.  
On a long term, PostgreSQL log will have information about all the victims of this concurrency problem
