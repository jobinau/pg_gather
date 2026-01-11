# Orphan files in PostgreSQL

Orphan files are those files in PostgreSQL tablespaces (default, global and other locations) which don't have corresponding catalog entries.
So PostgreSQL won't be aware that such file exists

## What causes orphan files 
Orphan files can come to existance due to verious reasons like
* Crashes During Physical Operations
  * Failed VACUUM FULL or CLUSTER commands. These commands create a brand-new copy of a table. If the server crashes or runs out of disk space halfway through, the partially created file remains on disk, but the database catalogs still point to the old version.
  * Interrupted CREATE TABLE / INDEX. If a transaction creates a new relation but the server crashes before it can commit, the physical file might be left behind.
* Failovers during operations
  * Systems which undergoes frequent failovers have high chance of orphan files. Agressive HA solution settings are to be avoided.
* Process Termination (kill -9)
  * Even if not a full database crash, The session which generates the file is getting terminated due to reasons like OOM, there is high chance of orphan files. Many times such events goes unoticed because PostgreSQL does the automatic recovery.
* Out-of-Disk-Space Errors
* Tablespace Migration Failures
* Large Object (LOB) Neglect
* Limitations of backup/restore and restore tools, or faulty procedure
  * Orphan files are commom when backups are restored. Use only reliable backup tool like `pgBackRest`
* Accidentl file copy to PostgreSQL datadirectory or tablespace locations
  * Human errors can leave unwanted files inside data directory
 
## What problems it may cause
* Orphan files can occupy considerable amount of size and can cause storage running out of space.
* Once a orphan file gets generated, there is high chance that the same file gets copied to all the replica on rebuild operaton. system may start accumuating orphan files
* Increases the Standby rebuild time
* Affects the storage of the backup repository. Depends on how many full backups are retained.
* Affects database restores
* PostgreSQL upgrades and post upgrade procedures to remove old data directory may have suprise.

## How to findout orphan files
Following SQL statement might help to findout orphan files related to particular database to which the session is connected.
* If there are multiple databases, please connect to each of them and check.
* This SQL statement requires Superuser privileges.

```sql
-- Findout orphan files which don't have catalog entries  | Last revision : Jobin Augustine 11-1-2026
-- Works ONLY for PG 10 and later
-- May not work for MS Windows
WITH 
cat AS ( -- Get catalog informations
SELECT catalog_version_no
  ,left(current_setting('server_version_num'),2) pgver
  ,current_setting('data_directory') datadir
  , (SELECT dattablespace FROM pg_database WHERE datname = current_database()) AS default_tablespace
  FROM pg_control_system())
, tsoid AS ( -- Get tablespace OIDs used by the current database
  SELECT dattablespace FROM pg_database WHERE datname = current_database()
    UNION ALL
  SELECT DISTINCT reltablespace FROM pg_class)
, paths AS ( --Findout all directory paths to check
  SELECT t.oid
    ,CASE 
        WHEN t.spcname = 'pg_default' THEN cat.datadir || '/base/' || d.oid
        WHEN t.spcname = 'pg_global'  THEN cat.datadir || '/global'
        ELSE pg_tablespace_location(t.oid) || '/PG_' || cat.pgver || '_' || cat.catalog_version_no || '/' || d.oid
    END AS dirpath
FROM tsoid ts
JOIN pg_tablespace t ON t.oid = ts.dattablespace
JOIN pg_database d ON d.datname = current_database()
JOIN cat ON true)
, catalog_files AS ( --Calculate possible filenames from catalog
    SELECT dirpath || '/' || relfilenode AS catfilename
FROM
    (SELECT relfilenode::text --Regular relations
    , CASE 
        WHEN reltablespace = 0 THEN (SELECT default_tablespace FROM cat)
        ELSE reltablespace 
    END AS tablespace_oid FROM pg_class WHERE relfilenode > 0   
    UNION
    SELECT t.relfilenode::text --TOAST relations
    , CASE 
        WHEN t.reltablespace = 0 THEN (SELECT default_tablespace FROM cat)
        ELSE t.reltablespace 
    END AS tablespace_oid FROM pg_class c JOIN pg_class t ON c.reltoastrelid = t.oid WHERE t.relfilenode > 0
    UNION
    SELECT pg_relation_filenode(oid)::text --Global/Shared relations
    ,CASE 
        WHEN reltablespace = 0 THEN (SELECT default_tablespace FROM cat)
        ELSE reltablespace 
    END AS tablespace_oid FROM pg_class WHERE relfilenode = 0 AND pg_relation_filenode(oid) IS NOT NULL) as catfilenodes
    JOIN paths ON paths.oid = catfilenodes.tablespace_oid
)
SELECT pathfilename,(pg_stat_file(pathfilename)).*
 FROM ( -- List of files directly from the file system
  SELECT paths.dirpath || '/' || pg_ls_dir(paths.dirpath) AS pathfilename,pg_ls_dir(paths.dirpath) AS fname
 FROM paths) AS allfiles
LEFT JOIN catalog_files ON replace(pathfilename, catfilename, '') ~ '^(_vm|_fsm|\.?[0-9]+)?$'
WHERE catalog_files.catfilename IS NULL
AND pathfilename !~ '/(pg_internal\.init|PG_VERSION|pg_filenode\.map|pg_control)$';
```

## How to remove orphan files
### IMPORTANT : Be Careful and safe
It could be a disaster If we delete a file which is actually needed by PostgreSQL. 
Please consider the following points to remove the unwanted files and reclaim the space. 
#### Ongoing Transactions: 
If a VACUUM FULL or INDEX creation is currently running, the files it creates will appear as orphans because they haven't been "committed" to the catalogs yet. 
Never delete files while the database is under heavy DDL load, Risk will be high.

#### The "Double Check" Rule: 
Collect the data about orphan files at two different times and compare them to make sure that we are not considering any temporary changes/files. Make sure that there is no long running sessions / statements are running in the system while collecting the data.
If you find an orphan file, move it to a temporary directory outside of the PostgreSQL path first. Wait a few days and restart the service. If everything remains stable, only then delete the file.

#### Compare with Standby (if Physical standby exists)
Comparing with orphan files on standby databases can reveal whether the file existing only on Primary or Standby

#### Clean orphan files on Standby first (if Physical standby exists)
Accidently removing the file from Pimary instance could be risky. It is safer do the cleanup work on the standby first,  if same orphan file exists on both Prirmary and Standby.


