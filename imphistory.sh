#!/bin/bash
if [ $# -eq 0 ]
  then
    echo "Please specify the log files as parameter. Wildcards accepted"
fi
for f in "$@"
do 
    ##Check whether the files are really the partial gather outputs
    partial=`head -n 12 $f | grep template1 | wc -l` ;
    ##Data collection timestamp. This info can be inserted for collect_ts of each line
    coll_ts=`head -n 15 $f | sed -n '/COPY pg_gather/ {n; s/\([0-9-]*\s[0-9:\.+]*\).*/\1/; p}'`
    echo
    echo "\Importing :"$coll_ts;
    if [ $partial = 1 ]; then
      #import gather data and copy it to history tables
      echo "Partial"

#      Old fasioned simple replacement using sed and final multi update using CTE
#      sed '/^Pager/d;
#        /^Tuples/d;
#        /^Output/d;
#        /^SELECT pg_sleep/d;
#        /^PREPARE/d;
#        /^\s*$/d;
#        s/^COPY pg_gather/COPY pg_gather (collect_ts,usr,db,ver,pg_start_ts,recovery,client,server,reload_ts,current_wal)/;
#        s/^COPY pg_get_block/COPY pg_get_block(blocked_pid,blocked_user,blocked_client_addr,blocked_client_hostname,blocked_application_name,blocked_wait_event_type,blocked_wait_event,blocked_statement,blocked_xact_start,blocking_pid,blocking_user,blocking_user_addr,blocking_client_hostname,blocking_application_name,blocking_wait_event_type,blocking_wait_event,statement_in_blocking_process,blocking_xact_start)/;
#        s/^COPY pg_replication_stat/COPY pg_replication_stat(usename,client_addr,client_hostname,state,sent_lsn,write_lsn,flush_lsn,replay_lsn,sync_state)/;
#        s/^COPY pg_archiver_stat/COPY pg_archiver_stat(archived_count,last_archived_wal,last_archived_time,last_failed_wal,last_failed_time)/;
#        s/^COPY pg_get_bgwriter/COPY pg_get_bgwriter(checkpoints_timed,checkpoints_req,checkpoint_write_time,checkpoint_sync_time,buffers_checkpoint,buffers_clean,maxwritten_clean,buffers_backend,buffers_backend_fsync,buffers_alloc,stats_reset)/
#        $aWITH collect AS (SELECT collect_ts FROM history.pg_gather WHERE imp_ts = (SELECT max(imp_ts) from history.pg_gather)), \
#         updateactivity AS (UPDATE history.pg_get_activity SET collect_ts = (SELECT collect_ts FROM collect) WHERE collect_ts IS NULL), \
#         updatedb AS (UPDATE history.pg_get_db SET collect_ts = (SELECT collect_ts FROM collect) WHERE collect_ts IS NULL), \
#         updatewait AS (UPDATE history.pg_pid_wait SET collect_ts = (SELECT collect_ts FROM collect) WHERE collect_ts IS NULL), \
#         updateblock AS (UPDATE history.pg_get_block SET collect_ts = (SELECT collect_ts FROM collect) WHERE collect_ts IS NULL), \
#         updatebgwriter AS (UPDATE history.pg_get_bgwriter SET collect_ts = (SELECT collect_ts FROM collect) WHERE collect_ts IS NULL), \
#         updatearchiver AS (UPDATE history.pg_archiver_stat SET collect_ts = (SELECT collect_ts FROM collect) WHERE collect_ts IS NULL), \
#         updatereplication AS (UPDATE history.pg_replication_stat SET collect_ts = (SELECT collect_ts FROM collect) WHERE collect_ts IS NULL) \
#         SELECT collect_ts,(SELECT count(*) FROM history.pg_gather) FROM collect;' \
#        $f | psql "options='-c search_path=history -c synchronous_commit=off'"  -f - 

# An alternate and more elegent solution (19-Jun-2021) to take out only COPY statement manipulate
        sed -n '
        /^COPY/, /^\\\./ {
          s/COPY pg_get_activity (/COPY pg_get_activity (collect_ts,/
          s/COPY pg_pid_wait (/COPY pg_pid_wait (collect_ts,/
          s/COPY pg_get_db (/COPY pg_get_db (collect_ts,/
          /^COPY\|\\\./! s/\(.*\)/'"$coll_ts"\\t'\1/g
          p
        }' $f | psql "options='-c search_path=history -c synchronous_commit=off'"  -f - 
#        /^Output/d
#        /^PREPARE/d

    else
      echo "Full"
    fi
done
