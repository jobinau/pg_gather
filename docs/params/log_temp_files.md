# log_temp_files
Heavy SQL statements which fetch large volumes of data and perform join or sort operations on that data may not be able to fit the data into `work_mem`, and consequently, PostgreSQL may spill it to disk. These files are called temp files. This could result in unwated I/O and performance degradation in PostgreSQL.The parameter `log_temp_files`  will help generate entries in the PostgreSQL log with details of the SQL statement that caused the temp file generation. Setting this value to "0" might cause a lot of entries in PostgreSQL log and resulting in big size log files.
## Recommendation
All SQL statements that generate excessive temp files need to be identified and addressed. Some of the SQL statements might need to be rewritten. Those statements that cannot be further simplified but need more `work_mem` needs special attention. Please refer to the [work_mem](work_mem.md) section for further details on how to handle this. In order to identify the problematic SQL statements, Start with those SQL statements which generate more than 100MB files
```
log_temp_files = '100MB';
``` 
Once all those queries are addressed,  this size can be further reduced to `50MB`. Keep reducing until objective is achived.

## References
1. [PostgreSQL documentation on log_temp_files](https://www.postgresql.org/docs/current/runtime-config-logging.html#GUC-LOG-TEMP-FILES)
2. [AWS documentation](https://docs.aws.amazon.com/prescriptive-guidance/latest/tuning-postgresql-parameters/log-temp-files.html)