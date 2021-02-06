# pg_gather
This is a SQL-only script for gathering performance and configuration data from PostgreSQL databases.

A SQL-Only script addresses the limitations of other means to collect data<br>
If a PostgreSQL client (psql) is able to connect to a PostgreSQL server, This works.

**Supported Versions** : PostgreSQL 10, 11, 12 & 13  
**Minimum support versions** : PostgreSQL 9.5, 9.6

# Features
1. Transperent / fully auditable code for the end user.<br>
   A SQL-only script is prefered over shell scripts, executable programs from end user readablity perspective, No Programming language skills needed.
2. No Executables are to be deployed<br>
    Usage of executables on a secured environments posses risks and not acceptable in many environments
3. Authentication agnostic<br>
   Any authentication mechanism which PostgreSQL supports should be acceptable for data gathering. So if `psql` is able to connect, data for analysis can be collected.
4. Any Operating System and architecture.<br>
   Linux 32 / 64 bit, SunSolaris, MAC os, Windows On x86-64 bit, ARM, Sparc
5. Minimal data collection with a single file output.
6. Works with any cloud, DaaS, On-Prim 

# How to Use

## Data Gathering.
Inorder to gather the configuration and Performance information, the `gather.sql` script need be executed against the database using `psql` as follows
```
psql -f gather.sql > out.txt
```
This script may take 20+ seconds to execute as there are sleeps/delays within. You may provide additional psql command line options if it is required in our environment. Please mention the database name also wherever relevant.
For example,
```
 psql -h serverhost -U user dbname -f gather.sql > out.txt
```
This output file contains all the information for analysis  
**Note:-** There is a seperate `gather_old.sql` form minimum support versions 9.5 and 9.6

## Data Analysis
The collected data can be imported to a PostgreSQL Instance as follows
```
sed -i '/^Pager/d; /^Tuples/d; /^Output/d; /^SELECT/d; /^PREPARE/d; /^$/d' out.txt; psql -f gather_schema.sql -f out.txt
```
The analysis report can be generated as follows
```
psql -q -X -f gather_report.sql > out.html
```