with source_events as (

    select
        event_date,
        event_timestamp,
        event_name,
        user_pseudo_id,
        user_first_touch_timestamp,
        event_bundle_sequence_id,

        traffic_source.source as traffic_source,
        traffic_source.medium as traffic_medium,
        traffic_source.name as traffic_campaign,

        ecommerce.transaction_id,
        ecommerce.purchase_revenue,
        ecommerce.total_item_quantity,

        event_params

    from `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

),

cleaned_events as (

    select
        event_date,
        timestamp_micros(event_timestamp) as event_timestamp,
        event_name,
        user_pseudo_id,
        timestamp_micros(user_first_touch_timestamp) as user_first_touch_timestamp,
        event_bundle_sequence_id,

        coalesce(traffic_source, '(unknown)') as traffic_source,
        coalesce(traffic_medium, '(unknown)') as traffic_medium,
        coalesce(traffic_campaign, '(unknown)') as traffic_campaign,

        transaction_id,
        purchase_revenue,
        total_item_quantity,

        event_params

    from source_events

)

select *
from cleaned_events