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

```

A `--replay` execution against the same event IDs produced:

```text
Mode: REPLAY / IDEMPOTENCY TEST
Total sample events: 10

Batch 1: loaded 0 new events, skipped 4 existing events
Batch 2: loaded 0 new events, skipped 3 existing events
Batch 3: loaded 0 new events, skipped 3 existing events

Total new events loaded: 0
```

### Latency

Each batch load (BigQuery load job submit → job completion) took low-hundreds-of-milliseconds to a few seconds in testing, with a fixed 2-second delay between batches to simulate arrival spacing. This measures ingestion latency into the raw `streamed_events` table only. Materializing `int_streamed_events` and the downstream marts requires a separate `dbt run` — this project does not (yet) wire an automatic trigger (e.g., a scheduled job or Cloud Function) between ingestion and transformation. In a production version, that gap would be closed with either a scheduled dbt Cloud/Composer job on a short interval, or a Cloud Function triggered on load-job completion.

### Known limitations

- The idempotency check (query existing `event_id`s, then load) is check-then-act and not safe against two concurrent producers racing on the same batch. A `MERGE` statement or a uniqueness-enforcing load pattern would remove that race in production.
- This is micro-batch, not true streaming — chosen because BigQuery streaming inserts are unavailable on the free tier used for this assessment. The interface (append-only load + downstream dedup view) is designed so it could be swapped for a real streaming source (Pub/Sub → Dataflow, or the BigQuery Storage Write API) without changing the dbt layer.

## 10. Dashboard

The Streamlit dashboard (`dashboard/app.py`) reads directly from the project's BigQuery marts:

- `mart_attribution_daily` — KPI totals and the 14-day trend
- `mart_dashboard_summary` — channel/source/medium/campaign breakdown
- `int_streamed_events` — the live streamed-events panel

It provides:

- **Attribution Overview** — total purchases, attributed purchases, channel-shift count, and unattributed purchases/revenue as KPI tiles.
- **14-Day Attribution Trend** — a line chart of daily total purchases, attributed purchases, and channel shifts.
- **Channel Attribution Breakdown** — a table comparing First-Click vs Last-Click purchases and revenue by channel/source/medium/campaign.
- **Live Streamed Events** — the most recent 20 rows from `int_streamed_events`, refreshed on a 10-second cache TTL (vs. 30 seconds for the attribution views), plus a manual "Refresh data" button in the sidebar that clears the cache and reruns.

Note: refresh is cache-expiry + rerun based (Streamlit does not push updates to an open tab on its own) — a viewer needs to interact with the page or wait for the next auto-rerun for new data to appear.

## 11. Run Instructions

### Prerequisites

- Python 3.10+
- A Google Cloud project with BigQuery API enabled and billing set up (required to query `bigquery-public-data`, even though that dataset itself is free to query up to the free monthly quota)
- `gcloud` CLI authenticated with a user or service account that has BigQuery Job User + Data Editor on the target project

### Setup

```bash
git clone https://github.com/sarvesh1710/customerlabs-ga4-attribution.git
cd customerlabs-ga4-attribution

python -m venv .venv
source .venv/bin/activate        # .venv\Scripts\activate on Windows

pip install -r requirements.txt

gcloud auth application-default login
gcloud config set project celestial-gist-407221
```

### Build the dbt models

```bash
cd customerlabs_ga4

dbt deps          # if any packages are added later
dbt run
dbt test
dbt docs generate
dbt docs serve    # optional, browses generated documentation locally
```

### Run the streaming demo

```bash
cd ../scripts
python stream_events.py            # loads 10 new events across 3 batches
python stream_events.py --replay   # re-loads the original deterministic IDs to prove idempotency
```

After running the streaming demo, re-run `dbt run --select int_streamed_events` (or a full `dbt run`) so the new rows are reflected in the dashboard's live panel.

### Launch the dashboard

```bash
cd ../dashboard
streamlit run app.py
```

## 12. Failure Handling

| Failure scenario | Behavior today | Recommended handling |
|---|---|---|
| `dbt run` fails mid-DAG (e.g., a source table schema change) | dbt stops and reports the failing model; downstream models are skipped | Add `dbt source freshness` checks on the GA4 source and alert on schema-breaking changes before they reach staging |
| BigQuery is unreachable from the dashboard | `app.py` catches the exception, shows `st.error` with the raw exception, and stops rendering (`st.stop()`) rather than showing partial/stale data | Acceptable for a demo; in production, fall back to last-known-good cached data with a visible "stale data" banner instead of a hard stop |
| Streaming script fails partway through a batch | The failed batch's events are not marked ingested; a re-run will retry only the not-yet-loaded IDs in that batch, since already-loaded IDs are skipped by the existence check | Add a small retry-with-backoff wrapper around `load_batch` for transient BigQuery errors |
| Duplicate `purchase` events in the source GA4 export | Not currently deduplicated in `int_ga4_purchases` (unlike `int_streamed_events`, which dedupes by `event_id`) | Add a `row_number()` dedup on `transaction_id` (or event id) before counting purchases, matching the pattern already used for streamed events |
| Concurrent streaming script runs | Possible race in the check-then-insert idempotency check — both runs could pass the existence check for the same new event before either inserts | Move to a `MERGE`-based upsert, or serialize ingestion through a single writer |

## 13. Monitoring Suggestions

- **Freshness**: alert if `MAX(purchase_date)` in `mart_attribution_daily` falls more than 1 day behind `CURRENT_DATE()` — signals the scheduled `dbt run` didn't execute.
- **Attribution health**: track `unattributed_purchases / total_purchases` day over day; a sudden spike suggests a touchpoint-extraction regression (e.g., a GA4 event-param key change) rather than a genuine traffic shift.
- **Reconciliation check**: `SUM(total_revenue)` from `mart_attribution_daily` should always equal `SUM(first_click_revenue) + unattributed revenue` from the same mart — worth a dbt test, and worth checking against `mart_dashboard_summary` too, since that mart currently excludes unattributed purchases entirely and will not sum to the same total.
- **Streaming lag**: alert if `MAX(ingested_at)` in `int_streamed_events` stops advancing during expected demo/ingestion windows.
- **dbt test failures**: wire `dbt test` exit codes into CI (or a scheduler) so a failing `not_null`/`unique` test blocks promotion rather than silently landing in the mart.

## 14. Cost Notes

- `stg_ga4_events` selects from the full `events_*` wildcard with no `_TABLE_SUFFIX` date filter, so every `dbt run` rescans the entire public sample dataset rather than an incremental slice. For this fixed, finite sample dataset the absolute cost is small, but the pattern would not scale to a live GA4 export — an incremental model filtered on `_TABLE_SUFFIX` (or `event_date`) against a real per-day export is the production fix.
- Marts are materialized as `table`s (full rebuild each run) rather than `incremental`, which is appropriate at this data volume but would need to move to incremental + `merge` for a production-sized event stream.
- The Streamlit dashboard caches query results (30s TTL for attribution views, 10s for the streaming panel) specifically to avoid re-querying BigQuery on every Streamlit rerun/interaction.
- The streaming demo's per-batch existence check (`SELECT event_id ... WHERE event_id IN UNNEST(...)`) is a small, cheap query relative to the load job itself and scales with batch size, not table size.

## 15. Demo

Screencast link: [GA4_Project_demo.mp4](https://drive.google.com/file/d/1UMFw9TDBtXUCpf4pUrlyA6jCK_kUPxsg/view?usp=sharing)

Live walkthrough is also available , covering: architecture, the `mart_purchase_attribution` model, the streaming idempotency demo, and the dashboard.