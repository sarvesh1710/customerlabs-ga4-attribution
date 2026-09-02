with attribution as (

    select *
    from {{ ref('mart_purchase_attribution') }}

),

first_click as (

    select
        first_click_channel as channel,
        first_click_source as source,
        first_click_medium as medium,
        first_click_campaign as campaign,

        count(*) as purchases,
        sum(coalesce(purchase_revenue, 0)) as revenue

    from attribution

    where first_click_timestamp is not null

    group by
        first_click_channel,
        first_click_source,
        first_click_medium,
        first_click_campaign

),

last_click as (

    select
        last_click_channel as channel,
        last_click_source as source,
        last_click_medium as medium,
        last_click_campaign as campaign,

        count(*) as purchases,
        sum(coalesce(purchase_revenue, 0)) as revenue

    from attribution

    where last_click_timestamp is not null

    group by
        last_click_channel,
        last_click_source,
        last_click_medium,
        last_click_campaign

)

select
    coalesce(f.channel, l.channel) as channel,

    coalesce(f.source, l.source) as source,

    coalesce(f.medium, l.medium) as medium,

    coalesce(f.campaign, l.campaign) as campaign,

    coalesce(f.purchases, 0) as first_click_purchases,

    coalesce(f.revenue, 0) as first_click_revenue,

    coalesce(l.purchases, 0) as last_click_purchases,

    coalesce(l.revenue, 0) as last_click_revenue

from first_click f

full outer join last_click l

    on f.channel = l.channel
    and f.source = l.source
    and f.medium = l.medium
    and f.campaign = l.campaign