#!/bin/bash
# Import Partial, continuous data gathering output files to history schema.
if [ $# -eq 0 ]
  then
    echo "Please specify the log files as parameter. Wildcards accepted"
fi
for f in "$@"
do 
  ##Data collection timestamp. This info can be inserted for collect_ts of each line
  coll_ts=`zcat $f | head -n 15 | sed -n '/COPY pg_gather/ {n; s/\([0-9-]*\s[0-9:\.+-]*\).*/\1/; p}'`
  printf "\nImporting %s from %s\n" "$coll_ts" "$f"
  #In some customer cases, additional column appeared for pg_pid_wait like : ?column?|8459	ClientRead
  #Suspectedly because customer passing -x instead of -X, Not yet confirmed with confidence. So treated as unknown bug
  #Added 2 lines to mitigate this problem: /^[[:space:]]*$/d      and    s/^\?column?|\(.*\)/\1/
  #TODO : Observe over a period of time and remove those 2 lines if possible.
  zcat $f | sed -n '
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
    /^COPY pg_get_statements/, /^\\\./d  #-do-
    /^COPY pg_get_ns/, /^\\\./d  #-do-
    /^[[:space:]]*$/d
    s/^\?column?|\(.*\)/\1/
    /^\(COPY\|\\\.\)/! s/^/'"$coll_ts"\\t'/ # All lines other than those starting with COPY or \. should have coll_ts inserted
    p
  }' | psql "options='-c search_path=history -c synchronous_commit=off'"  -f - 
done
