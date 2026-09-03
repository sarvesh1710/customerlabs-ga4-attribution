from datetime import datetime, timezone, timedelta
import argparse
import time
import uuid

from google.cloud import bigquery


PROJECT_ID = "celestial-gist-407221"
DATASET_ID = "customerlabs_ga4_streaming"
TABLE_ID = "streamed_events"

FULL_TABLE_ID = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"

BATCH_DELAY_SECONDS = 2


def build_sample_events(replay=False):
    base_time = datetime.now(timezone.utc)

    run_id = "replay" if replay else uuid.uuid4().hex[:8]

    event_definitions = [
        {
            "user_pseudo_id": "stream_user_001",
            "ga_session_id": 900001,
            "event_name": "page_view",
            "source": "google",
            "medium": "cpc",
            "campaign": "demo_campaign",
            "event_value": None,
        },
        {
            "user_pseudo_id": "stream_user_001",
            "ga_session_id": 900001,
            "event_name": "view_item",
            "source": "google",
            "medium": "cpc",
            "campaign": "demo_campaign",
            "event_value": None,
        },
        {
            "user_pseudo_id": "stream_user_001",
            "ga_session_id": 900001,
            "event_name": "add_to_cart",
            "source": "google",
            "medium": "cpc",
            "campaign": "demo_campaign",
            "event_value": None,
        },
        {
            "user_pseudo_id": "stream_user_002",
            "ga_session_id": 900002,
            "event_name": "page_view",
            "source": "newsletter",
            "medium": "email",
            "campaign": "demo_newsletter",
            "event_value": None,
        },
        {
            "user_pseudo_id": "stream_user_002",
            "ga_session_id": 900002,
            "event_name": "view_item",
            "source": "newsletter",
            "medium": "email",
            "campaign": "demo_newsletter",
            "event_value": None,
        },
        {
            "user_pseudo_id": "stream_user_002",
            "ga_session_id": 900002,
            "event_name": "purchase",
            "source": "newsletter",
            "medium": "email",
            "campaign": "demo_newsletter",
            "event_value": 129.99,
        },
        {
            "user_pseudo_id": "stream_user_003",
            "ga_session_id": 900003,
            "event_name": "page_view",
            "source": "(direct)",
            "medium": "(none)",
            "campaign": "(direct)",
            "event_value": None,
        },
        {
            "user_pseudo_id": "stream_user_003",
            "ga_session_id": 900003,
            "event_name": "begin_checkout",
            "source": "(direct)",
            "medium": "(none)",
            "campaign": "(direct)",
            "event_value": None,
        },
        {
            "user_pseudo_id": "stream_user_003",
            "ga_session_id": 900003,
            "event_name": "purchase",
            "source": "(direct)",
            "medium": "(none)",
            "campaign": "(direct)",
            "event_value": 79.50,
        },
        {
            "user_pseudo_id": "stream_user_004",
            "ga_session_id": 900004,
            "event_name": "page_view",
            "source": "instagram",
            "medium": "social",
            "campaign": "demo_social",
            "event_value": None,
        },
    ]

    events = []

    for index, definition in enumerate(event_definitions, start=1):
        if replay:
            event_id = f"stream_demo_{index:03d}"
        else:
            event_id = f"stream_{run_id}_{index:03d}"

        event = {
            "event_id": event_id,
            "event_timestamp": base_time - timedelta(
                seconds=11 - index
            ),
            **definition,
        }

        events.append(event)

    return events


def load_batch(client, batch):
    existing_query = f"""
        SELECT event_id
        FROM `{FULL_TABLE_ID}`
        WHERE event_id IN UNNEST(@event_ids)
    """

    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ArrayQueryParameter(
                "event_ids",
                "STRING",
                [event["event_id"] for event in batch],
            )
        ]
    )

    existing_rows = client.query(
        existing_query,
        job_config=job_config,
    ).result()

    existing_ids = {row.event_id for row in existing_rows}

    new_events = [
        event
        for event in batch
        if event["event_id"] not in existing_ids
    ]

    if not new_events:
        return 0, 0.0, len(batch)

    rows = []

    ingested_at = datetime.now(timezone.utc).isoformat()

    for event in new_events:
        rows.append(
            {
                "event_id": event["event_id"],
                "event_timestamp": event["event_timestamp"].isoformat(),
                "user_pseudo_id": event["user_pseudo_id"],
                "ga_session_id": event["ga_session_id"],
                "event_name": event["event_name"],
                "source": event["source"],
                "medium": event["medium"],
                "campaign": event["campaign"],
                "event_value": event["event_value"],
                "ingested_at": ingested_at,
            }
        )

    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND
    )

    start_time = datetime.now(timezone.utc)

    job = client.load_table_from_json(
        rows,
        FULL_TABLE_ID,
        job_config=job_config,
    )

    job.result()

    end_time = datetime.now(timezone.utc)

    latency_ms = (
        end_time - start_time
    ).total_seconds() * 1000

    return len(rows), latency_ms, len(batch) - len(rows)


def main():
    parser = argparse.ArgumentParser(
        description="Run the BigQuery micro-batch streaming demo."
    )

    parser.add_argument(
        "--replay",
        action="store_true",
        help="Replay the original deterministic event IDs to demonstrate idempotency.",
    )

    args = parser.parse_args()

    client = bigquery.Client(project=PROJECT_ID)

    events = build_sample_events(
        replay=args.replay
    )

    batches = [
        events[0:4],
        events[4:7],
        events[7:10],
    ]

    total_inserted = 0

    mode = "REPLAY / IDEMPOTENCY TEST" if args.replay else "NEW EVENT RUN"

    print(
        f"Starting micro-batch demo for {FULL_TABLE_ID}"
    )
    print(f"Mode: {mode}")
    print(f"Total sample events: {len(events)}")
    print()

    for batch_number, batch in enumerate(
        batches,
        start=1,
    ):
        inserted, latency_ms, skipped = load_batch(
            client,
            batch,
        )

        total_inserted += inserted

        print(
            f"Batch {batch_number}: "
            f"loaded {inserted} new events, "
            f"skipped {skipped} existing events "
            f"in {latency_ms:.2f} ms"
        )

        if batch_number < len(batches):
            time.sleep(BATCH_DELAY_SECONDS)

    print()
    print(
        f"Total new events loaded: {total_inserted}"
    )
    print("Micro-batch ingestion completed.")


if __name__ == "__main__":
    main()