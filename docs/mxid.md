# Multi Transaction ID

PostgreSQL uses Multi Transaction ID when multiple sessions want to keep a lock on the same row (shared lock). 
High use of Multi Transaction IDs are indications of contention and lenghty transactions which are problematic for concurrency.
The Multi Transaction ids are stored seperately on the disk. This could result in additional I/O
Multiple sessions aquiring lock on the same row need to be reduced as much as possible for better performance and stabilty.

## Investigating further

### pg_gather

Watch out for `MultiXact`* wait events in the pg_gather data. if they appear whe have a problem to address.

pg_gather collects only DB level multi transaction id ages, This can be checked like
```
SELECT datname, mxidage FROM pg_get_db;
```

### From DB catalog
More object level investigation is possible using the catalog information
```
SELECT datname,mxid_age(datminmxid) FROM pg_database;
```
Individual table level mxid age can be checked from `pg_class`
```
SELECT relname,mxid_age(relminmxid) FROM pg_class WHERE relkind = 'r';
```

# What causes 
## Foreign Key checks to Parent table
When data is inserted into child table, The tansaction that is  doing the `INSERT` will take a `FOR KEY SHARE` lock on the parent record. So if there are lot of INSERT satements refering to the same parent record, PostgreSQL don't have much option than using Multi-TransactionID
## Lengthy transactions.
Transactions which are taking time could result in Multi-Transaction IDs and conflict with other sessions. 

# Suggessions
1. Use Foreign Key checks only when database side data integrity checks are absolute necessary. Those checks can become costly.
2. Batch the transactions instead of individual small transactions in parallel. On transaction requires only one transaction id, irrespective of the size of the transaction.
3. Commit transactions as quick as possible. Watch out for `ClientRead` wait events
4. Use modern SQL features like WITH clause , MERGE statements to replace many of the complex programm code.
5. Use `COPY` command instead of `INSERT` statements when large number of records are to be inserted.
   
## Additional References
[Avoid Postgres performance cliffs with MultiXact IDs and foreign keys](https://pganalyze.com/blog/5mins-postgres-multiXact-ids-foreign-keys-performance)  
[Notes on some PostgreSQL implementation details](https://buttondown.com/nelhage/archive/notes-on-some-postgresql-implementation-details/)