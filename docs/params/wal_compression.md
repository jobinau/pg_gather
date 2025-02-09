# wal_compression
Better WAL compression algorithms like `lz4` and `zstd` are supported by PostgreSQL 15 and above.
Generally, Modern machines are not limited by CPU capacity when running the PostgreSQL database. Using the additional CPU capacity on the machine for better compression could be valuable

### Important points to remember : 
1. There is **no absolute winner or looser in compression** alogirthms. Different algorithms would be suitable for different use cases, workloads and performance characterstics of machine hardware.
2. WAL Compression comes with a **cost of more CPU utilization**. It may be preferable to avoid WAL compression completely on systems which are highly CPU constrained, else it will have adverse effect.
3. WAL Compression is **selectable by each user session**. This give the flexibilty of changing the algorithm based on the workloads. 
    For example, one might prefer high compression when doing a bulk dataloading, while an OLTP application connection might perfer to avoid any compresssion to improve the responsiveness.
4. Compression algorithms like lz4 removes the freespace within the page to give better compression. So the compression **depends on the FILLFACTOR**.


## How to test
You may want to check how compression performance on a specific system
### Using pg_stat_wal
```
--Prepare a table
CREATE TABLE t AS SELECT generate_series(1,999999)a; VACUUM t;

--Test the WAL compression one by one
SET wal_compression= off;
\set QUIET \\ \timing on \\ SET max_parallel_maintenance_workers=0; SELECT pg_stat_reset_shared('wal'); begin; CREATE INDEX ON t(a); rollback; SELECT * FROM pg_stat_wal;

SET wal_compression=lz4;
\set QUIET \\ \timing on \\ SET max_parallel_maintenance_workers=0; SELECT pg_stat_reset_shared('wal'); begin; CREATE INDEX ON t(a); rollback; SELECT * FROM pg_stat_wal;

SET wal_compression=pglz;
\set QUIET \\ \timing on \\ SET max_parallel_maintenance_workers=0; SELECT pg_stat_reset_shared('wal'); begin; CREATE INDEX ON t(a); rollback; SELECT * FROM pg_stat_wal;
```
** Perform the tests when there is sufficient load on the system to arraive at meaningful conclusions because it is CPU vs I/O choice  
** Compare the `wal_bytes` numbers and Time from above tests.
### Using pg_waldump
```
--Prepare a table
CREATE TABLE t AS SELECT generate_series(1,999999)a; VACUUM t;

SET wal_compression= off;
\set QUIET \\ \timing on \\  select pg_switch_wal(); select pg_sleep(2); SET max_parallel_maintenance_workers=0; SELECT pg_stat_reset_shared('wal'); begin; CREATE INDEX ON t(a); rollback; SELECT pg_walfile_name(pg_current_wal_lsn()); SELECT * FROM pg_stat_wal
;select pg_sleep(2); SELECT pg_walfile_name(pg_current_wal_lsn());

--Note down the walsegements generated (there could be multiple)
--Check the FPIs in in each segments and add them
 pg_waldump 000000010000001800000061 -w -z

--Repeat it for the compression alorithm
SET wal_compression=lz4;
\set QUIET \\ \timing on \\  select pg_switch_wal(); select pg_sleep(2); SET max_parallel_maintenance_workers=0; SELECT pg_stat_reset_shared('wal'); begin; CREATE INDEX ON t(a); rollback; SELECT pg_walfile_name(pg_current_wal_lsn()); SELECT * FROM pg_stat_wal
;select pg_sleep(2); SELECT pg_walfile_name(pg_current_wal_lsn());

```

## Additional References
1. [WAL Compression in PostgreSQL and Improvements in Version 15](https://www.percona.com/blog/wal-compression-in-postgresql-and-recent-improvements-in-version-15/)  
2. [PostgreSQL Community Discussions](https://www.postgresql.org/message-id/flat/3037310D-ECB7-4BF1-AF20-01C10BB33A33%40yandex-team.ru)
3. [Code Commit](https://git.postgresql.org/gitweb/?p=postgresql.git;h=4035cd5d4)


