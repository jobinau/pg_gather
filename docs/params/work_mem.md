# work_mem

The setting of `work_mem` needs to be done very carefully. A big value can cause severe memory pressure on the server, slow down the entire database and even trigger out-of-memory (OOM) conditions. On the other hand,  A small value can result in many temporary file generations for specific SQL statements, resulting in more IO.  
So, the general advice is to avoid specifying more than 64MB at the instance level, which could affect all the sessions. However, there could be specific SQL statements which require higher `work_mem`; please consider setting a bigger value for those specific SQL statements with a lower scope. For example, The  value of `work_mem` can be specified at the transaction level such that the setting will have an effect only on that transaction
```
SET LOCAL work_mem = '200MB';
```
or at session level
```
SET work_mem = '150MB';
```

