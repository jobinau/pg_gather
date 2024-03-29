#!/bin/bash
# Bulk Import to history schema from continuous data gathering output files
# This is a new version of imphistory.sh to support parallel execution (Beta - 15-Jan-22)
# USAGE : imphistory_parallel.sh out*.gz

#Deside on the number of parallelism you need
PARALLEL=4

process_gather(){
  ##Data collection timestamp. This info can be inserted for collect_ts of each line
  coll_ts=`zcat $1 | head -n 15 | sed -n '/COPY pg_gather/ {n; s/\([0-9-]*\s[0-9:\.+-]*\).*/\1/; p}'`
  printf "\nImporting %s \n" "$coll_ts"
  #In a real customer enviorment testing, an additional column appeared for pg_pid_wait like : ?column?|8459	ClientRead
  #This don't have a good explanation yet and treated as unknown bug. 
  #Added 2 lines to mitigate this problem: /^[[:space:]]*$/d      and    s/^\?column?|\(.*\)/\1/
  #TODO : Observe over a period of time and remove those 2 lines if possible.
  #TODO : copy pg_get_slots and pg_get_ns lines for sed from "imphistory.sh"
  zcat $1 | sed -n '
  /^COPY/, /^\\\./ {
    s/COPY pg_get_activity (/COPY pg_get_activity (collect_ts,/
    s/COPY pg_pid_wait (/COPY pg_pid_wait (collect_ts,/
    s/COPY pg_get_db (/COPY pg_get_db (collect_ts,/
    s/COPY pg_replication_stat(/COPY pg_replication_stat (collect_ts,/
    s/COPY pg_get_slots(/COPY pg_get_slots(collect_ts,/
    /^COPY pg_srvr/, /^\\\./d  #Delete any full gather information
    /^COPY pg_get_roles/, /^\\\./d   # -do-
    /^COPY pg_get_confs/, /^\\\./d   # -do-
    /^COPY pg_get_file_confs/, /^\\\./d  #-do-
    /^COPY pg_get_class/, /^\\\./d  #-do-
    /^COPY pg_get_index/, /^\\\./d  #-do-
    /^COPY pg_get_rel/, /^\\\./d  #-do-
    /^COPY pg_tab_bloat/, /^\\\./d  #-do-
    /^COPY pg_get_toast/, /^\\\./d  #-do-
    /^COPY pg_get_extension/, /^\\\./d  #-do-
    /^COPY pg_get_ns/, /^\\\./d  #-do-
    /^[[:space:]]*$/d
    s/^\?column?|\(.*\)/\1/
    /^\(COPY\|\\\.\)/! s/^/'"$coll_ts"\\t'/ # All lines other than those starting with COPY or \. should have coll_ts inserted
    p
  }' | psql "options='-c search_path=history -c synchronous_commit=off'"  -f -
}

#Make the process_gather() function available for all the shells
export -f process_gather

#Run the files in parallel using multiple shells
echo "$@" | sed -e 's/ /\n/g' | xargs -I{} -P $PARALLEL bash -c process_gather\ \{\}

