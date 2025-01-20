# Unlogged tables
Unlogged tables are the tables for which no WAL will be generated.  They are ephemeral
means data in the tables might be lost, if there is a crash / unclean-shutdown or a switchover to standbuy
Since there is no WAL records gets generated these taables won't be able to participate in replication. no data will be replicated.


## List of unlogged tables From pg_gather data

```
SELECT c.relname "Tab Name",c.relkind,r.tab_ind_size "Tab + Ind",ct.relname "Toast name",rt.tab_ind_size "Toast + T.Ind" 
FROM pg_get_class c
JOIN pg_get_rel r ON r.relid = c.reloid
LEFT JOIN pg_get_toast t ON r.relid = t.relid
LEFT JOIN pg_get_class ct ON t.toastid = ct.reloid
LEFT JOIN pg_get_rel rt ON rt.relid = t.toastid
WHERE c.relkind='r' AND c.relpersistence='u';
```

## List of unlogged tables from database
```
 SELECT c.relname,c.relkind,pg_total_relation_size(c.oid), tc.relname "TOAST",pg_total_relation_size(tc.oid) "TOAST + TInd"
 FROM pg_class c 
 JOIN pg_class tc ON c.reltoastrelid = tc.oid
 WHERE c.relkind='r' AND c.relpersistence='u'; 
```