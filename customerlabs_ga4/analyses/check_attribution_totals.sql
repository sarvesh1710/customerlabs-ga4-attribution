SELECT
    'First Click' AS attribution_model,
    COUNT(*) AS purchases,
    SUM(purchase_revenue) AS revenue
FROM `customerlabs_ga4.mart_purchase_attribution`
WHERE first_click_timestamp IS NOT NULL

UNION ALL

SELECT
    'Last Click' AS attribution_model,
    COUNT(*) AS purchases,
    SUM(purchase_revenue) AS revenue
FROM `customerlabs_ga4.mart_purchase_attribution`
WHERE last_click_timestamp IS NOT NULL;