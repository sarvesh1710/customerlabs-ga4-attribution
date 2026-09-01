SELECT
    COUNT(*) AS total_rows,

    COUNT(
        DISTINCT CONCAT(
            user_pseudo_id,
            '::',
            CAST(ga_session_id AS STRING)
        )
    ) AS distinct_user_sessions,

    COUNTIF(ga_session_id IS NULL) AS null_session_ids

FROM `customerlabs_ga4.int_ga4_touchpoints`;