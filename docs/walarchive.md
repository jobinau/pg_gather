# WAL archive failure and lag
WAL files are pushed to external backup repositories where backup is maintained.
Due various reasons the WAL archivings could be failing or delaying behind the current WAL generation (lag).
Following SQLs could help to analyze the archiving failures and delays.
If WAL archive is not healthy, Backups also might fail and Point-in-time-Recovery won't be possible.

## From pg_gather data
```SQL
SELECT collect_ts "collect_time", current_wal "current_lsn", last_archived_wal
 , coalesce(nullif(CASE WHEN length(last_archived_wal) < 24 THEN '' ELSE ltrim(substring(last_archived_wal, 9, 8), '0') END, ''), '0') || '/' || substring(last_archived_wal, 23, 2) || '000001' "last_archived_lsn"
 , last_archived_time::text || ' (' || CASE WHEN EXTRACT(EPOCH FROM(collect_ts - last_archived_time)) < 0 THEN 'Right Now'::text ELSE (collect_ts - last_archived_time)::text END  || ')' "last_archived_time"
 , pg_wal_lsn_diff( current_wal, (coalesce(nullif(CASE WHEN length(last_archived_wal) < 24 THEN '' ELSE ltrim(substring(last_archived_wal, 9, 8), '0') END, ''), '0') || '/' || substring(last_archived_wal, 23, 2) || '000001') :: pg_lsn )
 ,last_failed_wal,last_failed_time
  FROM  pg_gather,  pg_archiver_stat;
```

## From PostgreSQL Directly
```SQL
SELECT CURRENT_TIMESTAMP,pg_current_wal_lsn()
 ,coalesce(nullif(CASE WHEN length(last_archived_wal) < 24 THEN '' ELSE ltrim(substring(last_archived_wal, 9, 8), '0') END, ''), '0') || '/' || substring(last_archived_wal, 23, 2) || '000001' "last_archived_lsn"
 , last_archived_time::text || ' (' || CASE WHEN EXTRACT(EPOCH FROM(CURRENT_TIMESTAMP - last_archived_time)) < 0 THEN 'Right Now'::text ELSE (CURRENT_TIMESTAMP - last_archived_time)::text END  || ')' "last_archived_time"
  , pg_size_pretty(pg_wal_lsn_diff( pg_current_wal_lsn(), (coalesce(nullif(CASE WHEN length(last_archived_wal) < 24 THEN '' ELSE ltrim(substring(last_archived_wal, 9, 8), '0') END, ''), '0') || '/' || substring(last_archived_wal, 23, 2) || '000001') :: pg_lsn )) archive_lag
 ,last_failed_wal,last_failed_time
FROM pg_stat_archiver;
```