# Data Security 
Data Security is an area of paramount importance when it comes to information collected for any reason. `pg_gather` is designed to address the security/data safety aspects from day one, and it is one of the project's primary objectives itself. Transparency is ensured for what is collected, transmitted and processed. The data collection script (`gather.sql`) is maintained as SQL only script to enhance the auditing requirements. A basic understanding of SQL is sufficient. No programming knowledge is required for auditing.
  
`pg_gather` collects only minimal **system catalog**, **performance**, **current session activity** and **configuration/parameter** information which are essential for analysis. Data stored within the user-defined or application-defined tables or indexes are **Never** accessed or collected. Even from the performance and catalog views, bare minimal information is collected. Please consider the same minimalistic approach are submitting Patches / Pull requests. 

Please refer the "information collected" section of this document for understading th data points 

# Information masking
Even though `pg_gather` collects only very minimal information from  **system catalog**, **performance**, **current session activity** and **configuration/parameter**, One might want to mask more details, especially in a highly secured environment. Since the `pg_gather` uses the TSV (Tab Separated Value) format for the collected,  any tool or editor with regular expression will be good for data masking/trimming before transmitting the data. Please, see the examples below. Please ensure that the "tab" characters, which are used as the separator, are preserved.

## 1. Masking SQL query statements from pg_stat_activity
By default, PostgreSQL removes bind values from query string before it is displayed in views like `pg_stat_activity`. So there is no visibility of data by default. Still, a user may not want to give a complete query string. Following is an example of truncating a query string to 50 characters using the `sed` utility before handing over the output file for analysis.
```
sed -i '
  /^COPY pg_get_activity (/, /^\\\./ {
    s/\(^[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]\{50\}\)[^\t]*\([\t.]*\)/\1\2/g
  }' out.txt
```
** Please remember that masking or trimming the query/statement will prevent us from understanding problematic queries and statements.
## 2. Masking client IP addresses
Any monitoring or analysis tool which accesses the `pg_stat_activity` for understanding the session activities can see the client IP addresses. Following sample `sed` command can be used for masking the part of the IP address, leaving only the last digit of the IPv4
```
sed -r -i 's/([0-9]{1,3}\.){3}([0-9]{1,3})/0.0.0.\2/g' out.txt
```
** IP addresses or the clients connecting to PostgreSQL is essential to understand those clients who are abusive. IP addresses give vital information about application servers which has poor connection pooling. Masking the IP addresses can prevent such analysis.

## 3. Masking SQL statements from pg_stat_statements
For removing all characters except first 50 characters, you may use sed expression like
```
sed -i '
  /^COPY pg_get_statements (/, /^\\\./ {
    s/\(^[^\t]*\t[^\t]*\t[^\t]\{50\}\)[^\t]*\([\t.]*\)/\1\2/g
  }' out.txt
```


## Information collected  (incomplete, work-in-progress)

1. The name of the database to which user is connected  
   uses built-in function of PostgreSQL : `current_database()`
2. Version of PostgreSQL  
   uses built-in function PostgreSQL : `version()`
3. Time of startup of PostgreSQL Instance  
   uses built-in function PostgreSQL : `pg_postmaster_start_time()`
4. Check whether PostgreSQL is in recovery mode  
   uses the built-in function PostgreSQL : `pg_is_in_recovery()`
5. IP address from the connection came  
   uses the built-in function PostgreSQL : `inet_client_addr()`
6. IP address of the Database host  
   uses the built-in function PostgreSQL : `inet_server_addr()`
7. Time of last reloading of parameter  
   uses the built-in function PostgreSQL : `pg_conf_load_time()`
8. Current LSN Position
   uses the built-in function PostgreSQL : `pg_current_wal_lsn()` or `pg_last_wal_receive_lsn()`
9. Information about the session activity
   uses `select * from pg_stat_get_activity(NULL)` which is similar to `pg_stat_activity`
10. Wait-event sampling
    uses information from `pg_stat_activity`
11. Information from `pg_stat_statements`
12. Number of transaction commits in each database
    uses the built-in function `pg_stat_get_db_xact_commit()`
13. Number of transaction rollbacks in each database
    uses the built-in function `pg_stat_get_db_xact_rollback()`
14. Number of blocks fetched to memory for each database
    uses the built-in function `pg_stat_get_db_blocks_fetched()`
15. Number of pages in cache which is hit by query execution
    uses the built-in function `pg_stat_get_db_blocks_hit()`
16. Number of tuples/rows returned per database
    uses the built-in function `pg_stat_get_db_tuples_returned()`
17. Number of tuples fetched per database
    uses the built-in function `pg_stat_get_db_tuples_fetched()`
18. Number of tuples inserted per database
   `pg_stat_get_db_tuples_inserted()`
19. Number of tuples updated per database
    `pg_stat_get_db_tuples_updated()`
20. Number of tuples deleted per database
    `pg_stat_get_db_tuples_deleted()` 

## Notes to users:
Appreciate independent audits and feedback. You are welcome to report any concerns that arise out of audits.