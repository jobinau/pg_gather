# pg_gather
This is a SQL-only script for gathering performance and configuration data from PostgreSQL databases.  
And another SQL script for generating detailed HTML report from the collected data. Yes SQL-Only!

**Supported Versions** : PostgreSQL 10, 11, 12, 13 & 14  
**Minimum support versions** : PostgreSQL 9.5, 9.6


# Highlights
1. **Secure by Open :** Simple, Transperent, Fully auditable code.<br>
   A SQL-only data collection script. Programs with control structures are avoided for improving the readabilty and code auditability.
2. **No Executables :** No executables need to be deployed on the database host<br>
    Usage of executables on a secured environments posses risks and not acceptable in many environments
3. **Authentication agnostic**<br>
   Any authentication mechanism supported by PostgreSQL works for data gathering. So if `psql` is able to connect, data for analysis can be collected.
4. **Any Operating System** <br>
   Linux 32 / 64 bit, SunSolaris, Apple macOS, Microsoft Windows. Works everywhere where `psql` is available  
   (Windows users may Refer the Notes section below)
5. **Architecture agnostic**<br>
   x86-64 bit, ARM, Sparc, Power etc
6. **Auditable data** : Data is collected in a text file of Tab Seperated Values (TSV) format. Which makes it possible for reviewing and auditing the information before handing over for analysis.
7. **Any cloud/container/k8s** : Works with AWS RDS, Google Cloud SQL, On-Prim etc<br> 
   (Please see Heroku, AWS Aurora, Docker and K8s specific note in Notes section below)
8. **Zero failure design** : A Successful report generation with available information happens even if the Data collection is partial or there was failures due to permission issues  or unavailability of tables / views or other reasons.

# How to Use

# 1. Data Gathering.
Inorder to gather the configuration and Performance information, the `gather.sql` script need be executed against the database using `psql` as follows
```
psql <connection_parameters_if_any> -X -f gather.sql > out.txt
```
OR ALTERNATIVELY a gzip file
```
psql <connection_parameters_if_any> -X -f gather.sql | gzip > out.txt.gz
```
This script may take 20+ seconds to execute as there are sleeps/delays within. <br>
Recommended running the script as a privileged user (`superuser`, `rds_superuser` etc) or some account with `pg_monitor` privilege.  

This output file contains performance and configuration data for analysis  

## Notes: 
   1. There is a seperate `gather_old.sql` for **older** minimum support versions 9.5 and 9.6
   2. **Heroku** like DaaS hostings imposes very high restrictions on collecting performance data. query on views like pg_statistics may produce errors during the data collection. which can be ignored
   3. **MS Windows** users!, client tools like [pgAdmin](https://www.pgadmin.org/) comes with `psql` along with it. which can be used for running `pg_gather` against local or remote databases. For example
   ```
     "C:\Program Files\pgAdmin 4\v4\runtime\psql.exe" -h pghost -U postgres -f gather.sql > out.txt
   ```
   4. **Aurora** has "PostgreSQL compatible" offering. Even though it is look-alike PostgreSQL, It is not real PostgreSQL. So please do the following to the `gather.sql` which replaces one line with "NULL"
   ```
     sed -i 's/^CASE WHEN pg_is_in_recovery().*/NULL/' gather.sql
   ```
   5. **Docker** containers of PostgreSQL may not have curl, wget utilities to download `gather.sql` inside. So an alternate option of pipeing the content of the sql file to `psql` is recommended.
   ```
     cat gather.sql | docker exec -i <container> psql -X -f - > out.txt
   ```
   6. **Kubernetes** environment also will have similar restriction as mentioined for Docker. So similar approch is suggestable.
   ```
     cat gather.sql | kubectl exec -i <PGpod> -- psql -X -f - > out.txt
   ```


## Gathering data continuosly, but Partially
One-time data collecton may not be sufficient for capturing a problem which may not be happening at the moment. The `pg_gather` (Ver.8 onwards) has special optimizations for a light-weight and continuous data gathering for analysis.  The idea is to schedule `gather.sql` every minute against "template1" database. The generated output files can be collected into a directory.  
Following is an example of scheduling in Linux/Unix systems using cron.
```
* * * * * psql -U postgres -d template1 -X -f /path/to/gather.sql | gzip >  /path/to/out/out-`date +\%a-\%H.\%M`.txt.gz 2>&1
```
if the connection is to `template1` database, the gather script will collect only live, dynmamic, performance related information. Which means, all the database objects specific information will be skipped. So this is referred **"Partial"** gathering. The output is further compressed using gzip for much reduced size.

# 2. Data Analysis
## 2.1 Importing collected data
The collected data can be imported to a PostgreSQL Instance. This creates required schema objects in the `public` schema of the database  
**CAUTION :** Please avoid using any critical environments for importing the data. A temporary PostgreSQL instance is preferable.
```
sed -e '/^Pager/d; /^Tuples/d; /^Output/d; /^SELECT pg_sleep/d; /^PREPARE/d; /^\s*$/d' out.txt | psql -f gather_schema.sql -f -
```
## 2.2 Generating Report
The analysis report can be generated as follows
```
psql -X -f gather_report.sql > GatherReport.html
```
This HTML report can be viewed in your favourite borwser.

## 2.3 Importing "*Partial*" data
As mentioned in the previous section, partial data gathering is useful, if we ware scheduling the `gather.sql` as a simple continuous monitoring tool. The data can be imported to `history` schema.  
The schema can be created using the `history_schema.sql` provided.
```
psql -X -f history_schema.sql
```
This project provides a sample `imphistory.sh` file which automates importing partial data from multiple files into the tables in `history` schema. This script can be executed from the directory which contains all the output files. Multiiple files and Wild cards are allowed. Here is an example:
```
$ imphistory.sh out-*.gz > log.txt
```
Collecting the log file of the import is a good practice as shown above.

# ANNEXTURE 1 : Using PostgreSQL container and wrapper script
The above mentioned steps for data analysis appears simple. However, that needs a PostgreSQL instance where the data can be imported. As an alternate option, the `generate_report.sh` script can spin up a docker container and do everything for you. It is expected to be run from the cloned repository, or a directory that has both `gather_schema.sql` and `gather_report.sql` files available.
### How it works
This script will spin up a docker instance, import the provided output produced by `gather.sql` and output an html report. The script expects at least a single argument: path to the `out.txt` produced by `gather.sql`. 

There are two more additional positional arguments: 
* Desired report name with path. 
* A flag whether to keep the docker container. This allows us to use the raw data imported.

Example 1: Import data and generate html file
```
$ ./generate_report.sh /tmp/out.txt
...
Container 61fbc6d15c626b484bdf70352e94bbdb821971de1e00c6de774ca5cd460e8db3 deleted
Finished generating report in /tmp/out.txt.html
```
Example 2 : Import data, keep the container intact and generate report in the specified location
```
$ ./generate_report.sh /tmp/out.txt /tmp/custom-name.html y
...
Container df7b228a5a6a49586e5424e5fe7a2065d8be78e0ae3aa5cddd8658ee27f4790c left around
Finished generating report in /tmp/custom-name.html
```
# Advanced configurations
## Timezone 
By default, the `g_gather` report uses the same timezone of the server from the data is collected, because it considers the `log_timezone` paramter for generating the report. This helps to compare the PostgreSQL log entries with `pg_gather` report.
However, this many not be right timezone for few users. especially when they use cloud hostings. The `pg_gather` allows to have a custom timezone by setting the environment variable `PG_GATHER_TIMEZONE` to override the default. For example,
```
export PG_GATHER_TIMEZONE='UTC'
```
Please use the timezone name or abbriviation available from `pg_timezone_names`
# Demonstration
[![IMAGE ALT TEXT HERE](https://img.youtube.com/vi/k1pnXuJAl40/0.jpg)](https://www.youtube.com/watch?v=k1pnXuJAl40)
