SELECT
    COUNT(*) AS total_purchases,

    COUNTIF(
        first_click_source != last_click_source
        OR first_click_medium != last_click_medium
        OR first_click_campaign != last_click_campaign
    ) AS purchases_with_different_first_last,

    COUNTIF(
        first_click_timestamp = last_click_timestamp
    ) AS purchases_with_same_timestamp

FROM `customerlabs_ga4.mart_purchase_attribution`;