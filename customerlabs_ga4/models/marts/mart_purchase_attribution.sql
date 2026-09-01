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

        t.ga_session_id as touchpoint_session_id,
        t.session_start_ts as touchpoint_timestamp,
        t.source,
        t.medium,
        t.campaign

    from purchases p

    left join {{ ref('int_ga4_touchpoints') }} t
        on p.user_pseudo_id = t.user_pseudo_id
        and t.session_start_ts between
            timestamp_sub(p.purchase_timestamp, interval 14 day)
            and p.purchase_timestamp

),

ranked_touchpoints as (

    select
        *,
        row_number() over (
            partition by purchase_event_id
            order by
                touchpoint_timestamp asc,
                touchpoint_session_id asc
        ) as first_click_rank,

        row_number() over (
            partition by purchase_event_id
            order by
                touchpoint_timestamp desc,
                touchpoint_session_id desc
        ) as last_click_rank

    from eligible_touchpoints

    where touchpoint_session_id is not null

),

first_click as (

    select
        purchase_event_id,
        source as first_click_source,
        medium as first_click_medium,
        campaign as first_click_campaign,
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

    coalesce(fc.first_click_source, '(unattributed)') as first_click_source,
    coalesce(fc.first_click_medium, '(unattributed)') as first_click_medium,
    coalesce(fc.first_click_campaign, '(unattributed)') as first_click_campaign,
    fc.first_click_timestamp,

    coalesce(lc.last_click_source, '(unattributed)') as last_click_source,
    coalesce(lc.last_click_medium, '(unattributed)') as last_click_medium,
    coalesce(lc.last_click_campaign, '(unattributed)') as last_click_campaign,
    lc.last_click_timestamp

from purchases p

left join first_click fc
    on p.purchase_event_id = fc.purchase_event_id

left join last_click lc
    on p.purchase_event_id = lc.purchase_event_id