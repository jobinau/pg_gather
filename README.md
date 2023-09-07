# pg_gather aka pgGather
![pgGather logo](./docs/pgGather.svg)

This project mainly two SQL-only scripts for users. One (gather.sql) for gathering performance and configuration data from PostgreSQL databases. And another SQL script (gather_report.sql)  is available for analyzing and generating detailed HTML reports from the collected data. Yes, everything SQL-Only!, leveraging the built-in features of `psql`-The command-line utility of PostgreSQL.

**Supported Versions** : PostgreSQL 10, 11, 12, 13, 14 & 15  
**Older versions** : For PostgeSQL 9.6 and older, Please refer the [documentation page](docs/oldversions.md)

# Highlights
1. **Secure by Open :** Simple, Transperent, Fully auditable code.
   A SQL-only data-collection script ensures full transparency about what is collected, transmitted and analyzed. Programs with any control structures are avoided to improve the readability and auditability of the data collection. This is one reason for separating data collection and analysis.
2. **No Executables :** No executables need to be deployed on the database host  
   The usage of executables in secured environments poses risks. That many not acceptable in many highly secure environments. `pg_gather` requires only the standard PostgreSQL command line utility `psql`. No other libraries or executables are needed.
3. **Authentication agnostic**
   Any authentication mechanism supported by PostgreSQL works for data gathering of `pg_gather`, becauee it use standard `psql`
4. **Any Operating System**
   Linux 32 / 64 bit, SunSolaris, Apple macOS, Microsoft Windows. It works everywhere `psql` is available. This ensures maximum portability.
   (Windows users may please refer the [Notes section](#notes) below)
5. **Architecture agnostic**
   x86-64 bit, ARM, Sparc, Power etc. It works everywhere `psql` is available.
6. **Auditable and optionally maskable data** :  
   `pg_gather` collects data in a text file of Tab Separated Values (TSV) format. This makes it possible to review and audit the information before handing it over or transmitting it for analysis. Additional masking or trimming is also possible in [easy steps](docs/security.md)
7. **Any cloud/container/k8s** : Works with AWS RDS, Google Cloud SQL, On-Prim etc  
   (Please see Heroku, AWS Aurora, Docker and K8s specific notes in the [Notes section](#notes) below)
8. **Zero failure design** :   
   A Successful generation of a report with the available information happens even if the Data collection is partial or there were failures due to permission issues, unavailability of tables/views, or any other reasons.
9. **Low overhead for data collection** :  
   Data collection is separated from Data analysis by the very design itself. The collected data can be analyzed on an independent system so the execution of analysis queries won't adversely impact the critical systems. Overhead of data collection is negligible in most cases.
10. **Small, single file data dump** :  
    The redundancy in collected data is avoided as much as possible to generate the smallest file possible, which can be further compressible by `gzip` to a few kilobytes or MBs for easy transmission and storage.
  

# How to Use

# 1. Data Gathering.
Inorder to gather the configuration and Performance information, the `gather.sql` script need be executed against the database using `psql` as follows:
```
psql <connection_parameters_if_any> -X -f gather.sql > out.txt
```
OR ALTERNATIVELY pipe to a compression utilty to get a compressed output as follows:
```
psql <connection_parameters_if_any> -X -f gather.sql | gzip > out.txt.gz
```
This script may take 20+ seconds to execute as there are sleeps/delays within. We Recommend running the script as a privileged user (`superuser`, `rds_superuser` etc.) or some account with `pg_monitor` privilege. This output file contains performance and configuration data for analysis  
<a name="notes">
## Notes:</a> 
   1. **Heroku** like DaaS hostings imposes very high restrictions on collecting performance data. query on views like pg_statistics may produce errosrs during the data collection. which can be ignored
   2. **MS Windows** users!, client tools like [pgAdmin](https://www.pgadmin.org/) comes with `psql` along with it. which can be used for running `pg_gather` against local or remote databases. For example
   ```
     "C:\Program Files\pgAdmin 4\v4\runtime\psql.exe" -h pghost -U postgres -f gather.sql > out.txt
   ```
   3. **Aurora** has "PostgreSQL compatible" offering. Even though it is look-alike PostgreSQL, It is not real PostgreSQL. So please do the following to the `gather.sql` which replaces one line with "NULL"
   ```
     sed -i 's/^CASE WHEN pg_is_in_recovery().*/NULL/' gather.sql
   ```
   4. **Docker** containers of PostgreSQL may not have curl, wget utilities to download `gather.sql` inside. So an alternate option of pipeing the content of the sql file to `psql` is recommended.
   ```
     cat gather.sql | docker exec -i <container> psql -X -f - > out.txt
   ```
   5. **Kubernetes** environment also will have similar restriction as mentioined for Docker. So similar approch is suggestable.
   ```
     cat gather.sql | kubectl exec -i <PGpod> -- psql -X -f - > out.txt
   ```

## Gathering data continuosly, but Partially
More than one time data collection may be required to capture the details of a problem that may not be happening at the moment or occurs occasionally. The `pg_gather` (Ver.8 onwards) has special optimizations for lightweight and continuous data gathering for analysis. The idea is to schedule `gather.sql` every minute against the "template1" database and corresponding output files can be collected into a directory.  
Following is an example of scheduling in Linux/Unix systems using cron.
```
* * * * * psql -U postgres -d template1 -X -f /path/to/gather.sql | gzip >  /path/to/out/out-`date +\%a-\%H.\%M`.txt.gz 2>&1
```
If the connection is to `template1` database, the gather script will collect only live, dynamic, performance-related information. This means pg_gather will skip all the object-specific information. So this is referred **"Partial"** gathering. The output is further compressed using gzip for much-reduced size.

# 2. Data Analysis
## 2.1 Importing collected data
The collected data can be imported to a PostgreSQL Instance. This creates required schema objects in the `public` schema of the database. 
**CAUTION :** Please avoid importing the data into any critical environments/databases. A temporary PostgreSQL instance is preferable.
```
 psql -f gather_schema.sql -f out.txt
```
Deprecated usage of `sed` : sed -e '/^Pager/d; /^Tuples/d; /^Output/d; /^SELECT pg_sleep/d; /^PREPARE/d; /^\s*$/d' out.txt | psql -f gather_schema.sql -
## 2.2 Generating Report
An analysis report in HTML format can be generated from the imported data as follows.
```
psql -X -f gather_report.sql > GatherReport.html
```
You may use your favourite web browser to read the report.

NOTE: PostgreSQL version 13 or above is required to generate the analysis report.

## 2.3 Importing "*Partial*" data
As mentioned in the previous section, partial data gathering is helpful if we schedule the `gather.sql` as a simple continuous monitoring tool. A separate schema with the name `history` can hold the imported data.
A script file with the name `history_schema.sql` is provided for creating this schema and objects.
```
psql -X -f history_schema.sql
```
This project provides a sample `imphistory.sh` file which automates importing partial data from multiple files into the tables in `history` schema. This script can be executed from the directory which contains all the output files. Multiiple files and Wild cards are allowed. Here is an example:
```
$ imphistory.sh out-*.gz > log.txt
```
Collecting the import log file is a good practice, as shown above.

# ANNEXTURE 1 : Using PostgreSQL container and wrapper script
The steps mentioned above for data analysis appear simple. However, that needs a PostgreSQL instance to which the data can be imported. An alternate option is to use the `generate_report.sh` script, which can spin up a PostgreSQL docker container and do everything for you. This script should be executed from a directory with both `gather_schema.sql` and `gather_report.sql` files available.

This script will spin up a docker instance, import the provided output produced by `gather.sql` and output an HTML report. This script expects at least a single argument: path to the `out.txt`, The output file produced by `gather.sql`. 

There are two more additional positional arguments: 
* Desired report name with path. 
* A flag to specify whether to keep the docker container. This flag allows to usage of the container and data for further analysis.

Example 1: Import data and generate an HTML file
```
$ ./generate_report.sh /tmp/out.txt
...
Container 61fbc6d15c626b484bdf70352e94bbdb821971de1e00c6de774ca5cd460e8db3 deleted
Finished generating report in /tmp/out.txt.html
```
Example 2: Import data, keep the container intact and generate the report in the specified location
```
$ ./generate_report.sh /tmp/out.txt /tmp/custom-name.html y
...
Container df7b228a5a6a49586e5424e5fe7a2065d8be78e0ae3aa5cddd8658ee27f4790c left around
Finished generating report in /tmp/custom-name.html
```
# Advanced configurations
## Timezone 
By default, the `pg_gather` report uses the same timezone of the server from which the data is collected, because it considers the `log_timezone` parameter for generating the report. This default timezone setting helps to compare the PostgreSQL log entries with the `pg_gather` report.
However, this may not be the right timezone for few users, especially when cloud hostings are used. The `pg_gather` allows the user to have a custom timezone by setting the environment variable `PG_GATHER_TIMEZONE` to override the default. For example,
```
export PG_GATHER_TIMEZONE='UTC'
```
Please use the timezone name or abbreviation available from `pg_timezone_names`
# Demo
## Data collection
[![IMAGE ALT TEXT HERE](https://img.youtube.com/vi/4EK7BoV6oOg/0.jpg)](https://youtu.be/4EK7BoV6oOg)
## Simple Report Generation (1min): 
[![Import data and Generate report using PG](https://img.youtube.com/vi/Y8gq1dwfzQU/0.jpg)](https://youtu.be/Y8gq1dwfzQU)
## Report generation using postgresql docker container made easy (3min): 
[![Import data and Generate report using PG docker container: made simple](https://img.youtube.com/vi/amPQRzz5D8Y/0.jpg)](https://youtu.be/amPQRzz5D8Y)