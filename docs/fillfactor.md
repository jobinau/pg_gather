## FILLFACTOR tuning
Choosing fillfactor is a trade-off. Free space left on a heap page lets updates stay on that page (HOT), but the same free space makes the table bigger and scans slower. So the recommendation is to adjust the FILLFACTOR only where it is absolute necessary. It would be wise to test the modified fillfactor before rolling out to production.

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
### From pg_gather data
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

## Recommendation directly from the target database
This query is not for the pg_gather data. Run it directly on the target database (PostgreSQL 10 and above) to get more accurate FILLFACTOR recommendations.
It estimates the space to reserve on each page from the number of HOT-eligible updates landing on a page in each vacuum cycle, minus the space freed by deletes, multiplied by the actual tuple width taken from `pg_stats`.
Bulk inserts do not dilute the estimate. The number of updates in a cycle is capped at the autovacuum trigger point of the table. Tables which update indexed columns get no reduction, and tables with too low a FILLFACTOR get a suggestion to raise it.
Since pruning of pages between vacuums is not considered, the recommendation is on the conservative side (lower FILLFACTOR). On versions older than PG16, tables are assumed HOT-eligible and marked for verification.
The statistics need to accumulate over a reasonable period after a stats reset for the recommendation to be meaningful.
```
-- FILLFACTOR recommendation, run directly on the target database (PG10+).
-- Reserve per page ≈ (HOT-eligible updates landing on a page per vacuum cycle - deletes per page per cycle) × (tuple size + 4)
WITH param AS (SELECT 70 AS min_ff,                 -- Never suggest below this
                      1000 AS min_upd,              -- Ignore tables with fewer updates
                      1024*1024 AS min_size,        -- Ignore tables smaller than 1MB
                      current_setting('block_size')::int - 24 AS page_space,
                      current_setting('autovacuum_vacuum_threshold')::numeric AS av_thr,
                      current_setting('autovacuum_vacuum_scale_factor')::numeric AS av_sf),
tabs AS (
 SELECT s.relid, s.schemaname, s.relname, c.relpages, GREATEST(c.reltuples,1)::numeric AS reltuples,
   s.n_tup_ins, s.n_tup_upd, s.n_tup_del, s.n_tup_hot_upd,
   (to_jsonb(s)->>'n_tup_newpage_upd')::bigint AS n_tup_newpage_upd,   -- NULL before PG16
   s.vacuum_count + s.autovacuum_count + 1 AS cycles,
   COALESCE(substring(array_to_string(c.reloptions,',') from 'fillfactor=(\d+)')::int, 100) AS cur_ff,
   COALESCE(substring(array_to_string(c.reloptions,',') from 'autovacuum_vacuum_threshold=([\d.]+)')::numeric, av_thr) AS av_thr,
   COALESCE(substring(array_to_string(c.reloptions,',') from 'autovacuum_vacuum_scale_factor=([\d.]+)')::numeric, av_sf) AS av_sf,
   pg_relation_size(s.relid) AS rel_size
 FROM pg_stat_user_tables s
 JOIN pg_class c ON c.oid = s.relid AND c.relkind IN ('r','m') AND c.relpages > 0
 JOIN param ON s.n_tup_upd >= param.min_upd),
wdth AS (  -- Average heap tuple size: header + data from pg_stats, else derived from the relation size
 SELECT t.relid,
   COALESCE(24 + (SELECT sum(st.avg_width * (1 - st.null_frac)) FROM pg_stats st
                  WHERE st.schemaname = t.schemaname AND st.tablename = t.relname),
            t.rel_size::numeric / t.reltuples) AS tup_bytes
 FROM tabs t),
est AS (
 SELECT t.*, w.tup_bytes, p.min_ff, p.page_space,
  -- Fraction of updates that could be HOT if space was available on the page
  CASE WHEN n_tup_newpage_upd IS NOT NULL AND n_tup_upd - n_tup_newpage_upd >= 100
         THEN n_tup_hot_upd::numeric / (n_tup_upd - n_tup_newpage_upd)
       WHEN cur_ff < 100 OR n_tup_newpage_upd IS NOT NULL      -- space was there, HOT still didn't happen
         THEN n_tup_hot_upd::numeric / n_tup_upd
       ELSE 1 END AS hot_eligible,
  CASE WHEN n_tup_newpage_upd IS NOT NULL THEN 'PG16+ newpage stats'
       WHEN cur_ff < 100 THEN 'HOT ratio with reserved space'
       ELSE 'pre-PG16: assumes HOT-eligible, verify' END AS method,
  -- Updates per vacuum cycle, capped by what would trigger autovacuum anyway
  LEAST(n_tup_upd::numeric / cycles, t.av_thr + t.av_sf * reltuples) AS upd_cycle
 FROM tabs t JOIN wdth w USING (relid), param p
 WHERE t.rel_size >= p.min_size),
rec AS (
 SELECT est.*,
   GREATEST(0, (upd_cycle * hot_eligible - n_tup_del::numeric / cycles) / relpages) AS upd_page,
   100 * (1 - GREATEST(0, (upd_cycle * hot_eligible - n_tup_del::numeric / cycles) / relpages) * (tup_bytes + 4) / page_space) AS raw_ff
 FROM est)
SELECT quote_ident(schemaname)||'.'||quote_ident(relname) AS "Table",
  pg_size_pretty(rel_size) AS "Size", n_tup_upd AS "Updates",
  round(100.0*n_tup_hot_upd/n_tup_upd,1) AS "HOT%",
  round(100.0*n_tup_newpage_upd/n_tup_upd,1) AS "NewPage%",
  round(100*hot_eligible,1) AS "HOT-eligible%",
  cycles AS "Vac.Cycles", round(tup_bytes) AS "Tup.Bytes", round(upd_page,2) AS "Upd/Page/Cycle",
  cur_ff AS "Cur.FF",
  LEAST(100, GREATEST(min_ff, 5*round(raw_ff/5)))::int AS "Rec.FF",
  method AS "Method",
  'ALTER TABLE '||quote_ident(schemaname)||'.'||quote_ident(relname)||' SET ( FILLFACTOR='||LEAST(100, GREATEST(min_ff, 5*round(raw_ff/5)))::int||' );' AS "Statement"
FROM rec
WHERE cur_ff <> LEAST(100, GREATEST(min_ff, 5*round(raw_ff/5)))
ORDER BY abs(cur_ff - raw_ff) DESC;
```
