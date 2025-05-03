# Tablespaces
In PostgreSQL, each tablespace is a storage/mount point location.

Historically, Tablespaces were the only option for spreading the I/O load to multiple disk systems, which was the major use of tablespaces.
However, Advancements in LVM have made it less useful these days. LVMs are capable of striping data across different disk systems, which can give the total I/O bandwidth of all the storages put together.

## Checking the tablespaces
### From pg_gather data
```
 select * from pg_get_tablespace ;
```

## Directly from the database
```
SELECT spcname AS "Name",
  pg_catalog.pg_get_userbyid(spcowner) AS "Owner",
  pg_catalog.pg_tablespace_location(oid) AS "Location"
FROM pg_catalog.pg_tablespace
ORDER BY 1;
```

## Disadvantages of Tablespaces.
1. DBA will have higher responsibility for monitoring and managing each tablespace and space availability.
 Segregation of storage into multiple mount points can lead to management and monitoring complexities.
 Capacity planning needs to be done for each location.
2. PostgreSQL need to manage more metadata and dependent metadata in the primary data directory
3. Unavailability of single tablespace can affect the availabltiy of the entire cluster. We might be introducing more failure points by increasing the number of tablespaces
4. Standby cluster also need to have similar tablespaces and file locations.
5. Backup and recovery become more complex operations.In the event of a disaster, getting a replacement machine with a similar structure might be more involved.

## Uses of Tablespaces
Even though there is many disadvantages and maintenance overheads for using tablespaces, They can be useful for some of the senarios
1. Isolation of I/O load   
 There could be cases where we may want to avoid I/O load on specific tables not affecting the I/O operation on other tables.
2. Separate tablespace for temp  
 PostgreSQL allows the `temp_tablespaces` to use a different tablespace which is pointing to different mount point
3. Storage with different I/O characteristics  
 For example, we might want to move old table partitions to cheap, slow storage for archival purposes. If the number of queries hitting those old partitions is very rare, that could be a saving.
