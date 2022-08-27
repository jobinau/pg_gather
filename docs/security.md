# Security 
`pg_gather` is desisgned to address the security / data safety concerns from the day one.   Security is one of the primary objective of this project. Data collection script (`gather.sql`) is maintained as SQL only script to enhance the auditing requirements. Basic understanding of SQL is sufficinet, No programming knowledge required for auditing.
  
`pg_gather` collects only minimal **system catalog**, **performance**, **current session activity** and **configuration/parameter** information which are essential for analysis. Data stored within the user tables or indexes are not accessed. Only minimal information is collected. Please consider the same minimilistic approch are submitting Patches / Pull requests. 

Please refer the "information collected" section of this document for each of the data point collected. 

# Information masking
Even though `pg_gather` collects only minimal details like **system catalog**, **performance**, **current session activity** and **configuration/parameter**, On systems where high security is followed, pg_gather allows , any tool or editor whith regular expression support to be used for removing informations which is not allowed to go out.  
For example,
## Masking query
By default, PostgreSQL removes bind values from query string bfore it is displayed in views like `pg_stat_activity`. So there is no visibility to data by default. Still users may not want give full query string also. Following is an example for truncating query string to 50 characters using `sed` utility. 
```
sed  -i 's/\(^[0-9]*\t[0-9]*\t[[:alnum:]]*\t[[:alnum:] .-_]*\t[[:alnum:] ]*\t[[:alnum:]\/\* :,-_`\o47"$]\{50\}\)[^\t]*\([\t.]*\)/\1\2/g' out1.txt
```
** Please remember that masking the query string will prevent us from understanding problematic queries and statments. So it is nto re
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