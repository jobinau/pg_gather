# Glibc Collation Provider

PostgreSQL depends on collation providers to provide character collation feature.  
Unfortunately glibc is the widely used collation provider for PostgreSQL, which is unstable accross version and highly inefficient when it comes to character collation. 
Please refer to following comparitive studies by Jeremy Schneider  
[glibc-unicode-sorting](https://github.com/ardentperf/glibc-unicode-sorting/)

## The failure mode
Your sort order isn't as stable as you think it is  
A B-tree index is a promise: rows are physically arranged in the order the collation says they belong. That promise depends on the collation never changing its mind. For any collation backed by the operating system's glibc locale tables — which is the default for most initdb-created clusters — that promise is only as good as the OS underneath it.

As Jeremy mentions
> "If PostgreSQL data files are moved to a different operating system (or the base container used to build PostgreSQL is changed) without rebuilding indexes and other persistent structures that depend on collation ordering, the database is effectively corrupt."

There won't be any error, no log line, no checksum failure at the storage layer — just index scans that can silently skip rows, and unique constraints that can no longer be trusted. This can result in runtime errors, wrong results, index corruption errors and logical data corruptions due to constraint failures

## The performance case
Independent of the corruption risk, there's another problem and it doesn't require an OS upgrade to matter: glibc's linguistic collations are consistently, drastically slower — and unlike a fixed "tax", the slowness itself isn't even stable across versions.
As the benchmark explains, some of the collations in glibc is hundreds of times slower than built-in. The gap in performance alone would be reason enough to default away from linguistic glibc collations. But it gets worse: the range isn't fixed per locale — it moves under you.

A single RHEL major upgrade — no application change, no index rebuild, no query rewrite — made the exact same ORDER BY roughly 21× slower 

Overall performance numbers looks like:
```
┌──────────────────┬───────────────┐
│     Provider     │  Time range   │
├──────────────────┼───────────────┤
│ Postgres builtin │ 0.2–0.3 min   │
├──────────────────┼───────────────┤
│ ICU              │ 0.3–0.9 min   │
├──────────────────┼───────────────┤
│ glibc linguistic │ 2.7–167.5 min │
└──────────────────┴───────────────┘
```

## Reccomendation / Suggession
Most columns in most databases — surrogate keys, codes, timestamps-as-text, machine-generated identifiers, and plenty of user-facing text where byte order is perfectly acceptable — never needed natural-language sorting in the first place. Defaulting those to a builtin collation costs nothing and removes an entire class of latent corruption risk.

Its recommendable to use column level lingustic collation wherever neeed, For example, a customer-facing name field sorted for a German-language.
```bash
## Initialize the data directory using builtin provider
initdb -D ~/data --locale-provider=builtin --builtin-locale=C.UTF8 -E UTF8
```
OR
```sql
-- Opt for a database level default collation using built-in provider
CREATE DATABASE appdb ENCODING = 'UTF8' LOCALE_PROVIDER = 'builtin'  BUILTIN_LOCALE = 'C.UTF-8'  TEMPLATE = template0;
```

```sql
-- The one column that genuinely needs linguistic sorting gets it explicitly 
-- and is now the only thing you must remember to reindex after an OS/ICU upgrade.
CREATE TABLE customer (
    id        bigint GENERATED ALWAYS AS IDENTITY,
    ext_ref   text,                              -- builtin default: fine as-is
    full_name text COLLATE "de-DE-x-icu"          -- explicit override
);
```

## Why builtin doesn't have this problem
Glibc's linguistic collations are natural-language sort tables baked into the OS's own Unicode data, versioned on the OS's own release cadence and out of PostgreSQL's control. The builtin provider sidesteps that dependency entirely: `C` and `C.UTF-8` compare strings by raw byte/code-point value — no external locale table to consult, so nothing external to drift.

PG18 extended that same architecture with `pg_unicode_fast`: still code-point sort order (still a memcmp, still immune to OS drift), but layered with Unicode-aware case folding and pattern-matching semantics — so you get standards-correct upper('ß') = 'SS' behavior without giving up the one property that actually protects your indexes. 

ICU collations aren't immune to versioning. But compared to glibc they are both fast and checksum-stable across every OS tested  — because ICU ships its own bundled Unicode tables rather than borrowing the host's, so an OS upgrade doesn't silently swap your collation data out from under you the way glibc does.



