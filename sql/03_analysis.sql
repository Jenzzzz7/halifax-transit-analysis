/* =====================================================================
   Halifax Transit Ridership — 03. Analysis
   ---------------------------------------------------------------------
   Each query answers one business question. Results are summarised
   in the comment above each query.

   Fairness rule used throughout: day types have different numbers of
   days (205 weekdays vs 52 Sunday/Holidays), so ridership is totalled
   per day first and then averaged, rather than comparing raw totals.
   ===================================================================== */


/* ---------------------------------------------------------------------
   Q1. Which routes carry the most riders?
   Technique : GROUP BY, ORDER BY, LIMIT
   Result    : Spring Garden (1.99M) and CrossTown (1.76M) lead.
   --------------------------------------------------------------------- */
SELECT route_name, SUM(ridership_total) AS total_riders
FROM ridership
GROUP BY route_name
ORDER BY total_riders DESC
LIMIT 10;


/* ---------------------------------------------------------------------
   Q2. Which routes are busiest per half-hour slot?
   Technique : HAVING (filters groups after aggregation; WHERE filters rows before)
   --------------------------------------------------------------------- */
SELECT route_name, ROUND(AVG(ridership_total), 1) AS avg_riders_per_slot
FROM ridership
GROUP BY route_name
HAVING AVG(ridership_total) > 50
ORDER BY avg_riders_per_slot DESC;


/* ---------------------------------------------------------------------
   Q3. What share of all riders does each route carry?
   Technique : CTE + window functions
               RANK() OVER (ORDER BY ...)          -> ranking
               SUM() OVER ()                       -> grand total on every row
               SUM() OVER (ORDER BY ... ROWS ...)  -> running total
   Result    : Spring Garden alone carries 8.6%; the top 5 routes carry 32.4%.
   --------------------------------------------------------------------- */
WITH route_totals AS (
    SELECT route_name, SUM(ridership_total) AS riders
    FROM ridership
    GROUP BY route_name
)
SELECT
    route_name,
    riders,
    RANK() OVER (ORDER BY riders DESC)                 AS route_rank,
    ROUND(100.0 * riders / SUM(riders) OVER (), 2)     AS pct_share,
    ROUND(100.0 * SUM(riders) OVER (ORDER BY riders DESC
                                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
          / SUM(riders) OVER (), 1)                    AS cumulative_pct
FROM route_totals
ORDER BY route_rank;


/* ---------------------------------------------------------------------
   Q4. How many routes carry half of all riders? (Pareto check)
   Technique : filtering on a window-function result.
               WHERE runs before window functions, so the window result
               is computed in a CTE first and filtered afterwards.
   Result    : 9 of 76 routes carry 50% of all riders (Dalhousie, #9, crosses the line).
   --------------------------------------------------------------------- */
WITH route_totals AS (
    SELECT route_name, SUM(ridership_total) AS riders
    FROM ridership
    GROUP BY route_name
),
ranked AS (
    SELECT
        route_name,
        RANK() OVER (ORDER BY riders DESC) AS route_rank,
        100.0 * SUM(riders) OVER (ORDER BY riders DESC
                                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
              / SUM(riders) OVER ()        AS cumulative_pct,
        COUNT(*) OVER ()                   AS total_routes
    FROM route_totals
)
SELECT route_name, route_rank, total_routes, ROUND(cumulative_pct, 1) AS cumulative_pct
FROM ranked
WHERE cumulative_pct >= 50
ORDER BY route_rank
LIMIT 1;


/* ---------------------------------------------------------------------
   Q5. When is rush hour — and is it the same every day?
   Technique : PARTITION BY (restart the ranking within each day type),
               JOIN to a day-count CTE for per-day averages
   Result    : All day types peak mid-to-late afternoon.
               Weekday 3:30pm  ~4,928 riders/day in that slot
               Saturday 3:00pm ~2,349 | Sunday/Holiday 5:00pm ~1,954
   --------------------------------------------------------------------- */
WITH slot_totals AS (
    SELECT day_type, route_hour, route_hour_description,
           SUM(ridership_total) AS riders
    FROM ridership
    GROUP BY day_type, route_hour, route_hour_description
),
days AS (
    SELECT day_type, COUNT(DISTINCT route_date) AS n_days
    FROM ridership
    GROUP BY day_type
),
ranked AS (
    SELECT
        s.day_type,
        s.route_hour_description,
        ROUND(s.riders::numeric / d.n_days, 0)                      AS avg_riders_per_day,
        RANK() OVER (PARTITION BY s.day_type ORDER BY s.riders DESC) AS slot_rank
    FROM slot_totals s
    JOIN days d ON s.day_type = d.day_type
)
SELECT *
FROM ranked
WHERE slot_rank <= 3
ORDER BY day_type, slot_rank;


/* ---------------------------------------------------------------------
   Q6. How big is the weekday morning rush compared with the afternoon?
   Technique : MAX() OVER () for "% of peak"; ranking computed over the
               whole day BEFORE filtering to morning slots
   Result    : Morning peaks sharply at 7:30am (#5 of the day, 85% of the
               afternoon peak) and falls to 53% by 8:30am.
   --------------------------------------------------------------------- */
WITH weekday_slots AS (
    SELECT route_hour, route_hour_description,
           SUM(ridership_total)::numeric / COUNT(DISTINCT route_date) AS avg_riders
    FROM ridership
    WHERE day_type = 'Weekday'
    GROUP BY route_hour, route_hour_description
),
ranked AS (
    SELECT
        route_hour,
        route_hour_description,
        ROUND(avg_riders, 0)                                  AS avg_riders_per_day,
        RANK() OVER (ORDER BY avg_riders DESC)                AS slot_rank,
        ROUND(100.0 * avg_riders / MAX(avg_riders) OVER (), 0) AS pct_of_peak
    FROM weekday_slots
)
SELECT route_hour_description, avg_riders_per_day, slot_rank, pct_of_peak
FROM ranked
WHERE route_hour BETWEEN 6 AND 9.5
ORDER BY route_hour;


/* ---------------------------------------------------------------------
   Q7. Which routes lose their riders on weekends?
   Technique : pivot with AVG() FILTER (WHERE ...) to turn day types into
               columns; NULLS FIRST surfaces routes with no Sunday service
   Result    : 6 commuter routes run weekdays only. University and express
               routes keep ~30-40% on Sundays; Airport (74%) and retail routes
               hold up best. Bayers Lake and Dartmouth Crossing keep ~87%
               of weekday riders on Saturdays.
   --------------------------------------------------------------------- */
WITH daily_route AS (
    SELECT route_name, day_type, route_date,
           SUM(ridership_total) AS riders
    FROM ridership
    GROUP BY route_name, day_type, route_date
),
route_avgs AS (
    SELECT
        route_name,
        AVG(riders) FILTER (WHERE day_type = 'Weekday')        AS weekday_avg,
        AVG(riders) FILTER (WHERE day_type = 'Saturday')       AS saturday_avg,
        AVG(riders) FILTER (WHERE day_type = 'Sunday/Holiday') AS sunday_avg
    FROM daily_route
    GROUP BY route_name
)
SELECT
    route_name,
    ROUND(weekday_avg)                        AS weekday_avg,
    ROUND(saturday_avg)                       AS saturday_avg,
    ROUND(sunday_avg)                         AS sunday_avg,
    ROUND(100.0 * saturday_avg / weekday_avg) AS saturday_pct_of_weekday,
    ROUND(100.0 * sunday_avg / weekday_avg)   AS sunday_pct_of_weekday
FROM route_avgs
WHERE weekday_avg >= 500          -- ignore very small routes
ORDER BY sunday_pct_of_weekday ASC NULLS FIRST;


/* ---------------------------------------------------------------------
   Q8. How does ridership change month to month?
   Technique : DATE_TRUNC to group by month, LAG() for the previous
               month's value, month-over-month % change.
               Weekdays only, averaged per day, so months with more
               weekends or holidays are not penalised.
   Result    : Dips ~9% in July-August, then jumps 15.5% in September as
               the school year starts. Fall is the busiest period.
   --------------------------------------------------------------------- */
WITH daily AS (
    SELECT route_date, SUM(ridership_total) AS riders
    FROM ridership
    WHERE day_type = 'Weekday'
    GROUP BY route_date
),
monthly AS (
    SELECT
        DATE_TRUNC('month', route_date)::date AS month,
        COUNT(*)                              AS weekdays_in_data,
        ROUND(AVG(riders))                    AS avg_weekday_riders
    FROM daily
    GROUP BY DATE_TRUNC('month', route_date)
)
SELECT
    TO_CHAR(month, 'Mon YYYY')                    AS month_label,
    weekdays_in_data,
    avg_weekday_riders,
    LAG(avg_weekday_riders) OVER (ORDER BY month) AS prev_month,
    ROUND(100.0 * (avg_weekday_riders - LAG(avg_weekday_riders) OVER (ORDER BY month))
          / LAG(avg_weekday_riders) OVER (ORDER BY month), 1) AS mom_pct_change
FROM monthly
ORDER BY month;
