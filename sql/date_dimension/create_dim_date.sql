-- ============================================================
-- DATE DIMENSION (dim_date)
-- Purpose: the source schema stores order_year, order_month, and
-- order_day as three separate integer columns on `orders`. This is
-- workable for ad-hoc SQL filtering but is NOT sufficient for proper
-- time-intelligence in Power BI (which needs a genuine contiguous
-- Date column/table to drive slicers, YoY/MoM DAX measures, etc.).
--
-- This script builds a standard calendar date dimension covering the
-- dataset's known date range (2024-01-01 through 2026-12-31, padded
-- slightly beyond the documented March 2024 - February 2026 order
-- window so the table remains valid if data extends at either edge).
-- ============================================================

drop table if exists dim_date;

create table dim_date as
select
    d::date                                   as date_key,
    extract(year from d)::int                 as year,
    extract(quarter from d)::int              as quarter,
    'Q' || extract(quarter from d)::int        as quarter_label,
    extract(month from d)::int                as month_number,
    to_char(d, 'Month')                       as month_name,
    to_char(d, 'Mon')                         as month_short_name,
    extract(week from d)::int                 as iso_week,
    extract(day from d)::int                  as day_of_month,
    extract(isodow from d)::int               as day_of_week_number, -- 1=Mon .. 7=Sun
    to_char(d, 'Day')                         as day_of_week_name,
    to_char(d, 'Dy')                          as day_of_week_short_name,
    case when extract(isodow from d) in (6, 7) then true else false end as is_weekend,
    to_char(d, 'YYYY-MM')                     as year_month_label,
    (extract(year from d)::int * 100 + extract(month from d)::int)      as year_month_key
from generate_series(
    '2024-01-01'::date,
    '2026-12-31'::date,
    interval '1 day'
) as d;

alter table dim_date add primary key (date_key);
create index idx_dim_date_year_month on dim_date (year, month_number);
create index idx_dim_date_year_month_key on dim_date (year_month_key);

-- ============================================================
-- Helper: a single reusable expression to reconstruct an order's date
-- from the existing order_year/order_month/order_day columns, so it
-- can be joined against dim_date without altering the orders table.
--
-- Usage pattern (used throughout views/bi_ready/):
--
--   select o.*, dd.quarter_label, dd.day_of_week_name
--   from orders o
--   inner join dim_date dd
--       on dd.date_key = make_date(o.order_year, o.order_month, o.order_day)
--
-- NOTE: if any order has an invalid year/month/day combination (see
-- sql/data_quality/05_missing_values_and_invalid_dates.sql), the
-- make_date() call will error. Run that data-quality check and resolve
-- any invalid dates BEFORE relying on this join in production views.
-- ============================================================
