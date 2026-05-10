## Locks
Generally, Total locks used in database is highly unpredictable and spiky. So at any observable times exceeding 1/10th of the total possible locks in the shared lock table is considered as risky. Increase the value of `max_locks_per_transaction` to increase the value of total available locks in the shared lock table, which is cacluated like:
```
size of the shared lock table  = max_locks_per_transaction × (max_connections + max_prepared_transactions).
```