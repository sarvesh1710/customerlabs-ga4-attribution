with events as (

    select
        event_date,
        event_timestamp,
        event_name,
        user_pseudo_id,
        event_bundle_sequence_id,

        (
            select value.int_value
            from unnest(event_params)
            where key = 'ga_session_id'
        ) as ga_session_id,

        (
            select value.string_value
            from unnest(event_params)
            where key = 'source'
        ) as event_source,

        (
            select value.string_value
            from unnest(event_params)
            where key = 'medium'
        ) as event_medium,

        (
            select value.string_value
            from unnest(event_params)
            where key = 'campaign'
        ) as event_campaign,

        traffic_source,
        traffic_medium,
        traffic_campaign,

        transaction_id,
        purchase_revenue

    from {{ ref('stg_ga4_events') }}

),

session_events as (

    select
        *,
        row_number() over (
            partition by user_pseudo_id, ga_session_id
            order by
                event_timestamp,
                event_bundle_sequence_id
        ) as event_rank,

        row_number() over (
            partition by user_pseudo_id, ga_session_id
            order by
                case
                    when event_source is not null
                      or event_medium is not null
                      or event_campaign is not null
                    then 0
                    else 1
                end,
                event_timestamp,
                event_bundle_sequence_id
        ) as attribution_rank

    from events

    where ga_session_id is not null

),

session_touchpoints as (

    select
        user_pseudo_id,
        ga_session_id,

        min(event_timestamp) as session_start_ts,

        coalesce(
            max(
                case
                    when attribution_rank = 1
                    then event_source
                end
            ),
            max(traffic_source),
            '(unknown)'
        ) as source,

        coalesce(
            max(
                case
                    when attribution_rank = 1
                    then event_medium
                end
            ),
            max(traffic_medium),
            '(unknown)'
        ) as medium,

        coalesce(
            max(
                case
                    when attribution_rank = 1
                    then event_campaign
                end
            ),
            max(traffic_campaign),
            '(unknown)'
        ) as campaign,

        count(*) as event_count,

        countif(event_name = 'purchase') as purchase_events,

        sum(
            case
                when event_name = 'purchase'
                then coalesce(purchase_revenue, 0)
                else 0
            end
        ) as purchase_revenue

    from session_events

    group by
        user_pseudo_id,
        ga_session_id

)

select *
from session_touchpoints