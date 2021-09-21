#!/bin/bash
# Import Partial, continuous data gathering output files to history schema.
if [ $# -eq 0 ]
  then
    echo "Please specify the log files as parameter. Wildcards accepted"
fi
for f in "$@"
do 
    ##Check whether the files are really the partial gather outputs
    partial=`zcat $f | head -n 12 | grep template1 | wc -l` ;
    ##Data collection timestamp. This info can be inserted for collect_ts of each line
    coll_ts=`zcat $f | head -n 15 | sed -n '/COPY pg_gather/ {n; s/\([0-9-]*\s[0-9:\.+]*\).*/\1/; p}'`
    echo
    echo "\Importing :"$coll_ts;
    if [ $partial = 1 ]; then
      #import gather data and copy it to history tables
      echo "Partial"
        #In a real customer enviorment testing, an additional column appeared for pg_pid_wait like : ?column?|8459	ClientRead
        #This don't have a good explanation yet and treated as unknown bug. 
        #Added 2 lines to mitigate this problem: /^[[:space:]]*$/d      and    s/^\?column?|\(.*\)/\1/
        #TODO : Observe over a period of time and remove those 2 lines if possible.
        zcat $f | sed -n '
        /^COPY/, /^\\\./ {
          s/COPY pg_get_activity (/COPY pg_get_activity (collect_ts,/
          s/COPY pg_pid_wait (/COPY pg_pid_wait (collect_ts,/
          s/COPY pg_get_db (/COPY pg_get_db (collect_ts,/
          /^[[:space:]]*$/d
          s/^\?column?|\(.*\)/\1/
          /^\(COPY\|\\\.\)/! s/^/'"$coll_ts"\\t'/ # All lines other than those starting with COPY or \. should have coll_ts inserted
          p
        }' | psql "options='-c search_path=history -c synchronous_commit=off'"  -f - 
    else
      echo "Full"
    fi
done
