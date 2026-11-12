CREATE TABLE ridership (
    objectid                INT,
    route_number            TEXT,
    route_name              TEXT,
    route_direction         TEXT,
    ridership_total         INT,
    route_hour              NUMERIC,
    route_hour_description  TEXT,
    route_date              DATE,
    weekday                 TEXT
);

select count (*)
from ridership;

select route_name, sum(ridership_total) as total_riders
from ridership
group by route_name
order by total_riders Desc
limit 10;

select route_name, avg(ridership_total) as avg_riders
from ridership
group by route_name
having avg(ridership_total)>50
order by avg_riders desc;
