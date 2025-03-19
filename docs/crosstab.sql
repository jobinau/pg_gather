--------- Crosstab report for continuous data collection -----------
--   This requires tablefunc contrib extension to be created      --
--   tablefunc is part of PostgreSQL contrib modules              --
--------------------------------------------------------------------
--Findout the wait events and prepare the columns for the crosstab report
SELECT STRING_AGG(col,',') AS cols FROM 
(SELECT COALESCE(wait_event,'CPU') || ' int' "col"
FROM history.pg_pid_wait WHERE wait_event IS NULL OR 
  wait_event NOT IN ('ArchiverMain','AutoVacuumMain','BgWriterHibernate','BgWriterMain','CheckpointerMain','LogicalApplyMain','LogicalLauncherMain','RecoveryWalStream','SysLoggerMain','WalReceiverMain','WalSenderMain','WalWriterMain','CheckpointWriteDelay','PgSleep','VacuumDelay')  
GROUP BY wait_event ORDER BY 1) as A \gset
--Run a crosstab query 
SELECT *
FROM crosstab(
  $$ SELECT collect_ts,COALESCE(wait_event,'CPU') "Event", count(*) FROM history.pg_pid_wait
WHERE wait_event IS NULL OR wait_event NOT IN ('ArchiverMain','AutoVacuumMain','BgWriterHibernate','BgWriterMain','CheckpointerMain','LogicalApplyMain','LogicalLauncherMain','RecoveryWalStream','SysLoggerMain','WalReceiverMain','WalSenderMain','WalWriterMain','CheckpointWriteDelay','PgSleep','VacuumDelay')
GROUP BY 1,2 ORDER BY 1, 2 $$,
  $$ SELECT COALESCE(wait_event,'CPU')      
FROM history.pg_pid_wait WHERE wait_event IS NULL OR 
  wait_event NOT IN ('ArchiverMain','AutoVacuumMain','BgWriterHibernate','BgWriterMain','CheckpointerMain','LogicalApplyMain','LogicalLauncherMain','RecoveryWalStream','SysLoggerMain','WalReceiverMain','WalSenderMain','WalWriterMain','CheckpointWriteDelay','PgSleep','VacuumDelay')  
GROUP BY wait_event ORDER BY 1 $$)
AS ct (Collect_Time timestamp with time zone,:cols);

