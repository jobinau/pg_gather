# pg_gather
This is a SQL only script for gathering performance information from PostgreSQL databases.

The decision to develop and SQL-Only script was taken after assessing the limitations of with of other approches to collect info<br>
At the core of the requirement is that, If a PostgreSQL client (psql) is able to connect to PostgreSQL server, the data collection for the analysis should be possible.

# Major Features
1. Transperent / fully auditable code by the end user.<br>
   SQL only script is prefered over shell scripts, executable programs from readablity perspective, No Programming language skills needed.
2. No Executables are to be deployed<br>
    Using executables on a secured environments posses risks and not acceptable in may environments
3. Authentication agnostic<br>
   Any authentication mechanism which PostgreSQL supports should be acceptable for data gathering
4. Any Operating System and architecture.<br>
   Linux 32 / 64 bit, SunSolaris, MAC os, Windows On x86-64 bit, ARM, Sparc
5. Minimal data collection with a single file output.
6. Works with any cloud, DaaS, On-Prim 

# How to Use

## Data Gathering.
The configuration and Performance data can be gathered by executing the `gather.sql` against the database as follows
```
psql -f gather.sql > out.txt
```
One might have to specify additional connection information also in the psql as follows

```
 psql -h serverhost -U user -f gather.sql > out.txt
```
This output file contains all the information for analysis
## Data Analysis
The collected data can be imported to a PostgreSQL Instance as follows
```
sed -i '/^Pager/d; /^Tuples/d; /^Output/d; /^SELECT/d; /^PREPARE/d; /^$/d' out.txt; psql -f gather_schema.sql -f out.txt
```
The analysis report can be generated as follows
```
psql -q -X -f gather_report.sql > out.html
```