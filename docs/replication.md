# Replication
This analysis collects information from `pg_stat_replication` and `pg_replication_slots`

## Report details explained
Uniits used are : 1. Bytes for "Size"   2. XMIN differences with latest known XMINs for all "Age"


## Base pg_gather tables
1. pg_replication_stat
2. pg_get_slots

Raw Information imported in to above mentioned tables can be used for direct SQL queries.
In case of partial and continuous gather, the information will be imported to tables with same name in `history` schema