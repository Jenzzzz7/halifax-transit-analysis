/* =====================================================================
   Halifax Transit Ridership — 01. Create table
   ---------------------------------------------------------------------
   Database : PostgreSQL
   Purpose  : Create the ridership table that holds the cleaned APC data
              produced by notebooks/01_data_cleaning.ipynb.
   Grain    : one row = riders on one route, in one direction, in one
              half-hour slot, on one date.
   ===================================================================== */

DROP TABLE IF EXISTS ridership CASCADE;   -- CASCADE also drops the views built on it

CREATE TABLE ridership (
    objectid                INT,
    route_number            TEXT,
    route_name              TEXT,
    route_direction         TEXT,
    ridership_total         INT,       -- riders counted in the half-hour slot
    route_hour              NUMERIC,   -- slot start as a decimal hour, e.g. 15.5 = 3:30pm
    route_hour_description  TEXT,      -- e.g. '3:30pm to 3:59pm'
    route_date              DATE,
    weekday                 TEXT,      -- Monday ... Sunday
    day_type                TEXT       -- Weekday | Saturday | Sunday/Holiday
);

/* ---------------------------------------------------------------------
   Load the data
   ---------------------------------------------------------------------
   Column order matches data/apc_clean.csv, so the import maps by position.

   Option A — pgAdmin:
     right-click "ridership" > Import/Export Data > data/apc_clean.csv
     > Format: csv > Header: ON

   Option B — psql (run from the project folder):
     \copy ridership FROM 'data/apc_clean.csv' WITH (FORMAT csv, HEADER true)
   --------------------------------------------------------------------- */
