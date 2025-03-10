# Continuous Data collection

Continuous data collection can be an excellent solution for some of the use-cases as follows

1. Simple Monitoring  
Implement simple monitoring when sophisticated, dedicated monitoring tools are not available or not feasible due to various reasons like security policies, resources, etc.
2. Capturing an event which happens rarely  
Continuous capture of wait events can reveal many details about the system. It is a proven technique for capturing rare events.
3. Load pattern study.  
   

When connected to the `template1` database, the `gather.sql` script switches to a lightweight mode and skips the collection of many of the datapoints including object-specific information. It collects only live, dynamic, performance-related information. This is called a **partial** gathering and it can be further compressed with gzip to reduce the size significantly.

## Data collection

## Using cron job
A job can be scheduled to run `gather.sql` to run every minute against the "template1" database and collect the output files into a directory.
Following is an example for scheduling in Linux/Unix systems using `cron`.
```
* * * * * psql -U postgres -d template1 -X -f /path/to/gather.sql | gzip >  /path/to/out/out-`date +\%a-\%H.\%M`.txt.gz 2>&1
```


## Using simple shell loop. 
if there is any important event which need to be monitored. A simple shell loop should be good enough
```
for i in {1..10}
do 
    psql -U postgres -d template1 -X -f ~/pg_gather/gather.sql | gzip >  /tmp/out-`date +\%a-\%H.\%M.\%S`.txt.gz 2>&1
done 
```

# Importing the data of a continuous collection

A separate schema (`history`) can hold the imported data.
A script file with the name [`history_schema.sql`](../history_schema.sql) is provided for creating this schema and objects.
```
psql -X -f history_schema.sql
```
A Bash script [`imphistory.sh`](../imphistory.sh) is provided, which automates importing partial data from multiple files into the tables in `history` schema. This script can be executed from the directory which contains all the output files. Multiiple files and Wild cards are allowed. Here is an example:
```
$ imphistory.sh out-*.gz > log.txt
```

# Analysis 

## High level summary

```
SELECT COALESCE(wait_event,'CPU') "Event", count(*) FROM history.pg_pid_wait
WHERE wait_event IS NULL OR wait_event NOT IN ('ArchiverMain','AutoVacuumMain','BgWriterHibernate','BgWriterMain','CheckpointerMain','LogicalApplyMain','LogicalLauncherMain','RecoveryWalStream','SysLoggerMain','WalReceiverMain','WalSenderMain','WalWriterMain','CheckpointWriteDelay','PgSleep','VacuumDelay')
GROUP BY 1 ORDER BY count(*) DESC;
```

## Wait events in the order of time

```
SELECT collect_ts,COALESCE(wait_event,'CPU') "Event", count(*) FROM history.pg_pid_wait
WHERE wait_event IS NULL OR wait_event NOT IN ('ArchiverMain','AutoVacuumMain','BgWriterHibernate','BgWriterMain','CheckpointerMain','LogicalApplyMain','LogicalLauncherMain','RecoveryWalStream','SysLoggerMain','WalReceiverMain','WalSenderMain','WalWriterMain','CheckpointWriteDelay','PgSleep','VacuumDelay')
GROUP BY 1,2 ORDER BY 1,2 DESC;
```

## Crosstab report
Crosstab reports of waitevents over a time can provide more insight into the way waitevents are changing with time.
This kind of information will be useful for graphing.
A sample [crosstab query is provided](crosstab.sql) using which a CSV file for graphing can be generated like `psql --csv -f crosstab.sql > crosstab.csv`

## FAQ
## Will the continuous data collection impact the server performance?
The code for data collection went for multiple rounds of optimization effort over last few years. It is expected to take least server resource.
On test enviroments, Typically 4-5% of single CPU core is observed. 
In a multi-core server, this overhead becomes negligable and almost invisible
```
    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND   
  14316 postgres  20   0  225812  29052  24704 S   3.6   0.1   0:00.59 postgres: 14/main: postgres template1 127.0.0.1(39142) EXECUTE
  14313 jobin     20   0   25452  13312  11136 S   1.7   0.0   0:00.24 psql -U postgres -d template1 -X -f /home/jobin/pg_gather/gather.sql
```
The collection happens over single database connection and it is expected to consume 10MB RAM.
## Is it possible to generate regular pg_gather report using a snapshot of partial data collection  
Yes, One of the main objective of the `pg_gather` projct is the capability to generate reports using available informaiton. Since it is part of the design principle, generating the report usign partial data collection is supported.
If you find any issue, please report it as quick as possible in the [issues page](https://github.com/jobinau/pg_gather/issues)
