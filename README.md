# CustomerLabs GA4 Attribution Engineering Assessment



A BigQuery + dbt data engineering implementation for GA4 purchase attribution, including First-Click and Last-Click attribution, a local micro-batch streaming demonstration, and a Streamlit dashboard.



## 1. Project Overview



This project processes the public GA4 obfuscated ecommerce sample dataset in BigQuery and produces purchase attribution reporting using dbt.



The implementation includes:



- GA4 event staging

- Marketing touchpoint identification

- Purchase event modeling

- First-Click attribution

- Last-Click attribution

- 14-day attribution lookback

- Direct-traffic handling

- Deterministic event ordering

- dbt data quality tests and documentation

- Python micro-batch streaming simulation

- Event-level ingestion idempotency

- Downstream streaming deduplication

- Streamlit attribution dashboard



## 2. Architecture

The high-level flow is:

GA4 public dataset

→ `stg_ga4_events`

→ intermediate purchase/touchpoint models

→ `mart_purchase_attribution`

→ reporting marts

→ Streamlit dashboard

The streaming demonstration follows a separate path:

Python sample events

→ BigQuery load jobs

→ `customerlabs_ga4_streaming.streamed_events`

→ `int_streamed_events`

→ dashboard live-events panel

The handwritten architecture and attribution sketches are available under:

`docs/sketches/`



## 3. Technology Stack



| Area | Technology |

|---|---|

| Source data | BigQuery GA4 public sample dataset |

| Data warehouse | Google BigQuery |

| Transformation | dbt Core |

| Streaming simulation | Python |

| Dashboard | Streamlit |

| Version control | Git |



## 4. Source Dataset



The project uses:



`bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_\*`



The dataset is queried directly from BigQuery and transformed into the project dataset.



## 5. BigQuery Datasets



### Analytics dataset



Project:



`celestial-gist-407221`



Dataset:



`customerlabs_ga4`



Models:



- `stg_ga4_events`

- `int_ga4_purchases`

- `int_ga4_touchpoints`

- `int_streamed_events`

- `mart_purchase_attribution`

- `mart_attribution_daily`

- `mart_dashboard_summary`



### Streaming dataset



Dataset:



`customerlabs_ga4_streaming`



Raw streaming table:



`streamed_events`



## 6. dbt Model Layers



### Staging



`stg_ga4_events`



The staging layer exposes the required GA4 event fields used by downstream models.



Materialization:



`view`



### Intermediate



`int_ga4_purchases`



Extracts purchase events and creates a deterministic purchase event identifier.



`int_ga4_touchpoints`



Builds marketing touchpoints from qualifying page-view events.



`int_streamed_events`



Reads the streamed event table and deduplicates events by `event_id`.



Materialization:



`view`



### Marts



`mart_purchase_attribution`



Produces one attribution record per purchase with First-Click and Last-Click results.



`mart_attribution_daily`



Provides daily purchase, revenue, attribution, channel-shift, and unattributed metrics.



`mart_dashboard_summary`



Provides channel/source/medium/campaign-level First-Click versus Last-Click reporting.



Materialization:



`table`



## 7. Attribution Methodology



### Identity resolution



The implementation uses:



`user_pseudo_id`



as the user-level identity for connecting touchpoints to purchases.



### Lookback window



The attribution window is:



\*\*14 days before the purchase timestamp.\*\*



This was confirmed as an acceptable assumption for the assessment and is documented in the dbt model descriptions.



### Eligible marketing touchpoints



A touchpoint is a `page_view` event with at least one event-level traffic parameter:



- source

- medium

- campaign



Purchase events themselves are not treated as marketing touchpoints.



### Channel normalization



The current channel mapping is:



| Condition | Channel |

|---|---|

| medium = `cpc` | `paid_search` |

| medium = `organic` | `organic_search` |

| medium = `referral` | `referral` |

| source = `(direct)` and medium = `(none)` | `direct` |

| otherwise | `other` |



The original source, medium, and campaign values are retained alongside the normalized channel.



### Consecutive touchpoint handling



Within a user session, consecutive page views with the same normalized channel are collapsed into one touchpoint.



A change in channel starts a new touchpoint.



### First-Click



First-Click receives credit from the \*\*earliest eligible touchpoint\*\* within the 14-day lookback window.



### Last-Click



Last-Click receives credit from the \*\*latest non-direct eligible touchpoint\*\*.



If no non-direct touchpoint exists, the latest direct touchpoint is used as the fallback.



If no eligible touchpoint exists, the purchase is classified as:



`unattributed`



### Deterministic ordering



Touchpoints are ordered using:



1\. `event_timestamp`

2\. `event_bundle_sequence_id`

3\. `touchpoint_id`



This provides deterministic behavior when timestamps need a secondary ordering key.



## 8. Attribution Validation



The implemented model currently produces:



| Metric | Result |

|---|---:|

| Total purchases | 5,692 |

| First-Click attributed | 5,330 |

| Last-Click attributed | 5,330 |

| Unattributed purchases | 362 |

| First-vs-Last channel shifts | 2,323 |

| Total revenue | $362,165 |

| Unattributed revenue | $19,458 |



The attribution results also show meaningful differences between models.



First-Click assigns more purchase credit to Organic Search, while Last-Click assigns more credit to Referral.



This demonstrates why the choice of attribution model changes channel-level performance interpretation.



## 9. Streaming Demonstration



The assignment allows a local Python streaming simulation, so the project implements streaming as micro-batches using a local Python script and BigQuery load jobs.



The script is:



`scripts/stream_events.py`



Each normal execution generates 10 sample events and processes them in three batches:



- Batch 1: 4 events

- Batch 2: 3 events

- Batch 3: 3 events



Normal executions generate unique event IDs using a run identifier. This allows repeated executions to represent new incoming events without reusing the same IDs.



### Idempotency



Before inserting a batch, the script checks the existing `event_id` values in the raw streaming table.



Existing IDs are skipped before the load job is submitted.



The script also provides a `--replay` mode that intentionally uses the original deterministic event IDs. This makes duplicate handling easy to demonstrate.



A normal execution produced:



```text

Mode: NEW EVENT RUN

Total sample events: 10



Batch 1: loaded 4 new events, skipped 0 existing events

Batch 2: loaded 3 new events, skipped 0 existing events

Batch 3: loaded 3 new events, skipped 0 existing events



Total new events loaded: 10
