# pg_gather Project

# History
In 2019, The author of the project @jobinau, decided to convert all his scripts, which he accumulated over decades working with PostgreSQL into a single script/tool, So that it will be beneficial for every novice users and DBAs of PostgreSQL.
Since it was a personal project, Initial couple of versions were purely private/personal and not available in Github. The work remained private/presonal for 1 more year. Later decided opensource it under PostgreSQL licence. In Jan 19, 2021, The Public Github project was created and code was published : https://github.com/jobinau/pg_gather/commit/1b7ccfc5222601adc2f3d27341db87cb780a4098
Every release there after is public : https://github.com/jobinau/pg_gather/releases

## Objective 1.  Clarity and auditability on what is collected
    
    Solution : Data collection need to be performed using simple SQL statements, preferably without any joins. SQL statements with complex joins are avoided wherever possible to improve the readability.
    User will be able to execute individual SQL statement and analyze what it collects.

## Objective 2. Avoid any observable load on the target database.

    Solution : Complex join / sort operations on the target database during the data collection can cause sudden spikes of load and cause further damange if the data is collected for any performance incident. Avoid it completely.
    Collect only the very essential data
    Offload the join/sort operation to different system where the data is analyzed.
    Thorughly test the load created by data collection before each release,
   
## Objective 3. Simplify data storage and transmission  

    Solution : Use TSV as the standard format to store the data collected. This gives excellent compression. Typical data collection can be stored in kilobytes.
    A simplified, compressed storage is important for continuous, repeated data collection.
    Moreover that makes it easy to transmit over mediums like email attachement easily.
    Every on-going development must make sure to collect only the minimum data as possible and store it in most effecient format feasible.

## Objective 4. Perform complex data analytics on the data collected.
    
    Solution : Import the collected into a a dedicated database and perform all complex data analytics. Modern SQL langaguage, Especially with latest reases of PostgreSQL as an analytical tool is very powerful, liverage it for performing data analyitics. As of writing this documentation, SQL features of PostgreSQL 14 or above is required.

## Objective 5. Run anywhere, Any OS, Processor Architecture, and use any authentication.

    Solution : Use `psql` - the commandline client of PostgreSQL as the platfrom. It is available in almost all Operating systems, architectures. It also support every possible authentication mechanism wich PostgreSQL support.

## Objective 6. Support every PostgreSQL versions which are currently supported
    Solution : Version detection is part of the data collection and the script changes the SQL statements according to the PostgreSQL version.

## Objective 7. Support Partial data collection
    Analytical queries are designed and tested to support collection of partial data. The project accepts that the data collection could be challenging in few enviroments and it may fail due to issues like permission.

## Objective 8 : Zero tolerance to bugs
    


# FAQ

## Why to separate the data analytics to a different Instance? why we can't perform on the taget database?
Ans : Complex queries with many Joins and Sort operations causes load on the target database. This is crutial when we are analyzing degraded performance cases. if we can more this analytical part and report generation to a seperate system, we can avoid causing any observable load by data collection.  
Another reason is Objective 4. The Modern SQL language, which is used for analytical work will be available only on new versions of PostgreSQL. Seperation of data collection and data analysis makes it possible to collect the data from older versions and perform analysis on a new version of PostgreSQL

## Why to store the collected data in TSV format
Ans : TSV is the standard format used in PostgreSQL. The format of `pg_dump` and `COPY` commands are TSV. TSV allows the users to audit the data, If required mask the data using UNIX tools like `sed`. Moreover TSV gies good compression.  
The compressed storage is important for continuous data collection and trasmission.
TSV facilitate the data loading to other systems / different database technologies if required.



