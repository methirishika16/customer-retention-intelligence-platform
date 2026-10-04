-- RAW geolocation has ~1M sample points with many per zip prefix.
-- This model reduces it to ONE row per zip prefix (average point), after dropping
-- the points that fall outside Brazil (Sprint 1 found 42).
-- Use it for maps: join on customer_zip_code_prefix / seller_zip_code_prefix.

with source as (

    select * from {{ source('olist', 'geolocation') }}

),

inside_brazil as (

    select
        lpad(trim(geolocation_zip_code_prefix), 5, '0')  as zip_code_prefix,
        geolocation_lat                                  as latitude,
        geolocation_lng                                  as longitude,
        lower(trim(geolocation_city))                    as city,
        upper(trim(geolocation_state))                   as state
    from source
    where geolocation_lat between -34 and 6
      and geolocation_lng between -74 and -34

),

one_row_per_zip as (

    select
        zip_code_prefix,
        avg(latitude)    as latitude,
        avg(longitude)   as longitude,
        mode(city)       as city,       -- most common spelling for the prefix
        mode(state)      as state,
        count(*)         as source_point_count
    from inside_brazil
    group by zip_code_prefix

)

select * from one_row_per_zip
