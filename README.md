# pg_gather
This is a SQL only script for gathering performance information from PostgreSQL databases.

The decision to develop and SQL-Only script was taken after exeprimenting with couple of other approches <br>
At the core of the requirement is that, If a PostgreSQL client (psql) is able to connect to PostgreSQL server, the data collection should be completed successfully.

# Major Features
1. Transperent / fully auditable code by the end user.<br>
   SQL only script is prefered over shell scripts, executable programs from readablity perspective, No Programming language skills needed.
2. No Executables are to be deployed<br>
    Using executables on a secured enviroment posses risks and not acceptable in may environments
3. Authentication agnostic<br>
   Any authentication mechanism which PostgreSQL supports should be acceptable for data gathering
4. Any Operating System and architecture.<br>
   Linux 32 / 64 bit, SunSolaris, MAC os, Windows On x86-64 bit, ARM, Spark 
5. Minimal data collection with a single file output.
6. Works with any cloud, DaaS, On-Prim 

