# Schema / Namespace

## From pg_gather data 
### 1. list of schema/namespace present in the database 
```
SELECT nsoid,nsname,
CASE  WHEN nsname IN ('pg_toast','pg_catalog','information_schema') THEN 'System'
 WHEN nsname LIKE 'pg_toast_temp%' THEN 'TempToast'
 WHEN nsname LIKE 'pg_temp%' THEN 'Temp'
ELSE 'User' END
FROM pg_get_ns;
```
### 2. Grops of Namespaces
```
WITH ns AS (SELECT nsoid,nsname,
CASE  WHEN nsname IN ('pg_toast','pg_catalog','information_schema') THEN 'System'
 WHEN nsname LIKE 'pg_toast_temp%' THEN 'TempToast'
 WHEN nsname LIKE 'pg_temp%' THEN 'Temp'
ELSE 'User' END AS nstype
FROM pg_get_ns)
SELECT nstype,count(*) FROM ns GROUP BY nstype;
```
### 3. List of Schema of "User" schema
List of schema which doesn't include temp or temp toast or system schema.  
Meaning, list of schema explicity created by users.
```
WITH ns AS (SELECT nsoid,nsname,
CASE  WHEN nsname IN ('pg_toast','pg_catalog','information_schema') THEN 'System'
 WHEN nsname LIKE 'pg_toast_temp%' THEN 'TempToast'
 WHEN nsname LIKE 'pg_temp%' THEN 'Temp'
ELSE 'User' END AS nstype
FROM pg_get_ns)
SELECT * FROM ns WHERE nstype='User';
```

### 4. Schema wise, count and size
```
WITH ns AS (SELECT nsoid,nsname
FROM pg_get_ns WHERE nsname NOT LIKE 'pg_temp%' AND nsname NOT LIKE 'pg_toast_temp%' 
    AND nsname NOT IN ('pg_toast','pg_catalog','information_schema')),
 sumry AS (SELECT r.relnamespace, count(*) AS "Tables", sum(r.rel_size) "Tot.Rel.size",sum(r.tot_tab_size) "Tot.Tab.size",sum(r.tab_ind_size) "Tab+Ind.size"
FROM pg_get_rel r
JOIN pg_get_class c ON r.relid = c.reloid AND c.relkind NOT IN ('t','p')
GROUP BY r.relnamespace)
SELECT nsoid,nsname,"Tables","Tot.Rel.size","Tot.Tab.size","Tab+Ind.size",pg_size_pretty("Tab+Ind.size") as "Size" 
FROM ns LEFT JOIN sumry ON ns.nsoid = sumry.relnamespace 
ORDER BY 6 DESC NULLS LAST;
```
** use JOIN instead of LEFT JOIN to eleminate emtpy schemas