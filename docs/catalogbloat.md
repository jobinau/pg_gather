# Catalog bloat
PostgreSQL metadata catalogs are where all database objects and their attributes are stored, such as tables, columns, indexes, and view definitions. The metadata includes permissions and statistics about each object, which are used for checking permissions, parsing SQL statements, and preparing the execution plan. It is important to keep the metadata size small for fast database response. Bloating can negatively affect the overall system performance.

## Causes
Bloating in PostgreSQL metadata catalogs can occur due to various reasons. Some of the common reasons are:

1. **Frequent DDLs:** This generally affects systems where DDL is issued from the application side. For example, OLAP systems creating staging tables and creating indexes after the data load. This bloat comes out of fragmentation.

2. **Heavy catalog created by multi-tenancy:** Multi-tenancy can cause several thousands of database objects, sometimes even hundreds of thousands. Multi-tenancy using a single catalog is not a great idea.

3. **Use of temporary tables:** Temporary tables in PostgreSQL work like regular tables in terms of metadata. Metadata about temporary tables will be added to the catalog and later removed when the usage of the temporary table is finished. This addition and removal leads to a lot of fragmentation. Extensive use of temporary tables is the most common reason for heavily bloated catalog tables.

## Detection.
In a healthy database, The total catalog size should be around 15 - 20 MB, Any size bigger than that can cause performance degradation. One might experinece poor responce from quries. `pg_gather` report can estimate the catalog size

Additionally You may use the bloat estimation SQL statement : https://github.com/jobinau/pgsql-bloat-estimation/blob/master/table/table_bloat.sql  
But remember to replace the line
```
AND ns.nspname NOT IN ('pg_catalog', 'information_schema')
```
with 
```
AND ns.nspname IN ('pg_catalog')
```

## Fixing the Bloat.
Performing a VACUUM FULL on the catalog tables is the remedy if the bloat is due to fragmentation. Generally there won't be any continuous DMLs on catalog tables. But better to performt he VACCUM FULL during a low activity window:
Connect to the right database using `psql` and run the following SQL to get the VACUUM FULL statements for each tables. You may add additional filters based on the bloat estimation as mentioned above.
```
SET statement_timeout='5s';
SELECT 'VACUUM FULL pg_catalog.'|| tablename || ';' FROM pg_tables WHERE schemaname = 'pg_catalog';
```
Then we should be able to run all the statments using `\gexec`

But if the bloat is due to very high number of database objects, there is no easy remedy than removing the unwated objects and avoiding multi-tenancy using single database.
