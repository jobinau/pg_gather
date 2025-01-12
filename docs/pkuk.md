# Primary Key and Unique Keys

**Primary Key (PK)** defines how to uniquely identify a record in a table. If a record cannot be idenfied uniquely, then there is no meaning in storing it the table.
So conceptually Primary Key is mandatory for any table, even if database systems won't enforce it.  
**Unique Keys (UK)** are conceptually refered as "Candiate Keys" - Candidates for using as them as Primary Key  
PostgreSQL maintains B-Tree index for each of them.

## Use of Keys
Following are some of the benefits
1. Ensuring the integrity of data.
2. Improve the query performance, because keys are often used for joins and lookups.
3. In Logical replications as an identitty column
4. Tools like `pg_repack` uses them for functionality

# Tables without PK and UKs
## From pg_gather data.
```
WITH idx AS (SELECT indrelid, string_agg(ci.relname,',') FILTER (WHERE indisprimary) primarykey,  
  string_agg(ci.relname,chr(10)) FILTER (WHERE indisunique AND NOT indisprimary) uniquekey
, string_agg(ci.relname,chr(10)) FILTER (WHERE NOT indisunique AND NOT indisprimary) index
FROM pg_get_index i join pg_get_class ci ON i.indexrelid = ci.reloid 
GROUP BY indrelid)
-- SELECT the required fields.
SELECT c.relname "table", primarykey, uniquekey, index 
FROM pg_get_class c LEFT JOIN idx ON c.reloid = idx.indrelid WHERE c.relkind IN ('r')
-- Filter to see the tables without primary key or unique key.
AND primarykey IS NULL AND uniquekey IS NULL;
```
## Directly from database
```
WITH idx AS (SELECT indrelid, string_agg(ci.relname,',') FILTER (WHERE indisprimary) primarykey,  
  string_agg(ci.relname,chr(10)) FILTER (WHERE indisunique AND NOT indisprimary) uniquekey
, string_agg(ci.relname,chr(10)) FILTER (WHERE NOT indisunique AND NOT indisprimary) index
FROM pg_index i join pg_class ci ON i.indexrelid = ci.oid 
GROUP BY indrelid)
-- SELECT the required fields.
SELECT c.relname "table", primarykey, uniquekey, index 
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace AND nspname NOT IN ('pg_catalog', 'information_schema')
LEFT JOIN idx ON c.oid = idx.indrelid WHERE c.relkind IN ('r') and c.relname NOT LIKE 'pg_toast%'
-- Filter to see the tables without primary key or unique key.
AND primarykey IS NULL AND uniquekey IS NULL;
```
