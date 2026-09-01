WITH session_sources AS (

    SELECT
        user_pseudo_id,

        (
            SELECT value.int_value
            FROM UNNEST(event_params)
            WHERE key = 'ga_session_id'
        ) AS ga_session_id,

        COUNT(DISTINCT traffic_source) AS source_values,
        COUNT(DISTINCT traffic_medium) AS medium_values,
        COUNT(DISTINCT traffic_campaign) AS campaign_values

    FROM `customerlabs_ga4.stg_ga4_events`

    GROUP BY
        user_pseudo_id,
        ga_session_id

)

SELECT
    COUNT(*) AS total_sessions,

    COUNTIF(
        source_values > 1
        OR medium_values > 1
        OR campaign_values > 1
    ) AS sessions_with_multiple_traffic_values,

    COUNTIF(source_values > 1) AS sessions_multiple_sources,
    COUNTIF(medium_values > 1) AS sessions_multiple_mediums,
    COUNTIF(campaign_values > 1) AS sessions_multiple_campaigns

FROM session_sources

WHERE ga_session_id IS NOT NULL;