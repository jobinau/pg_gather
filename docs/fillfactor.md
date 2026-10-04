## FILLFACTOR tuning
Choosing fillfactor is a trade-off. Free space left on a heap page lets updates stay on that page (HOT), but the same free space makes the table bigger and scans slower.

## factors to be considered for adjusting FILLFACTOR

#### % Of updates
Tables that only receive inserts (logs, events, audit) should stay at 100. Leaving space free on those pages costs you and gains nothing.
#### Rate of updates
A row updated 50 times a minute needs much more headroom than one updated once a dayv
#### Deletes. 
Space freed by deletes is reused, so tables with heavy deletes need less reserved space.
#### Update on Indexed column
If updates change indexed columns, a lower fillfactor won't turn them into HOT updates.

## Theoretical Calculation of FILLFACTOR

```
ReserveNeedInBytes ≈ (updates landing on a page between prunes) × (new tuple size + 4)

fillfactor ≈ 100 × (1 − ReserveNeedInBytes ÷ 8168)
```
However, it is practically very difficult to do it. And it may not stay stable.

## Practical Calculation of FILLFACTOR
This is the practical approch.
Hovering the mouse over the table names, gives approximate suggessions for fillfactor.
Following are better options for FILLFACTOR estimate
```
WITH param AS (SELECT 20 AS max_step,          -- Max reduction (%) suggested in one step
                      70 AS min_ff,            -- Never suggest below this
                      1000 AS min_upd,         -- Ignore tables with fewer updates
                      1000 AS min_sample,      -- Min same-page updates to trust the HOT-eligible fraction
                      8*1024*1024 AS min_size), -- Ignore tables smaller than 8MB
tabs AS (
 SELECT ns.nsname, c.relname, r.n_tup_ins, r.n_tup_upd, r.n_tup_hot_upd, r.n_tup_newpage_upd,
   COALESCE(substring(array_to_string(c.reloptions,',') from '(?:^|,)fillfactor=(\d+)')::int, 100) AS cur_ff
 FROM pg_get_rel r
 JOIN pg_get_class c ON r.relid = c.reloid AND c.relkind NOT IN ('t','p')
 JOIN pg_get_ns ns ON r.relnamespace = ns.nsoid
 JOIN param ON r.n_tup_upd >= param.min_upd AND r.rel_size >= param.min_size),
est AS (
 SELECT tabs.*, param.*,
  CASE WHEN n_tup_newpage_upd IS NULL THEN 'non-HOT ratio (pre-PG16)'
       WHEN n_tup_upd - n_tup_newpage_upd < min_sample THEN 'newpage, HOT-eligibility unknown'
       ELSE 'newpage x HOT-eligible' END AS method,
  CASE WHEN n_tup_newpage_upd IS NULL OR n_tup_upd - n_tup_newpage_upd < min_sample THEN NULL
       ELSE n_tup_hot_upd::numeric / (n_tup_upd - n_tup_newpage_upd) END AS hot_eligible
 FROM tabs, param),
rec AS (
 SELECT est.*,
  CASE WHEN cur_ff < 100 AND hot_eligible < 0.1 THEN 100   -- Space already reserved, but updates change indexed columns
       ELSE GREATEST(min_ff, cur_ff - round(max_step *
         CASE WHEN n_tup_newpage_upd IS NULL THEN n_tup_upd - n_tup_hot_upd
              ELSE n_tup_newpage_upd * COALESCE(hot_eligible, 1) END
         / (n_tup_ins + n_tup_upd)))::int END AS rec_ff
 FROM est)
SELECT nsname||'.'||relname AS "Table", cur_ff AS "Cur.FF", rec_ff AS "Rec.FF", method AS "Method",
  n_tup_ins AS "Inserts", n_tup_upd AS "Updates",
  round(100.0*n_tup_hot_upd/n_tup_upd,1) AS "HOT%",
  round(100.0*n_tup_newpage_upd/n_tup_upd,1) AS "NewPage%",
  round(100*hot_eligible,1) AS "HOT-eligible%",
  'ALTER TABLE '||quote_ident(nsname)||'.'||quote_ident(relname)||' SET ( FILLFACTOR='||rec_ff||' );' AS "Statement"
FROM rec
WHERE abs(cur_ff - rec_ff) >= 2
ORDER BY cur_ff - rec_ff DESC, n_tup_upd DESC;
```
