# Worklog

## 2026-08-31 â€” Project setup and staging
- Initialized the repository and dbt project structure.
- Configured the BigQuery project and dbt development target.
- Added the GA4 staging model for the public ecommerce sample dataset.
- Verified the staging model against the available GA4 event structure.

## 2026-08-31 â€” Attribution model implementation
- Built the purchase and touchpoint intermediate models.
- Implemented First-Click and Last-Click attribution using user-level journey history.
- Chose a 14-day lookback window and documented it as an assignment assumption.

## 2026-08-31 â€” Touchpoint validation
- Investigated event-level traffic parameters in the GA4 sample data.
- Defined marketing touchpoints using page_view events with available source, medium, or campaign information.
- Validated channel transitions and checked cases where the first and last eligible channels differ.

## 2026-09-01 â€” Attribution edge cases
- Reviewed direct-traffic behavior in the attribution model.
- Implemented Last-Click logic that prefers the latest non-direct touchpoint, with direct used as fallback when no non-direct touchpoint exists.
- Added deterministic ordering using event timestamp, event bundle sequence, and touchpoint ID.

## 2026-09-01 â€” Attribution reporting marts
- Added daily attribution reporting and dashboard summary marts.
- Validated purchase, revenue, attributed, channel-shift, and unattributed totals against the purchase attribution model.
- Added dbt schema documentation and data quality tests.

## 2026-09-01 â€” Streaming demo
- Implemented a Python micro-batch streaming simulation using deterministic sample event IDs.
- Used BigQuery load jobs because streaming inserts are unavailable in the current free-tier project.
- Added ingestion-side event ID checks to prevent replayed events from being inserted again.

## 2026-09-02 â€” Streaming idempotency validation
- Replayed the same 10 deterministic sample events against the streaming table.
- The ingestion script loaded 0 new events and skipped all 10 existing event IDs.
- Verified the raw table remained at 17 rows with 10 unique event IDs.
- Rebuilt `int_streamed_events` and verified 10 model rows with 10 unique event IDs.
- All 7 streaming model data tests passed.

## 2026-09-02 â€” Dashboard implementation
- Added the Streamlit attribution dashboard.
- Added KPI metrics, a 14-day attribution view, channel-level First-Click versus Last-Click reporting, and live streamed events.
- Added the BigQuery Storage dependency for dashboard query performance.
- Verified the dashboard against the BigQuery models.

## 2026-09-03 â€” Streaming run and idempotency validation
- Updated the streaming demo so normal runs generate unique event IDs while preserving the original deterministic IDs for replay testing.
- Ran a new-event micro-batch execution and loaded 10 new events across three batches.
- Replayed the deterministic sample events and verified that all 10 existing event IDs were skipped.
- Verified the raw streaming table contained 27 rows and 20 unique event IDs after the test runs.
- Rebuilt the downstream streaming model and verified 20 rows with 20 unique event IDs.
