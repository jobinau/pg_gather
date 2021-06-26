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
        zcat $f | sed -n '
        /^COPY/, /^\\\./ {
          s/COPY pg_get_activity (/COPY pg_get_activity (collect_ts,/
          s/COPY pg_pid_wait (/COPY pg_pid_wait (collect_ts,/
          s/COPY pg_get_db (/COPY pg_get_db (collect_ts,/
          /^COPY\|\\\./! s/\(.*\)/'"$coll_ts"\\t'\1/g
          p
        }' | psql "options='-c search_path=history -c synchronous_commit=off'"  -f - 
    else
      echo "Full"
    fi
done
