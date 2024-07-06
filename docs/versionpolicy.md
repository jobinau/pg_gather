# pg_gather version policy

Each pg_gather release invalidates all the previous versions. Data collections using older versions may or may not work with new analytical logic and can result in misleading inferences.  There will be many corrections and improvements with every release. You may refer to the [release notes](https://github.com/jobinau/pg_gather/releases) for details.  
So, it is always important to use the latest version, and using older versions is highly discouraged. 
All PostgreSQL server versions above 10 are supported. However, the client utility : `psql` should be of minimum version 11