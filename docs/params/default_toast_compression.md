# default_toast_compression
PostgreSQL allows users to select the compression algorithm used for TOAST compression from PostgreSQL version 14 onwards.
PostgreSQL historically used the built-in algorithm `pglz` as default. However algorithms like `lz4` showed significant performance gains [1].
PostgreSQL allow users to select the algorithm at a column basis; for example
```sql
CREATE TABLE tbl (id int,
 col1 text COMPRESSION pglz,
 col2 text COMPRESSION lz4,
 col3 text);
```
`lz4` is highly recommended for json datatypes
### Requirement:
In order to avail `lz4` as the compression algorithm, The PostgreSQL should be built with the configuration option `--with-lz4`. You may confirm the configuration options used for building 
```
pg_config | grep -i 'with-lz4'
```

## How to check the current toasting algorithm
Per-tuple,per-column toasting compression can be checked using `pg_column_compression()`.  
For example:
```
 select id,pg_column_compression(col3) FROM tbl ;
```

## How to change the toast compression
1. The compression method used for existing tuples won't chnage. Only newly inserted tuples will have the new compression method.
2. `VACUUM FULL` command or `pg_repack` WILL NOT change the compression algorithm. They cannot be used to alter the TOAST compression algorithm.
3. CREATE TABLE tab AS SELECT ... (CTAS) WILL NOT change the compression algorithm
4. INSERT INTO tab AS SELECT  also WILL NOT change the compression algorithm
5. Logical dump (`pg_dump`) and `pg_restore` can be used for changing the toast compression
6. Existing column values of tuples can be changed if there is an operation which requires detoasting the column
```
update tbl1 SET col3=col3||'' WHERE pg_column_compression(col3) != 'lz4';
# or
update tbl SET col3=trim(col3) WHERE pg_column_compression(col3) != 'lz4';
# or for json
update jsondat set dat = dat || '{}' where pg_column_compression(dat) != 'lz4';
```


## References
1. https://www.postgresql.fastware.com/blog/what-is-the-new-lz4-toast-compression-in-postgresql-14
2. https://stackoverflow.com/questions/71086258/query-on-json-jsonb-column-super-slow-can-i-use-an-index