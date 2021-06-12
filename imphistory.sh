#!/bin/bash
for f in out-Sat-19*.txt;
do 
    ##Check whether the files are really the partial gather outputs
    partial=`head -n 12 $f | grep template1 | wc -l` ;
    echo $partial;
    if [ $partial = 1 ]; then
      #import gather data and copy it to history tables
      echo "Partial"
      sed '/^Pager/d;
        /^Tuples/d;
        /^Output/d;
        /^SELECT pg_sleep/d;
        /^PREPARE/d;
        /^\s*$/d;
        s/^COPY pg_gather/COPY pg_gather (collect_ts,usr,db,ver,pg_start_ts,recovery,client,server,reload_ts,current_wal)/;
        s/^COPY pg_get_block/COPY pg_get_block(blocked_pid,blocked_user,blocked_client_addr,blocked_client_hostname,blocked_application_name,blocked_wait_event_type,blocked_wait_event,blocked_statement,blocked_xact_start,blocking_pid,blocking_user,blocking_user_addr,blocking_client_hostname,blocking_application_name,blocking_wait_event_type,blocking_wait_event,statement_in_blocking_process,blocking_xact_start)/;
        s/^COPY pg_replication_stat/COPY pg_replication_stat(usename,client_addr,client_hostname,state,sent_lsn,write_lsn,flush_lsn,replay_lsn,sync_state)/;
        s/^COPY pg_archiver_stat/COPY pg_archiver_stat(archived_count,last_archived_wal,last_archived_time,last_failed_wal,last_failed_time)/;
        s/^COPY pg_get_bgwriter/COPY pg_get_bgwriter(checkpoints_timed,checkpoints_req,checkpoint_write_time,checkpoint_sync_time,buffers_checkpoint,buffers_clean,maxwritten_clean,buffers_backend,buffers_backend_fsync,buffers_alloc,stats_reset)/
        $aSELECT count(*) \n FROM pg_gather;' \
        $f | psql "options='-c search_path=history -c synchronous_commit=off'"  -f - 
    else
      echo "Full"
    fi
done
