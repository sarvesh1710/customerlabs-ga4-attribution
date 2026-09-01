WITH events AS (

    SELECT
        user_pseudo_id,

        (
            SELECT value.int_value
            FROM UNNEST(event_params)
            WHERE key = 'ga_session_id'
        ) AS ga_session_id,

        (
            SELECT value.string_value
            FROM UNNEST(event_params)
            WHERE key = 'source'
        ) AS event_source,

        (
            SELECT value.string_value
            FROM UNNEST(event_params)
            WHERE key = 'medium'
        ) AS event_medium,

        (
            SELECT value.string_value
            FROM UNNEST(event_params)
            WHERE key = 'campaign'
        ) AS event_campaign,

        traffic_source.source AS user_source,
        traffic_source.medium AS user_medium,
        traffic_source.name AS user_campaign

    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

),

sessions AS (

    SELECT
        user_pseudo_id,
        ga_session_id,

        COUNTIF(
            event_source IS NOT NULL
            OR event_medium IS NOT NULL
            OR event_campaign IS NOT NULL
        ) AS attributed_events,

        COUNTIF(
            user_source IS NOT NULL
            OR user_medium IS NOT NULL
            OR user_campaign IS NOT NULL
        ) AS events_with_user_traffic_source

    FROM events

    WHERE ga_session_id IS NOT NULL

    GROUP BY
        user_pseudo_id,
        ga_session_id

)

SELECT
    COUNT(*) AS sessions,

    COUNTIF(attributed_events = 0) AS sessions_without_event_attribution,

    COUNTIF(
        attributed_events = 0
        AND events_with_user_traffic_source > 0
    ) AS sessions_with_user_source_fallback,

    COUNTIF(
        attributed_events = 0
        AND events_with_user_traffic_source = 0
    ) AS sessions_without_any_source

FROM sessions;