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
### 3. Schema of a specific type, for example "User" schema
```
WITH ns AS (SELECT nsoid,nsname,
CASE  WHEN nsname IN ('pg_toast','pg_catalog','information_schema') THEN 'System'
 WHEN nsname LIKE 'pg_toast_temp%' THEN 'TempToast'
 WHEN nsname LIKE 'pg_temp%' THEN 'Temp'
ELSE 'User' END AS nstype
FROM pg_get_ns)
SELECT * FROM ns WHERE nstype='User';
```

