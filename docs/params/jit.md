# jit (Just In Time compilation)
PostgreSQL is capable of doing just in time compilation of the SQL statements from PostgreSQL version 12.  
This uses LLVM infrasructure available on the host machine.
However, Due to initial compilation overhead, it is seldom gives any advantage. There could be very specific cases where this gives some advantage.

# Disadvantages
1. Very rarely it gives any performance advatage.
2. LLVM infra can cause memory and CPU overhead.
3. Memory leaks are reported.
4. JIT is reported to cause crash in few enviroments.

# Suggession
1. Disable JIT at global level (At instance level)
2. If there are specific SQL statements which has some advatage in terms of performance, Plase consider enabling the parameter at lower scope (At transaction level or Session level). [PostgreSQL Parameters: Scope and Priority Users Should Know](https://www.percona.com/blog/postgresql-parameters-scope-and-priority-users-should-know/)
   
## Additional references
1. [backend crash caused by query in llvm on arm64](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1059476)
2. [BUG #18503: Reproducible 'Segmentation fault' in 16.3 on ARM64](https://www.postgresql.org/message-id/flat/18503-6e0f5ab2f9c319c1%40postgresql.org)