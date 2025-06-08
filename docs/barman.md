# Barman / rsync
Barman is a Python wrapper script on the top of [rsync](https://en.wikipedia.org/wiki/Rsync) and [pg_basebackup](https://www.postgresql.org/docs/current/app-pgbasebackup.html).
The acutal backup is perfomed by either of the underlying tools. So all limitations of underlying tools will be applicable for Barman.

# Known Limitations of rsync
1. **CRITICAL : Unreliable Static File List**  
  `rsync` builds a list of files at the beginning of the synchronisation process, and this list is not updated during the run. If new files are added to the source after the file list is created, these new files will not be copied. Similarly, if files are deleted after the list is created, `rsync` will warn that it could not copy those files. In a live database, files are added and removed at any time. So, there is a risk that the database backup taken using rsync will not be restorable.  
  Incremental backups have a higher risk. 
  
2. **CRITICAL : Inconsistancies and File corruption risk**  
  `rsync` is not designed for a filesystem which is undergoing changes. It does not create a snapshot of the filesystem either. it is difficult to determine the exact point in time when the data was copied. This can lead to inconsistencies if files are modified during the synchronisation process. It is risky to use on a filesystem which is undergoing changes. Corruptions are reported.
3. **No Differential Backups**  
  No differential backups possible. 
4. **No Delta restore**  
  restore only files that are different than in backups based on checksums, which can improve restore speed by a lot, the bigger db, the better result
5. **No Encryption of backup repository**  
  This could be a serious limitation affecting the "Data-At-Rest" encryption compliance requirements.
6. **No TLS Protocols**  
  There is no support for Secure TLS Protocol, Certificate authentication for the file transfer.
7. **No Async/Parallel WAL Archiving**  
  WAL archiving happens in a single treaded/single process. Asynchronous and parallel archiving is not possible. A system which generates high volume of WAL files can cause serious lag in WAL archiving without Parallel/Async backup. 
8. **No Native Cloud bucket support**   
  The cloud bucket support is also a wrapper.
9. **No Incremental Backups possible to Cloud Buckets**
  Due to above mentioned archtiectural limiation, Incremental backups to cloud buckets are also not possible.
10. **No auto detection of switchover/failover**  
  If there is fail-over or swtich-over to standby in a PostgreSQL cluster, Barman don't have an automatic mechanism to change the backup configuration.
11. **No single database restore**  
  There is no option to restore a single database of a PostgreSQL cluster. The entire data directory need to be restored with all the database.
12. No parallelism for Barman-Cloud backup

## Limitations of pg_basebackup
12. **No Incremental backup***  
  No incremental backup is possible until PostgreSQL 17
13. **No Parallelism**  
  No Parallelism possible.This could be a serious limiation for big databases
14. **No compression over network**  
  Backup is copied over network in uncompressed format leading to heavy utilization of network bandwidth.
