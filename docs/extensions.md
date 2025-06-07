# Over use of Extensions 

The benefits of extensions are highlighted and discussed more, while all adverse effects are ignored. Most users remain unaware of the cons, limitations, and consequences until they are hurt. 
Extensions have implications on performance, administrative/management overhead, the possibility of misconfigurations, and security and availability.

## Negative effects often reported:
The following are some commonly reported areas of trouble, which one should be aware of when using too many extensions.

* **PostgreSQL may fail to start**:  
Extensions can cause database unavailability if there are permission problems, corrupt library files, failing dependencies, library path problems, etc.
  For example:
```
 FATAL:  could not load library "/usr/pgsql-15/lib/pg_xxxxxxx.so": /usr/pgsql-15/lib/pg_xxxxxxx.so: cannot read file data
 ```
*An increase in startup time is also reported in some cases.  
* **Implications on High Availablity:**  
Automatic failover or switchover might be affected if libraries or extensions are missing on the candidate node. The DBA has the increased responsibility of keeping all candidate machines installed and configured with the same extensions and a similar configuration.

* **Slow connections:**  
Forking new backend processes becomes more costly as they inherit the preloaded libraries.

* **Memory Usage:**  
 Libraries loaded using `shared_preload_libraries` remain resident in memory for all server processes, increasing the base memory footprint. Affects the instruction cache.
 Some extensions allocate memory (in-memory ring buffer) in shared buffers to hold all the data they need.

* **CPU Usage :**  
 Additional code to execute causes more CPU usage.  
Some extensions even launch additional background processes also.

* **Conflict between extensions:**  
 This happens because extensions are developed by isolated groups of people and seldom tested with all other extensions.

* **Quality:**  
Unlike PostgreSQL, Extensions other than contrib modules are developed and maintained by small sets of indviduals, with limited very limited user bases, code auditing and reviews and QA. Obviously they more prone to more bugs. 

* **Stability/Availability:**  
Many incidents were reported about Bugs and other run-time problems of extensions, causing database outages (hangs and crashes). If an extension crashes, the session also crashes. PostgreSQL has no option but to restart.

* **PG Version Upgrade**  
Extensions are a frequent cause of trouble during version upgrades. DBA Need to be well aware of the extensions and their implications, much before any attempts for upgrades

* **Dependancy on other libraries:**  
Some of the extensions are developed using third-party libraries which need to be present in the system. Missing libraries and version conflicts are reported.

* **Security issues:**
Extensions have access to data and can cause vulnerabilities and security issues. Extensions which link to external libraries or use the network are considered more risky.

* **Tarball installations and immutable images**:  
Maintaining extensions on portable binary installations and immutable images are big challange. Because there won't be any help from package managers to ensure the integrity. Frequent problems are reported.

* **Extension version incompatibility**:  
Extensions are versioned separately, differently and released differently than PostgreSQL. It becomes an additional responsibility for DBAs to keep the extensions updated, ensuring compatibility.

* **Backup & Restore**  
Information about Extensions and versions used in each environment needs to be maintained, which is important for restoring the database to a new machine in an emergency. The new machine needs to have compatible binaries/packages of extensions installed.

## Sample Benchmarks for performance implications:
Even the widely used extensions like `pg_stat_statements` are reported to cause severe performance degradation on specific workloads.  For example:  
[How pg_stat_statements Causes High-concurrency Performance Issues](https://www.alibabacloud.com/blog/postgresql-v12-how-pg-stat-statements-causes-high-concurrency-performance-issues_597790)  
[pg_stat_statement can cause significant degradation for fast SELECT workload](https://www.linkedin.com/posts/samokhvalov_postgresql-activity-7211431755403210752-bUNx/)  
Proper independent benchmarking of extensions are rarely done.

## Suggesions/Recomendations.
* Avoid those extensions which are not very widely used, as they may introduce a bigger risk
* Extensions require more knowledge from DBAs. Ensure that experts are available who are knowledgeable about each extension before it is used.
* Be aware of the overhead, stability & availability issues, and security issues the extensions can cause.  
* Use extensions wherever and whenever it is unavoidable for business purposes.
* Periodically check the usage of extensions and DROP the extension whenever not in use and add it back when needed.

