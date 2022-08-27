# Data Security 
Data Security is an area of paramount importance when it comes to information collection for eighter analysis or monitoring. `pg_gather` is desisgned to address the security / data safety concerns from the day one and it is one of the primary objective of this project itself. Transperancy is ensured for what is collected, transmitted and processed. Data collection script (`gather.sql`) is maintained as SQL only script to enhance the auditing requirements. Basic understanding of SQL is sufficinet, No programming knowledge required for auditing.
  
`pg_gather` collects only minimal **system catalog**, **performance**, **current session activity** and **configuration/parameter** information which are essential for analysis. Data stored within the user-defined or application-defined tables or indexes are Never accessed or collected. Even from the performance and catalog views, bare minimal information is collected. Please consider the same minimilistic approch are submitting Patches / Pull requests. 

Please refer the "information collected" section of this document for understading th data points 

# Information masking
Even though `pg_gather` collects only very minimal information from  **system catalog**, **performance**, **current session activity** and **configuration/parameter**, One might want to mask more information, especially on a highly secured enviroment. Since the `pg_gather` uses the TSV (Tab Seperated Value) frormat for the collected,  any tool or editor whith regular expression can  be used for data masking / trimming.  berfore transmitting the data.  
For example,  
## 1. Masking SQL query statements
By default, PostgreSQL removes bind values from query string bfore it is displayed in views like `pg_stat_activity`. So there is no visibility to data by default. Still a user may not want give full query string. Following is an example for truncating query string to 50 characters using `sed` utility before handing over the output file for analysis.
```
sed  -i 's/\(^[0-9]*\t[0-9]*\t[[:alnum:]]*\t[[:alnum:] .-_]*\t[[:alnum:] ]*\t[[:alnum:]\/\* :,-_`\o47"$]\{50\}\)[^\t]*\([\t.]*\)/\1\2/g' out.txt
```
** Please remember that masking or trimming the query/statement will prevent us from understanding problematic queries and statments. So it is not a recommended pratice.
## 2. Masking client IP addresses
Any monitoring or analysis tool which access the `pg_stat_activity` for understanding the session activities can see the client IP addresses . Following `sed` command can be used for masking the part of IP address
```
sed -r -i 's/([0-9]{1,3}\.){3}([0-9]{1,3})/0.0.0.\2/g' out.txt
```
** IP addresess or the clients connecting to PostreSQL is important to understand those clients which are abusive. IP addresses gives vital information about application servers which has poor connection pooling. Masking the IP addresss can prevent many such analysis.

## Information collected  

1. The name of the database to which user is connected  
   uses built-in function of PostgreSQL : `current_database()`
2. Version of PostgreSQL  
   uses built-in function PostgreSQL : `version()`
3. Time of startup of PostgreSQL Instance  
   uses built-in function PostgreSQL : `pg_postmaster_start_time()`
4. Check whether PostgreSQL is in recovery mode  
   uses the buit-in function PostgreSQL : `pg_is_in_recovery()`
5. IP address from the connection came  
   uses the built-in function PostgreSQL : `inet_client_addr()`
6. IP address of the Database host  
   uses the buit-in function PostgreSQL : `inet_server_addr()`
7. Time of last reloading of parameter  
   uses the buit-in function PostgreSQL : `pg_conf_load_time()`
8. Current LSN Position
   uses the buit-in function PostgreSQL : `pg_current_wal_lsn()` or `pg_last_wal_receive_lsn()`



## Notes to users:
Appreiciate independent audits and feedback. You are welcome to report any concerns arrises out of audits.