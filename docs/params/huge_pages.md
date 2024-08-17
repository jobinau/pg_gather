# huge_pages - Use Linux hugepages
Lack of hugepage usage is the No.1 reason for most of the OOM cases in PostgreSQL database systems
The memory management and accounting becomes much complex without hugepages.
Use of huge pages are considered as one of the most essential OS level tuning for databases
Detailed discussion of the importance of hugepages is beyond the scope of this documentation.  So I would recommend following blog post :
[Why Linux HugePages are Super Important for Database Servers: A Case with PostgreSQL](https://www.percona.com/blog/why-linux-hugepages-are-super-important-for-database-servers-a-case-with-postgresql/)

# Suggessions
1. Disable THP (Trasperent huge pages), preferably on the bootloader level of Linux
2. Eanable regular HugePages (2MB Size) with sufficient number of huge pages. Please refer the above blog post for details of the calculations.
3. Change the parameter `huge_pages` to `on` at PostgreSQL Instance to make sure that PostgreSQL will allocate sufficient huge pages on startup. It is good to prevent PostgreSQL startup with wrong settings, rather than a startup with wrong settings and troubles later.