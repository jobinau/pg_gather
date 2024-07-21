Requirements 
--------------------
1. No download cases. Database Servers may not have net connection and admins may not be allowed to download script from public net for using in production.
   Expected : Need to share the script over official mail / ticket
2. No executables allowed. Secured enviroment with security scanners and auditing in place.
   DBAs are allowed to execute simple SQL statements.
3. No password authentication - Peer / ssl certificate authentication
   The data collection tool should work with any PostgreSQL authentication 
4. Windows laptop and RDS instance.
   Windows client connecting to RDS
5. PostgreSQL on Windows
   Unix tools are completely helpless. 
6. Aurora and other PostgreSQL like softwares
   Many PostreSQL like softwares started appearing without full compatibility. many catalog views and stats views are missing. Tool should just skip over what is missing than a hard stop with error.
7. ARM processor - No information about the processor architecutre when customer reports a problem.
   For example, Customer just reports a problem like "database is slow". The data collection step should be independent of the processor architecture.
8. PG in Container and different shell.
   In addition to Shell, Unix tools / Perl scripts won't help as many of them are missing in many containers.
9.  Customer who collects data may not have privilege to execute query on many PostgreSQL views.
    Many SQL statments are expected to fail in unprivilaged user environrment. But tool should proceed with what it can.
10. Should be very light weight.  Completely avoid any complex analysis queries on the system to be scanned
    Practically Users have 2 vcpu machines with 4GB ram for their micro services.
11. Seperation of data collection and analysis
    Collected data should be available in row format for in-depeth analysis and complex SQL statements
12. The collected data should be captured in a smallest file possible. Eleminate every data redundancy over each version.
   