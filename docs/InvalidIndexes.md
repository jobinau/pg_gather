# Invalid Indexes 
Invalid Indexes are the corrupt unusable indexes, Which need to be dropped off or recreated

## Query to find Invalid indexes details from pg_gather data
```
SELECT ind.relname index, indexrelid indexoid,tab.relname table ,indrelid tableoid 
FROM pg_get_index i
LEFT JOIN pg_get_class ind ON i.indexrelid = ind.reloid
LEFT JOIN pg_get_class tab ON i.indrelid = tab.reloid
WHERE i.indisvalid=false;
```

## Query to find Invalid indexes from the current databasae
```
SELECT ind.relname index, indexrelid indexoid,tab.relname table ,indrelid tableoid, pg_get_indexdef(ind.oid)
FROM pg_index i
LEFT JOIN pg_class ind ON i.indexrelid = ind.oid
LEFT JOIN pg_class tab ON i.indrelid = tab.oid
WHERE i.indisvalid=false;
```