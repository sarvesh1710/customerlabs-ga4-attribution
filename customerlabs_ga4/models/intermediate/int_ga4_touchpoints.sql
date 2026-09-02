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
        ) as event_campaign

    from {{ ref('stg_ga4_events') }}

),

candidate_touchpoints as (

    select
        event_date,
        event_timestamp,
        event_name,
        user_pseudo_id,
        ga_session_id,
        event_bundle_sequence_id,
        event_source,
        event_medium,
        event_campaign,

        case
            when lower(coalesce(event_medium, '')) = 'cpc'
                then 'paid_search'

            when lower(coalesce(event_medium, '')) = 'organic'
                then 'organic_search'

            when lower(coalesce(event_medium, '')) = 'referral'
                then 'referral'

            when lower(coalesce(event_source, '')) = '(direct)'
                and lower(coalesce(event_medium, '')) = '(none)'
                then 'direct'

            else 'other'
        end as channel

    from events

    where event_name = 'page_view'

      and ga_session_id is not null

      and (
          event_source is not null
          or event_medium is not null
          or event_campaign is not null
      )

),

with_previous_channel as (

    select
        *,
        lag(channel) over (
            partition by
                user_pseudo_id,
                ga_session_id
            order by
                event_timestamp,
                event_bundle_sequence_id
        ) as previous_channel

    from candidate_touchpoints

),

deduplicated_touchpoints as (

    select
        *
    from with_previous_channel

    where previous_channel is null
       or channel != previous_channel

),

final as (

    select
        concat(
            user_pseudo_id,
            '::',
            cast(event_timestamp as string),
            '::',
            cast(coalesce(event_bundle_sequence_id, 0) as string)
        ) as touchpoint_id,

        event_date,
        event_timestamp,
        user_pseudo_id,
        ga_session_id,
        event_bundle_sequence_id,

        event_source as source,
        event_medium as medium,
        event_campaign as campaign,

        channel

    from deduplicated_touchpoints

)

select *
from final