# pg_gather
This is a SQL-only script for gathering performance and configuration data from PostgreSQL databases 

A SQL-Only script addresses the limitations of other means to collect data<br>
This requires only `psql` (PostgreSQL client tool) connectivity to server

**Supported Versions** : PostgreSQL 10, 11, 12 & 13  
**Minimum support versions** : PostgreSQL 9.5, 9.6


# Highlights
1. **Secure by Open :** Simple, Transperent, Fully auditable code.<br>
   A SQL-only script is prefered over shell scripts, executable programs from end user readablity perspective, No Programming language skills needed.
2. **No Executables** are to be deployed on the database host<br>
    Usage of executables on a secured environments posses risks and not acceptable in many environments
3. **Authentication agnostic**<br>
   Any authentication mechanism which PostgreSQL supports should be acceptable for data gathering. So if `psql` is able to connect, data for analysis can be collected.
4. **Any Operating System** <br>
   Linux 32 / 64 bit, SunSolaris, MAC os, Windows
5. **Architecture agnostic**<br>
   x86-64 bit, ARM, Sparc, Power etc
6. **Minimal data collection** with a single text file with Tab Seperated Values (TSV)
7. **Any cloud** : Works with AWS RDS, Google Cloud SQL, On-Prim etc<br> 
   (Hiroku specific restrictions are addressed. Please see the note below)

# How to Use

## Data Gathering.
Inorder to gather the configuration and Performance information, the `gather.sql` script need be executed against the database using `psql` as follows
```
psql <connection_parameters_if_any> -X -f gather.sql > out.txt
```
This script may take 20+ seconds to execute as there are sleeps/delays within. <br>
Recommended running the script as a privileged user (`superuser`, `rds_superuser` etc) or some account with `pg_monitor` privilege.  

This output file contains performance and configuration data for analysis  

## Notes: 
   1. There is a seperate `gather_old.sql` for older minimum support versions 9.5 and 9.6
   2. Heroku like DaaS hostings imposes very high restrictions on collecting performance data. query on views like pg_statistics may produce errors during the data collection. which can be ignored
   3. Windows users!, client tools like [pgAdmin](https://www.pgadmin.org/) comes with `psql` along with it. which can be used for running `pg_gather` against local or remote databases. For example
   ```
     "C:\Program Files\pgAdmin 4\v4\runtime\psql.exe" -h pghost -U postgres -f gather.sql > out.txt
   ```

## Data Analysis
The collected data can be imported to a PostgreSQL Instance as follows
```
sed -e '/^Pager/d; /^Tuples/d; /^Output/d; /^SELECT pg_sleep/d; /^PREPARE/d; /^\s*$/d' out.txt | psql -f gather_schema.sql -f -
```
The analysis report can be generated as follows
```
psql -X -f gather_report.sql > GatherReport.html
```
