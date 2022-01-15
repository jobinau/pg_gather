#!/bin/bash
# Bulk Import to history schema from continuous data gathering output files
# This is a new version of imphistory.sh to support parallel execution (Beta - 15-Jan-22)
# USAGE : imphistory_parallel.sh out*.gz

#Deside on the number of parallelism you need
PARALLEL=4

process_gather(){
    ##Check whether the files are really the partial gather outputs
    partial=`zcat $1 | head -n 12 | grep template1 | wc -l` ;
    ##Data collection timestamp. This info can be inserted for collect_ts of each line
    coll_ts=`zcat $1 | head -n 15 | sed -n '/COPY pg_gather/ {n; s/\([0-9-]*\s[0-9:\.+]*\).*/\1/; p}'`
    echo -e "\nImporting :"$coll_ts;
    if [ $partial = 1 ]; then
    #import gather data and copy it to history tables

        #In a real customer enviorment testing, an additional column appeared for pg_pid_wait like : ?column?|8459	ClientRead
        #This don't have a good explanation yet and treated as unknown bug. 
        #Added 2 lines to mitigate this problem: /^[[:space:]]*$/d      and    s/^\?column?|\(.*\)/\1/
        #TODO : Observe over a period of time and remove those 2 lines if possible.
        zcat $1 | sed -n '
        /^COPY/, /^\\\./ {
          s/COPY pg_get_activity (/COPY pg_get_activity (collect_ts,/
          s/COPY pg_pid_wait (/COPY pg_pid_wait (collect_ts,/
          s/COPY pg_get_db (/COPY pg_get_db (collect_ts,/
          /^[[:space:]]*$/d
          s/^\?column?|\(.*\)/\1/
          /^\(COPY\|\\\.\)/! s/^/'"$coll_ts"\\t'/ # All lines other than those starting with COPY or \. should have coll_ts inserted
          p
        }' | psql -q "options='-c search_path=history -c synchronous_commit=off'"  -f - 
    else
      echo "Full"
    fi
}

#Make the process_gather() function available for all the shells
export -f process_gather

#Run the files in parallel using multiple shells
echo "$@" | sed -e 's/ /\n/g' | xargs -I{} -P $PARALLEL bash -c process_gather\ \{\}