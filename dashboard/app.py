import streamlit as st
from google.cloud import bigquery
import pandas as pd


# ---------------------------------------------------------
# Configuration
# ---------------------------------------------------------

PROJECT_ID = "celestial-gist-407221"
DATASET_ID = "customerlabs_ga4"

ATTRIBUTION_TABLE = f"{PROJECT_ID}.{DATASET_ID}.mart_purchase_attribution"
DAILY_TABLE = f"{PROJECT_ID}.{DATASET_ID}.mart_attribution_daily"
CHANNEL_TABLE = f"{PROJECT_ID}.{DATASET_ID}.mart_dashboard_summary"
STREAM_TABLE = f"{PROJECT_ID}.{DATASET_ID}.int_streamed_events"


# ---------------------------------------------------------
# Page configuration
# ---------------------------------------------------------

st.set_page_config(
    page_title="GA4 Attribution Dashboard",
    page_icon="📊",
    layout="wide",
)


# ---------------------------------------------------------
# BigQuery client
# ---------------------------------------------------------

@st.cache_resource
def get_bigquery_client():
    return bigquery.Client(project=PROJECT_ID)


client = get_bigquery_client()


# ---------------------------------------------------------
# Query helper
# ---------------------------------------------------------

@st.cache_data(ttl=30)
def run_query(query):
    return client.query(query).to_dataframe()


# ---------------------------------------------------------
# Load dashboard data
# ---------------------------------------------------------

@st.cache_data(ttl=30)
def load_summary():
    query = f"""
        SELECT
            SUM(total_purchases) AS total_purchases,
            SUM(first_click_purchases) AS attributed_purchases,
            SUM(channel_shift_purchases) AS channel_shift_purchases,
            SUM(unattributed_purchases) AS unattributed_purchases,
            SUM(total_revenue) AS total_revenue,
            SUM(unattributed_revenue) AS unattributed_revenue
        FROM `{DAILY_TABLE}`
    """

    return run_query(query)


@st.cache_data(ttl=30)
def load_daily():
    query = f"""
        SELECT
            PARSE_DATE('%Y%m%d', purchase_date) AS purchase_date,
            total_purchases,
            total_revenue,
            first_click_purchases,
            first_click_revenue,
            last_click_purchases,
            last_click_revenue,
            channel_shift_purchases,
            unattributed_purchases,
            unattributed_revenue
        FROM `{DAILY_TABLE}`
        ORDER BY purchase_date DESC
        LIMIT 14
    """

    df = run_query(query)

    df["attributed_purchases"] = df["first_click_purchases"]

    return df.sort_values("purchase_date")

@st.cache_data(ttl=30)
def load_channels():
    query = f"""
        SELECT
            channel,
            source,
            medium,
            campaign,
            first_click_purchases,
            first_click_revenue,
            last_click_purchases,
            last_click_revenue
        FROM `{CHANNEL_TABLE}`
        ORDER BY last_click_revenue DESC
    """

    return run_query(query)


@st.cache_data(ttl=10)
def load_streamed_events():
    query = f"""
        SELECT
            event_id,
            event_timestamp,
            user_pseudo_id,
            ga_session_id,
            event_name,
            source,
            medium,
            campaign,
            event_value,
            ingested_at
        FROM `{STREAM_TABLE}`
        ORDER BY ingested_at DESC
        LIMIT 20
    """

    return run_query(query)


# ---------------------------------------------------------
# Header
# ---------------------------------------------------------

st.title("GA4 Attribution Dashboard")

st.caption(
    "First-Click and Last-Click attribution with a near-real-time "
    "micro-batch streaming demonstration"
)


# ---------------------------------------------------------
# Sidebar
# ---------------------------------------------------------

with st.sidebar:
    st.header("Dashboard Controls")

    if st.button("Refresh data"):
        st.cache_data.clear()
        st.rerun()

    st.divider()

    st.markdown(
        """
        **Data sources**

        - `mart_dashboard_summary`
        - `mart_attribution_daily`
        - `int_streamed_events`

        Dashboard cache:
        - Attribution data: 30 seconds
        - Streaming events: 10 seconds
        """
    )


# ---------------------------------------------------------
# Load data
# ---------------------------------------------------------

try:
    summary = load_summary()
    daily = load_daily()
    channels = load_channels()
    streamed_events = load_streamed_events()

except Exception as exc:
    st.error("Unable to load dashboard data from BigQuery.")

    st.exception(exc)

    st.stop()


# ---------------------------------------------------------
# KPI calculations
# ---------------------------------------------------------

total_purchases = int(
    summary["total_purchases"].iloc[0] or 0
)

attributed_purchases = int(
    summary["attributed_purchases"].iloc[0] or 0
)

channel_shift_purchases = int(
    summary["channel_shift_purchases"].iloc[0] or 0
)

unattributed_purchases = int(
    summary["unattributed_purchases"].iloc[0] or 0
)

total_revenue = float(
    summary["total_revenue"].iloc[0] or 0
)

unattributed_revenue = float(
    summary["unattributed_revenue"].iloc[0] or 0
)

attribution_rate = (
    attributed_purchases / total_purchases * 100
    if total_purchases
    else 0
)

channel_shift_rate = (
    channel_shift_purchases / attributed_purchases * 100
    if attributed_purchases
    else 0
)

unattributed_rate = (
    unattributed_purchases / total_purchases * 100
    if total_purchases
    else 0
)

# ---------------------------------------------------------
# Attribution KPIs
# ---------------------------------------------------------
st.subheader("Attribution Overview")

col1, col2, col3, col4 = st.columns(4)

with col1:
    st.metric(
        "Total Purchases",
        f"{total_purchases:,}",
    )

with col2:
    st.metric(
        "Attributed Purchases",
        f"{attributed_purchases:,}",
        delta=f"{attribution_rate:.1f}% attributed",
    )

with col3:
    st.metric(
        "Channel Shifts",
        f"{channel_shift_purchases:,}",
        delta=f"{channel_shift_rate:.1f}% of attributed",
    )

with col4:
    st.metric(
        "Unattributed Purchases",
        f"{unattributed_purchases:,}",
        delta=f"{unattributed_rate:.1f}% of total",
        delta_color="inverse",
    )

st.caption(
    f"Total revenue: ${total_revenue:,.2f} | "
    f"Unattributed revenue: ${unattributed_revenue:,.2f}"
)


st.divider()


# ---------------------------------------------------------
# 14-day time series
# ---------------------------------------------------------

st.subheader("14-Day Attribution Trend")

if daily.empty:
    st.info("No daily attribution data available.")

else:
    chart_data = daily.set_index("purchase_date")[
        [
            "total_purchases",
            "attributed_purchases",
            "channel_shift_purchases",
        ]
    ]

    chart_data.columns = [
        "Total Purchases",
        "Attributed Purchases",
        "Channel Shifts",
    ]

    st.line_chart(chart_data)

    st.caption(
        "Daily purchase volume, attributed conversions, and First-vs-Last channel shifts."
    )

st.divider()


# ---------------------------------------------------------
# Channel breakdown
# ---------------------------------------------------------

st.subheader("Channel Attribution Breakdown")

if channels.empty:
    st.info("No channel attribution data available.")

else:
    channel_display = channels.copy()

    channel_display = channel_display[
        [
            "channel",
            "source",
            "medium",
            "campaign",
            "first_click_purchases",
            "first_click_revenue",
            "last_click_purchases",
            "last_click_revenue",
        ]
    ]

    channel_display.columns = [
        "Channel",
        "Source",
        "Medium",
        "Campaign",
        "First-Click Purchases",
        "First-Click Revenue",
        "Last-Click Purchases",
        "Last-Click Revenue",
    ]
    st.dataframe(
        channel_display,
        width="stretch",
        hide_index=True,
    )


st.divider()


# ---------------------------------------------------------
# Live streaming panel
# ---------------------------------------------------------

st.subheader("Live Streamed Events")

st.caption(
    "Events loaded into BigQuery by the Python micro-batch streaming demo."
)

if streamed_events.empty:
    st.info("No streamed events available.")

else:
    display_events = streamed_events.copy()

    display_events["event_timestamp"] = pd.to_datetime(
        display_events["event_timestamp"]
    )

    display_events["ingested_at"] = pd.to_datetime(
        display_events["ingested_at"]
    )

    display_events = display_events[
        [
            "event_id",
            "event_timestamp",
            "user_pseudo_id",
            "ga_session_id",
            "event_name",
            "source",
            "medium",
            "campaign",
            "event_value",
            "ingested_at",
        ]
    ]

    display_events.columns = [
        "Event ID",
        "Event Timestamp",
        "User",
        "Session ID",
        "Event",
        "Source",
        "Medium",
        "Campaign",
        "Value",
        "Ingested At",
    ]

    st.dataframe(
        display_events,
        width="stretch",
        hide_index=True,
    )


# ---------------------------------------------------------
# Footer
# ---------------------------------------------------------

st.divider()

st.caption(
    "GA4 Attribution Demo | BigQuery + dbt + Streamlit | "
    "Streaming implemented as a free-tier micro-batch demonstration"
)