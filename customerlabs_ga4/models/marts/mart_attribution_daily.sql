with attribution as (

    select *
    from {{ ref('mart_purchase_attribution') }}

),

daily as (

    select
        purchase_date,

        count(*) as total_purchases,

        sum(coalesce(purchase_revenue, 0)) as total_revenue,

        countif(first_click_timestamp is not null) as first_click_purchases,

        sum(
            case
                when first_click_timestamp is not null
                then coalesce(purchase_revenue, 0)
                else 0
            end
        ) as first_click_revenue,

        countif(last_click_timestamp is not null) as last_click_purchases,

        sum(
            case
                when last_click_timestamp is not null
                then coalesce(purchase_revenue, 0)
                else 0
            end
        ) as last_click_revenue,

        countif(
            first_click_channel != 'unattributed'
            and last_click_channel != 'unattributed'
            and first_click_channel != last_click_channel
        ) as channel_shift_purchases,

        countif(
            first_click_channel = 'unattributed'
        ) as unattributed_purchases,

        sum(
            case
                when first_click_channel = 'unattributed'
                then coalesce(purchase_revenue, 0)
                else 0
            end
        ) as unattributed_revenue

    from attribution

    group by purchase_date

)

select *
from daily
order by purchase_date