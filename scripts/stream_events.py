from datetime import datetime, timezone, timedelta
import time

from google.cloud import bigquery


PROJECT_ID = "celestial-gist-407221"
DATASET_ID = "customerlabs_ga4_streaming"
TABLE_ID = "streamed_events"

FULL_TABLE_ID = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"

BATCH_DELAY_SECONDS = 2


def build_sample_events():
    base_time = datetime.now(timezone.utc)

    return [
        {
            "event_id": "stream_demo_001",
            "event_timestamp": base_time - timedelta(seconds=10),
            "user_pseudo_id": "stream_user_001",
            "ga_session_id": 900001,
            "event_name": "page_view",
            "source": "google",
            "medium": "cpc",
            "campaign": "demo_campaign",
            "event_value": None,
        },
        {
            "event_id": "stream_demo_002",
            "event_timestamp": base_time - timedelta(seconds=9),
            "user_pseudo_id": "stream_user_001",
            "ga_session_id": 900001,
            "event_name": "view_item",
            "source": "google",
            "medium": "cpc",
            "campaign": "demo_campaign",
            "event_value": None,
        },
        {
            "event_id": "stream_demo_003",
            "event_timestamp": base_time - timedelta(seconds=8),
            "user_pseudo_id": "stream_user_001",
            "ga_session_id": 900001,
            "event_name": "add_to_cart",
            "source": "google",
            "medium": "cpc",
            "campaign": "demo_campaign",
            "event_value": None,
        },
        {
            "event_id": "stream_demo_004",
            "event_timestamp": base_time - timedelta(seconds=7),
            "user_pseudo_id": "stream_user_002",
            "ga_session_id": 900002,
            "event_name": "page_view",
            "source": "newsletter",
            "medium": "email",
            "campaign": "demo_newsletter",
            "event_value": None,
        },
        {
            "event_id": "stream_demo_005",
            "event_timestamp": base_time - timedelta(seconds=6),
            "user_pseudo_id": "stream_user_002",
            "ga_session_id": 900002,
            "event_name": "view_item",
            "source": "newsletter",
            "medium": "email",
            "campaign": "demo_newsletter",
            "event_value": None,
        },
        {
            "event_id": "stream_demo_006",
            "event_timestamp": base_time - timedelta(seconds=5),
            "user_pseudo_id": "stream_user_002",
            "ga_session_id": 900002,
            "event_name": "purchase",
            "source": "newsletter",
            "medium": "email",
            "campaign": "demo_newsletter",
            "event_value": 129.99,
        },
        {
            "event_id": "stream_demo_007",
            "event_timestamp": base_time - timedelta(seconds=4),
            "user_pseudo_id": "stream_user_003",
            "ga_session_id": 900003,
            "event_name": "page_view",
            "source": "(direct)",
            "medium": "(none)",
            "campaign": "(direct)",
            "event_value": None,
        },
        {
            "event_id": "stream_demo_008",
            "event_timestamp": base_time - timedelta(seconds=3),
            "user_pseudo_id": "stream_user_003",
            "ga_session_id": 900003,
            "event_name": "begin_checkout",
            "source": "(direct)",
            "medium": "(none)",
            "campaign": "(direct)",
            "event_value": None,
        },
        {
            "event_id": "stream_demo_009",
            "event_timestamp": base_time - timedelta(seconds=2),
            "user_pseudo_id": "stream_user_003",
            "ga_session_id": 900003,
            "event_name": "purchase",
            "source": "(direct)",
            "medium": "(none)",
            "campaign": "(direct)",
            "event_value": 79.50,
        },
        {
            "event_id": "stream_demo_010",
            "event_timestamp": base_time - timedelta(seconds=1),
            "user_pseudo_id": "stream_user_004",
            "ga_session_id": 900004,
            "event_name": "page_view",
            "source": "instagram",
            "medium": "social",
            "campaign": "demo_social",
            "event_value": None,
        },
    ]


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
    client = bigquery.Client(project=PROJECT_ID)

    events = build_sample_events()

    batches = [
        events[0:4],
        events[4:7],
        events[7:10],
    ]

    total_inserted = 0

    print(
        f"Starting micro-batch demo for {FULL_TABLE_ID}"
    )
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