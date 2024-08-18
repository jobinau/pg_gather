# random_page_cost - Cost of Randomly accessing a memory block
It is costly to access random pages in a magnetic disk because of the seek time ( track-to-track seek) and additional rotational latency to reach the track.
Random accesss can be 10s of magnitude costly than sequently reading data from the same track. PostgreSQL by default considers that random access is 4x time costly than sequential access (value of random_page_cost), which is a generally accepted good balance.
Hoever nowadays most of the environments has SSDs or NVMes  or Storage which behave like SSDs where the random access is as cheap as sequential access.

# Implications on Database performnace
The Index scans are generally random access (B-Tree). If the random access is costly, the PostgreSQL planner (cost based planner) will take plans which could reduce the use of Indexes. Effectively we might see less use of indexes.

# Suggessions
1. If The storage is using local SSD/NVMe, The `random_page_cost` can be almost same as `seq_page_cost`. A value between 1 to 1.2 is generally suggested
2. If the storage is SAN drive with memory caches, A value around 1.5 would be good.
3. if the storage is a Magnetic disk, The default value of 4 would be sufficient.
