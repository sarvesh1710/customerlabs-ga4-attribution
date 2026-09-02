with ranked_events as (

    select
        event_id,
        event_timestamp,
        user_pseudo_id,
        ga_session_id,
        event_name,
        source,
        medium,
        campaign,
        event_value,
        ingested_at,

        row_number() over (
            partition by event_id
            order by ingested_at desc
        ) as row_num

    from `celestial-gist-407221.customerlabs_ga4_streaming.streamed_events`

)

select
    event_id,
    event_timestamp,
    user_pseudo_id,
    ga_session_id,
    event_name,
    source,
    medium,
    campaign,
    event_value,
    ingested_at

from ranked_events

where row_num = 1