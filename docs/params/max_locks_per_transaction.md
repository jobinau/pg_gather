# max_locks_per_transaction - and why it matters far more from PostgreSQL 18

Most DBAs know `max_locks_per_transaction` only as *"the parameter to bump when I get `out of shared memory ... You might need to increase max_locks_per_transaction`"*.

That is only half of the story - and from **PostgreSQL 18 it is the less interesting half**. Starting with PG 18, this same parameter also controls the size of the **fast-path lock** array of every backend, which decides whether your queries take locks cheaply in process-local memory or fight each other on the `LWLock:LockManager` shared lock manager.

This is one of the very few parameters where a **major version upgrade changes what the parameter does**, so it deserves attention.

---

## 1. The classic role : sizing the shared lock table

The shared lock table is allocated once, at instance startup, in shared memory:

```
size of the shared lock table = max_locks_per_transaction × (max_connections + max_prepared_transactions)
```

As the [documentation](https://www.postgresql.org/docs/current/runtime-config-locks.html#GUC-MAX-LOCKS-PER-TRANSACTION) says, this limits the **average** number of object locks per transaction - individual transactions may lock far more objects as long as everything fits in the global table.

Because the allocation is fixed at startup, PostgreSQL cannot grow it on the fly. When the pool is exhausted:

```
ERROR:  out of shared memory
HINT:  You might need to increase max_locks_per_transaction.
```

Changing the parameter **requires a restart**.

See [Locks](../locks.md) and [Partitioning in PostgreSQL](../partition.md) for the lock-consumption math with partitioned tables.

---

## 2. The fast-path lock : the part that decides performance

### What is a fast-path lock?

Taking a lock through the shared lock table is not free. The lock manager is protected by a set of LWLocks (the lock hash is split into 16 partitions), so every lock/unlock has to enter shared memory and serialize with every other backend hashing to the same partition. At high concurrency, this is a scalability wall.

Since PostgreSQL 9.2 there is an optimization for this: **fast-path locking**. A backend can record a lock in a **small private array inside its own process descriptor (PGPROC)** instead of the shared lock table. It is protected only by that backend's own `fpInfoLock`, so there is effectively **zero cross-backend contention**.

Fast-path locking applies only when all of the following are true:

* The lock is on a **relation** (table, index, partition, materialized view) - not a tuple lock, transaction ID lock, advisory lock etc.
* The lock mode is **weak**: `AccessShareLock`, `RowShareLock`, `RowExclusiveLock`. In other words the everyday `SELECT` / `INSERT` / `UPDATE` / `DELETE` locks.
* **No strong lock** (`ShareLock` and above, e.g. from `CREATE INDEX`, `VACUUM FULL`, most `ALTER TABLE`, `REINDEX`) is held or pending on that relation. PostgreSQL tracks this with an array of 1024 counters (`FastPathStrongRelationLocks`); a non-zero counter for the relation's hash group disables the fast path for it.
* There is a **free slot** in the backend's fast-path array.

The last condition is where the trouble starts.

### The 16-slot cliff (PostgreSQL 9.2 to 17)

Up to PostgreSQL 17, the array size is a **compile-time constant**:

```c
#define FP_LOCK_SLOTS_PER_BACKEND   16     /* PG 9.2 - 17, hardcoded */
```

**16 relation locks per backend. Not configurable. Not affected by `max_locks_per_transaction`.**

The 17th and every subsequent relation lock of that backend falls back to the shared lock table. The result is a genuine performance cliff, not a gentle slope:

* `LWLock:LockManager` becomes the dominant wait event.
* The damage lands on **planning time**, not execution time - the planner opens and locks every relation in the query tree. Execution time typically stays flat while planning latency explodes.
* It gets worse with concurrency, so it shows up exactly when the system is busy.

### Why 16 slots is nothing for real schemas

The count is of **relations**, and every index is a separate relation. A single plain table with a primary key already consumes 2 slots.

| Object touched by a single query | Fast-path slots consumed |
|---|---|
| Table + primary key index | 2 |
| Table with 15 indexes | 16 - **already at the limit** |
| Partitioned parent + 20 partitions, 2 indexes each | 1 + 20 + 40 = **61** |
| Same, joined against another partitioned table | doubles again |

Additional amplifiers:

* **Poor partition pruning** - if the planner cannot prune at plan time, it locks *all* partitions and *all* their indexes.
* **Parallel query** - every parallel worker is an independent backend with its **own** 16 slots, and it re-opens and re-locks the relations it is assigned. Lock consumption multiplies with the worker count.
* **Prepared statements / generic plans** - the whole plan tree gets locked.

This is exactly why heavily partitioned schemas hit `LWLock:LockManager` contention so reliably on PG 17 and older.

### The critical PG ≤ 17 caveat

On PostgreSQL 17 and older, **raising `max_locks_per_transaction` does absolutely nothing for `LWLock:LockManager` contention.** It only makes the shared lock table bigger, so it prevents the `out of shared memory` error. The fast-path limit stays at 16, hardcoded.

The only real remedies on those versions are schema-level: fewer partitions per query (better pruning), fewer indexes, and less parallelism.

---

## 3. What changed in PostgreSQL 18

PostgreSQL 18 commit [`c4d5cb71d`](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commitdiff;h=c4d5cb71d) (Tomas Vondra) replaced the fixed 16-slot inline array with a **variable-sized array in separate shared memory**, organized as a **16-way set-associative cache**:

```c
#define FP_LOCK_GROUPS_PER_BACKEND_MAX  1024
#define FP_LOCK_SLOTS_PER_GROUP         16      /* don't change */
#define FP_LOCK_SLOTS_PER_BACKEND \
        (FP_LOCK_SLOTS_PER_GROUP * FastPathLockGroupsPerBackend)
```

At startup the number of groups is derived from `max_locks_per_transaction`:

```c
FastPathLockGroupsPerBackend = 1;
while (FastPathLockGroupsPerBackend < FP_LOCK_GROUPS_PER_BACKEND_MAX)
{
    if (FastPathLockGroupsPerBackend * FP_LOCK_SLOTS_PER_GROUP >= max_locks_per_xact)
        break;
    FastPathLockGroupsPerBackend *= 2;
}
```

In plain words: **the number of fast-path slots per backend is `max_locks_per_transaction` rounded up to the next power-of-two multiple of 16, capped at 16384.**

| `max_locks_per_transaction` | Groups | Fast-path slots per backend |
|---:|---:|---:|
| 16 | 1 | 16 (same as PG 17) |
| 64 *(default)* | 4 | **64** |
| 100 | 8 | 128 |
| 128 | 8 | 128 |
| 256 | 16 | 256 |
| 512 | 32 | 512 |
| 1024 | 64 | 1024 |
| ≥ 16384 | 1024 | 16384 (hard cap) |

A relation is mapped to one of the groups with:

```c
#define FAST_PATH_REL_GROUP(rel) \
        (((uint64) (rel) * 49157) % FastPathLockGroupsPerBackend)
```

Multiplying the OID by the prime 49157 spreads even consecutive OIDs (which is exactly what a freshly created set of partitions looks like) evenly across groups. Because a relation can only live in its own group, a strong-lock transfer only has to scan the relevant 16 slots per backend instead of the whole array - so the design stays cheap even at 16384 slots.

**Two consequences worth internalising:**

1. **The default just got 4× better.** With the default `max_locks_per_transaction = 64`, every PG 18 backend gets 64 fast-path slots instead of 16 - no configuration change needed.
2. **The limit is now tunable.** Schemas with many partitions and indexes can be given a fast path that actually fits the workload.

Being a set-associative cache, it is still possible - though far less likely - for a group to fill up while other groups are free. Round numbers of relations spread well thanks to the prime multiplier, so in practice this is rare.

### Benchmark evidence

Denis Morozov's benchmark reported in the postgres.ai article (128 vCPU machine, `pgbench -i -s 100`, `pgbench --select-only -c 100 -j 100 -T 120`, adding indexes one by one so the relation count grows from 2 upward):

* Up to 14 extra indexes (≤ 16 relations), latency grows slowly - everything fits in the fast path.
* At 15+ extra indexes with `max_locks_per_transaction = 16` (PG 18 configured to behave like PG 17): **planning time spikes dramatically** and the wait-event profile turns into a wall of `LWLock:LockManager`.
* At 15+ extra indexes with `max_locks_per_transaction = 64` or higher: **no degradation**, the profile stays dominated by actual CPU execution.
* **Execution time stayed flat throughout** in all cases - confirming that this is a planning-phase, lock-acquisition problem.

---

## 4. How to detect the problem

**Wait events** are the primary signal. In the pg_gather report, look for `LWLock:LockManager` in the [wait event](../waitevents.md) analysis. On a live system:

```sql
SELECT wait_event_type, wait_event, count(*)
  FROM pg_stat_activity
 WHERE state = 'active' AND wait_event IS NOT NULL
 GROUP BY 1,2 ORDER BY 3 DESC;
```

**Count the relation locks a single backend needs.** Anything above the fast-path slot count for your version is a candidate:

```sql
SELECT pid, count(*) AS relation_locks
  FROM pg_locks
 WHERE locktype = 'relation'
 GROUP BY pid
 ORDER BY 2 DESC
 LIMIT 10;
```

**Check what a specific query really locks** - `EXPLAIN (ANALYZE)` and compare *Planning Time* against *Execution Time*. A planning time that is large and grows with concurrency, while execution time stays flat, is the classic fingerprint.

The pg_gather report already reports `max_locks_by_a_pid` against the effective fast-path slot count for the server version, so a backend exceeding it is flagged directly.

---

## 5. Recommendations

**On PostgreSQL 18 and above**

1. Keep `max_locks_per_transaction` at least at the default of `64`. Do not lower it - on PG 18 lowering it now shrinks the fast path as well and can reintroduce the old cliff.
2. If you have partitioned tables and see `LWLock:LockManager` waits, raise it so that the fast-path slots cover the relations a typical query touches. Determine the real number from `pg_locks` (the query above), then round up:
   ```sql
   ALTER SYSTEM SET max_locks_per_transaction = 256;   -- 256 fast-path slots per backend
   -- restart required
   ```
3. Remember it is a **postmaster start-time** parameter - a restart is mandatory.
4. Memory cost is small. The fast-path arrays are a few hundred bytes to a few KB per backend; the shared lock table entries dominate. Still, `max_locks_per_transaction × (max_connections + max_prepared_transactions)` grows the shared lock table linearly, so avoid absurd values - and keep [max_connections](max_connections.md) sane, since both structures scale with it.
5. Do not treat it as a substitute for schema design. Reducing partition counts, fixing partition pruning, and dropping [unused indexes](../unusedIndexes.md) reduce the lock count at the source.

**On PostgreSQL 17 and below**

1. Set `max_locks_per_transaction` high enough to avoid `out of shared memory` - but understand it will **not** relieve `LWLock:LockManager` contention.
2. Attack the relation count instead: improve plan-time partition pruning, reduce the number of partitions scanned, drop unused indexes, and consider limiting parallelism for queries over many partitions (`max_parallel_workers_per_gather`, `parallel_setup_cost`, or `ALTER TABLE ... SET (parallel_workers = 1)`).
3. **If the contention is severe, upgrading to PostgreSQL 18 is the real fix.** For a schema with many partitions and indexes, this alone can remove the `LWLock:LockManager` wall - which makes PG 18 a compelling upgrade target for such workloads, independent of its other features.

---

## References

1. [Postgres Marathon 2-004: Fast-path locking (postgres.ai)](https://postgres.ai/blog/20251008-postgres-marathon-2-004)
2. [PostgreSQL commit c4d5cb71d - Increase the number of fast-path lock slots](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commitdiff;h=c4d5cb71d)
3. [Fast-path locking improvements in PG18 - Tomas Vondra, PGConf.dev 2025](https://youtu.be/iCmUhS9XYI0)
4. [PostgreSQL documentation - max_locks_per_transaction](https://www.postgresql.org/docs/current/runtime-config-locks.html#GUC-MAX-LOCKS-PER-TRANSACTION)
5. [pg_gather : Partitioning in PostgreSQL - Things to remember](../partition.md)
6. [pg_gather : Locks](../locks.md) and [Wait Events](../waitevents.md)
