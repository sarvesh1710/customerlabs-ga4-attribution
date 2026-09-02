with purchases as (

    select
        purchase_event_id,
        event_date as purchase_date,
        event_timestamp as purchase_timestamp,
        user_pseudo_id,
        ga_session_id as purchase_session_id,
        transaction_id,
        purchase_revenue,
        total_item_quantity

    from {{ ref('int_ga4_purchases') }}

),

eligible_touchpoints as (

    select
        p.purchase_event_id,
        p.purchase_date,
        p.purchase_timestamp,
        p.user_pseudo_id,
        p.purchase_session_id,
        p.transaction_id,
        p.purchase_revenue,
        p.total_item_quantity,

        t.touchpoint_id,
        t.ga_session_id as touchpoint_session_id,
        t.event_timestamp as touchpoint_timestamp,
        t.event_bundle_sequence_id,
        t.source,
        t.medium,
        t.campaign,
        t.channel

    from purchases p

    left join {{ ref('int_ga4_touchpoints') }} t
        on p.user_pseudo_id = t.user_pseudo_id

        and t.event_timestamp < p.purchase_timestamp

        and t.event_timestamp >= timestamp_sub(
            p.purchase_timestamp,
            interval 14 day
        )

),

ranked_touchpoints as (

    select
        *,

        row_number() over (
            partition by purchase_event_id
            order by
                touchpoint_timestamp asc,
                event_bundle_sequence_id asc,
                touchpoint_id asc
        ) as first_click_rank,

        row_number() over (
            partition by purchase_event_id
            order by
                touchpoint_timestamp desc,
                event_bundle_sequence_id desc,
                touchpoint_id desc
        ) as chronological_last_click_rank,

        row_number() over (
            partition by purchase_event_id
            order by
                case
                    when channel != 'direct' then 0
                    else 1
                end,
                touchpoint_timestamp desc,
                event_bundle_sequence_id desc,
                touchpoint_id desc
        ) as last_click_rank

    from eligible_touchpoints

    where touchpoint_id is not null

),

first_click as (

    select
        purchase_event_id,
        source as first_click_source,
        medium as first_click_medium,
        campaign as first_click_campaign,
        channel as first_click_channel,
        touchpoint_timestamp as first_click_timestamp

    from ranked_touchpoints

    where first_click_rank = 1

),

last_click as (

    select
        purchase_event_id,
        source as last_click_source,
        medium as last_click_medium,
        campaign as last_click_campaign,
        channel as last_click_channel,
        touchpoint_timestamp as last_click_timestamp

    from ranked_touchpoints

    where last_click_rank = 1

)

select
    p.purchase_event_id,
    p.purchase_date,
    p.purchase_timestamp,
    p.user_pseudo_id,
    p.purchase_session_id,
    p.transaction_id,
    p.purchase_revenue,
    p.total_item_quantity,

    coalesce(
        fc.first_click_source,
        '(unattributed)'
    ) as first_click_source,

    coalesce(
        fc.first_click_medium,
        '(unattributed)'
    ) as first_click_medium,

    coalesce(
        fc.first_click_campaign,
        '(unattributed)'
    ) as first_click_campaign,

    coalesce(
        fc.first_click_channel,
        'unattributed'
    ) as first_click_channel,

    fc.first_click_timestamp,

    coalesce(
        lc.last_click_source,
        '(unattributed)'
    ) as last_click_source,

    coalesce(
        lc.last_click_medium,
        '(unattributed)'
    ) as last_click_medium,

    coalesce(
        lc.last_click_campaign,
        '(unattributed)'
    ) as last_click_campaign,

    coalesce(
        lc.last_click_channel,
        'unattributed'
    ) as last_click_channel,

    lc.last_click_timestamp

from purchases p

left join first_click fc
    on p.purchase_event_id = fc.purchase_event_id

left join last_click lc
    on p.purchase_event_id = lc.purchase_event_id