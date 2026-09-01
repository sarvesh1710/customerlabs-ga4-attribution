with purchase_events as (

    select
        event_date,
        event_timestamp,
        user_pseudo_id,
        event_bundle_sequence_id,

        (
            select value.int_value
            from unnest(event_params)
            where key = 'ga_session_id'
        ) as ga_session_id,

        transaction_id,
        purchase_revenue,
        total_item_quantity

    from {{ ref('stg_ga4_events') }}

    where event_name = 'purchase'

),

numbered_purchases as (

    select
        *,
        row_number() over (
            partition by user_pseudo_id
            order by
                event_timestamp,
                event_bundle_sequence_id,
                coalesce(transaction_id, '')
        ) as user_purchase_number

    from purchase_events

)

select
    concat(
        user_pseudo_id,
        '::',
        cast(event_timestamp as string),
        '::',
        cast(coalesce(event_bundle_sequence_id, 0) as string)
    ) as purchase_event_id,

    event_date,
    event_timestamp,
    user_pseudo_id,
    ga_session_id,
    event_bundle_sequence_id,

    transaction_id,
    purchase_revenue,
    total_item_quantity,

    user_purchase_number

from numbered_purchases