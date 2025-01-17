# Unlogged tables
Unlogged tables are the tables for which no WAL will be generated.  They are ephemeral
means data in the tables might be lost, if there is a crash / unclean-shutdown or a switchover to standbuy
Since there is no WAL records gets generated these taables won't be able to participate in replication. no data will be replicated.


## List of unlogged tables From pg_gather data

```
SELECT relname,relkind,tab_ind_size FROM 
pg_get_class c
JOIN pg_get_rel r ON r.relid = c.reloid 
WHERE relkind='r' AND relpersistence='u';
```

## List of unlogged tables from database
```
SELECT relname FROM pg_class WHERE relpersistence = 'u';
```