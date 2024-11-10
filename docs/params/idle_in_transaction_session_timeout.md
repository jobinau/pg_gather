# idle_in_transaction_session_timeout

It is important to protect the system from "idle in transaction" sessions. The sessions which are not completing the transactions quickly are dangerous for the health of the database. The default value is zero (0) which disables this timeout and that is not a good configuration for most of the enviroments.
Such "idle in transaction" sessions are often found to cause blockages in databases, causing poor performance and even outages.
It is suggestable to timeout such sessions in 5 mintues **at the maximum**, hence the suggession
```
ALTER SYSTEM SET idle_in_transaction_session_timeout='5min';
```
Consider smaller values wherever applicable. 