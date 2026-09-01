WITH first_click AS (

    SELECT
        first_click_source AS source,
        first_click_medium AS medium,
        first_click_campaign AS campaign,
        COUNT(*) AS purchases,
        SUM(purchase_revenue) AS revenue
    FROM `customerlabs_ga4.mart_purchase_attribution`
    GROUP BY
        source,
        medium,
        campaign

),

last_click AS (

    SELECT
        last_click_source AS source,
        last_click_medium AS medium,
        last_click_campaign AS campaign,
        COUNT(*) AS purchases,
        SUM(purchase_revenue) AS revenue
    FROM `customerlabs_ga4.mart_purchase_attribution`
    GROUP BY
        source,
        medium,
        campaign

)

SELECT
    COALESCE(fc.source, lc.source) AS source,
    COALESCE(fc.medium, lc.medium) AS medium,
    COALESCE(fc.campaign, lc.campaign) AS campaign,

    COALESCE(fc.purchases, 0) AS first_click_purchases,
    COALESCE(fc.revenue, 0) AS first_click_revenue,

    COALESCE(lc.purchases, 0) AS last_click_purchases,
    COALESCE(lc.revenue, 0) AS last_click_revenue

FROM first_click fc

FULL OUTER JOIN last_click lc
    ON fc.source = lc.source
    AND fc.medium = lc.medium
    AND fc.campaign = lc.campaign

ORDER BY
    last_click_revenue DESC,
    first_click_revenue DESC

LIMIT 25;