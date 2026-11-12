/* =====================================================================
   Halifax Transit Ridership — 02. Data checks
   ---------------------------------------------------------------------
   Purpose : Confirm the import is complete and matches the notebook
             before any analysis. Expected values are shown for each.
   ===================================================================== */


-- 2.1  Row count
-- Expected: 863,550 (raw 863,614 minus 64 outliers above 300 riders)
SELECT COUNT(*) AS total_rows
FROM ridership;


-- 2.2  Rows per day type
-- Expected: Weekday 653,356 | Sunday/Holiday 106,756 | Saturday 103,438
SELECT day_type, COUNT(*) AS rows
FROM ridership
GROUP BY day_type
ORDER BY rows DESC;


-- 2.3  Date coverage
-- Expected: 2026-01-01 to 2026-10-27, 299 distinct dates (2026-09-19 missing)
SELECT
    MIN(route_date)            AS first_date,
    MAX(route_date)            AS last_date,
    COUNT(DISTINCT route_date) AS distinct_dates
FROM ridership;


-- 2.4  Days per day type (used to turn totals into fair per-day averages)
-- Expected: Weekday 205 | Sunday/Holiday 52 | Saturday 42
SELECT day_type, COUNT(DISTINCT route_date) AS days
FROM ridership
GROUP BY day_type
ORDER BY days DESC;
