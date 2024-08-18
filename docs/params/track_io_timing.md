# track_io_timing - Capture timing information of I/O
PostgreSQL will caputre and populate I/O related counters if this parameter is enabled.  
This parameter is `off` by default, as it will repeatedly query the operating system for the current time, which may cause significant overhead on some platforms.  
However most of the modern CPUs (Intel/AMD and ARM) for database servers, the overhead is very low.

# Suggession
Run the `pg_test_timing` which comes along with the PostgreSQL installation.
Please proceed to enable this parameter ("on"). If the results indicates that 95% of the calls has less than 1 microsecond delay
Here is a sample result
```
$pg_test_timing
Testing timing overhead for 3 seconds.
Per loop time including overhead: 22.23 ns
Histogram of timing durations:
  < us   % of total      count
     1     97.78015  131942883
     2      2.21770    2992526
     4      0.00196       2643
     8      0.00018        245
    16      0.00001         13
    32      0.00000          3
```

# Benefit
The additional information it catpures enables users to undstand I/O related latency better.  
1. I/O timing information is displayed in `pg_stat_database`, `pg_stat_io`
2. I/O timing information in the output of EXPLAIN when the BUFFERS option is used, 
3. I/O timing information in the output of VACUUM when the VERBOSE option is used, by autovacuum for auto-vacuums and auto-analyzes, when log_autovacuum_min_duration is set and by pg_stat_statements
