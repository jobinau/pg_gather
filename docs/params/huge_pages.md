# huge_pages - Use Linux hugepages

### Warning: Critical Impact of Not Using Hugepages
Failure to implement Hugepages is a primary cause of stability and reliability issues in PostgreSQL database systems. Memory-related problems and out-of-memory (OOM) terminations are frequently reported in systems that do not utilize Hugepages. Additionally, connection issues and inconsistent execution times are also prevalent.
Without Hugepages, memory management and accounting become significantly more complex, leading to increased risk of system instability and performance degradation. The use of Hugepages is essential for optimal memory management and is a critical OS-level tuning requirement for handling database workloads. 
Failure to implement this feature may result in severe performance issues - occational drop in performance, stalls, connection failures and system instability.  

Detailed discussion of the importance of hugepages is beyond the scope of this summary info. Following blog post is highly recommend for further reading :
### [Why Linux HugePages are Super Important for Database Servers: A Case with PostgreSQL](https://www.percona.com/blog/why-linux-hugepages-are-super-important-for-database-servers-a-case-with-postgresql/)

## Warning about Missleading Benchmarks
Synthentic benchmarks often consideres only speed, without considering other stability / reliablity aspect of the database system on the long run. Many of the synthetic benchmarks may not be able to demonstrate any considerable speed difference after enabling Hugepages.

# Suggessions
1. Disable THP (Trasperent huge pages), preferably on the bootloader level of Linux
2. Eanable regular HugePages (2MB Size) with sufficient number of huge pages. Please refer the above blog post for details of the calculations.
3. Change the parameter `huge_pages` to `on` at PostgreSQL Instance to make sure that PostgreSQL will allocate sufficient huge pages on startup. It is good to prevent PostgreSQL startup with wrong settings, rather than a startup with wrong settings and troubles later.