# checkpoint_timeout
PostgreSQL performs a checkpoint every 5 minutes, as per the default settings. Checkpointing every 5 minutes is a very high frequency for a production system. 
In practical world, if there is a database outage, the HA will be failover to standby. So, the time it takes for a crash recovery becomes meaningless.

PostgreSQL must flush out all dirty buffers to the disk to complete the checkpoint. if there is a good chance of the same pages getting modified again, this effort will be meaningless  
The biggest disadvantage of frequent checkpoints is the full-page write of every page getting modified is required after the checkpoint. In a system with a large amount of memory and many pages being modified, the impact will be huge. Often, that causes a huge spike in IO and a drop in database throughput.  


## Recommendation
Overall, checkpointing is a heavy and resource-intensive activity in the system. Reduce its frequency to get better performance and stability. 
Considering all the factors and real world feedback, we recommend checkpointing in every half an hour to one hour duration.
```
checkpoint_timeout = 1800
```
The value is specified in seconds.
