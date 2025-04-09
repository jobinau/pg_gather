# cp / rsync as archive_command
WAL archiving is an essential part of Backups to facilitate point-in-time recovery (PITR), so its reliability is crucial.
Unfortunately, the PostgreSQL documentation provides a command line which includes `cp` as follows.
```
archive_command = 'test ! -f /mnt/server/archivedir/%f && cp %p /mnt/server/archivedir/%f' 
```
The official documentation states, "This is an example, not a recommendation, and might not work on all platforms." However, that is not enough to warn against the use of `cp`. Many users tend to use this in critical environments.  
As Tom Lane comments : *"It's not really intended to be production-grade, and I think the docs say so (perhaps not emphatically enough)"*
`cp` or `rsync` are not designed to meet the high-reliability requirements of a database workload. But they are more tuned for the speed. Using them as WAL archiving could jeopardise the reliability of WALs archived.
The PostgreSQL documentation still contains such samples to explain the concept of WAL archiving.


## Known Problems
1. Partially written WAL files:  
 if the file copy is interrupted due to some reason. The archive destination can have partially written WAL files
2. `cp` is not atomic  
 The file can be read before the contents are materialised, causing an early end to recovery.
3. Accidental overwriting of files.  
 if the backup location is mounted on multiple hosts, a plain `cp` could overwrite files
4. WAL Archive failures.  
 Inorder to protect from accidental overwriting of files `test ! -f` check is used in the example. But that often results in archive failures and WAL directory fill ups.
5. Risk of losing archived WAL file
 many `cp` implementations won't flush. So, there exists a narrow gap where a file can be lost from the archive destination if the OS kernel is not flushing it before a power failure.
6. Missing WAL  
some of the `cp` implementations (GNU cp) return a value of 0 even if a copy is not successful. This can lead to the removal of the WAL file without any archive.
  

## Some of the relevant PostgreSQL community discussions
Following discussions could reveal the expert's view on the subject
1. [https://www.postgresql.org/message-id/flat/E1QXiEl-00068A-1S%40gemulon.postgresql.org](https://www.postgresql.org/message-id/flat/E1QXiEl-00068A-1S%40gemulon.postgresql.org)
2. [https://www.postgresql.org/message-id/flat/53E5603B.5040102%40agliodbs.com](https://www.postgresql.org/message-id/flat/53E5603B.5040102%40agliodbs.com)

## Recommendations
1. PostgreSQL supports `archive_library` from PostgreSQL 15 onwards and a simple sample library: `basic_archive` is provided as part of contrib modules   Please refer : [https://www.postgresql.org/docs/current/basic-archive.html](https://www.postgresql.org/docs/current/basic-archive.html) . So the regular cp / rsync commands are no longer needed.
2. An advanced backup tool is recommended which can safely execute WAL archiving; for example, pgBackRest can do WAL archiving in Asynchronous and Parallel mode. Please refer: [https://www.percona.com/blog/how-pgbackrest-is-addressing-slow-postgresql-wal-archiving-using-asynchronous-feature/](https://www.percona.com/blog/how-pgbackrest-is-addressing-slow-postgresql-wal-archiving-using-asynchronous-feature/)
