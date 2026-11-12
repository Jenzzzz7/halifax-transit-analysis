/* =====================================================================
   Halifax Transit Ridership — 04. Views for Power BI
   ---------------------------------------------------------------------
   Views are saved queries: they store no data and always reflect the
   current ridership table. Power BI imports these instead of the raw
   863k rows, so the per-day averaging logic lives in one place.
   ===================================================================== */


/* ---------------------------------------------------------------------
   v_daily_ridership — grain: one row per date
   Used for: KPI cards, monthly trend
   --------------------------------------------------------------------- */
CREATE OR REPLACE VIEW v_daily_ridership AS
SELECT
    route_date,
    DATE_TRUNC('month', route_date)::date AS month,
    weekday,
    day_type,
    SUM(ridership_total)                  AS riders
FROM ridership
GROUP BY route_date, weekday, day_type;


/* ---------------------------------------------------------------------
   v_route_daily — grain: one row per route per date
   Used for: top routes chart, weekend retention table
   --------------------------------------------------------------------- */
CREATE OR REPLACE VIEW v_route_daily AS
SELECT
    route_name,
    route_date,
    day_type,
    SUM(ridership_total) AS riders
FROM ridership
GROUP BY route_name, route_date, day_type;


/* ---------------------------------------------------------------------
   v_hourly_profile — grain: one row per day type per half-hour slot
   Used for: rush-hour line chart
   --------------------------------------------------------------------- */
CREATE OR REPLACE VIEW v_hourly_profile AS
WITH days AS (
    SELECT day_type, COUNT(DISTINCT route_date) AS n_days
    FROM ridership
    GROUP BY day_type
)
SELECT
    r.day_type,
    r.route_hour,
    r.route_hour_description,
    ROUND(SUM(r.ridership_total)::numeric / d.n_days, 0) AS avg_riders_per_day
FROM ridership r
JOIN days d ON r.day_type = d.day_type
GROUP BY r.day_type, r.route_hour, r.route_hour_description, d.n_days;


-- Checks (expected: 299 days; weekday peak 3:30pm at 4,928)
SELECT COUNT(*) AS days FROM v_daily_ridership;

SELECT *
FROM v_hourly_profile
WHERE day_type = 'Weekday'
ORDER BY avg_riders_per_day DESC
LIMIT 3;
