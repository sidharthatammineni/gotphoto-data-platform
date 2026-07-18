# GotPhoto — Data Platform Assignment

A production-minded analytical data product built with **dbt + Snowflake**, using the TPC-H sample dataset. Submitted for the Data Platform Lead role at GotPhoto.

---

## Architecture

This project follows the **Medallion Architecture** (Bronze → Silver → Gold):

```
SNOWFLAKE_SAMPLE_DATA.TPCH_SF1   ← Raw source (external, read-only)
         │
         ▼
  Staging (Bronze)                ← Views: rename + cast raw columns
         │
         ▼
  Intermediate (Silver)           ← Ephemeral CTEs: joins + enrichment
         │
         ▼
  Marts (Gold)                    ← Physical tables: business-ready datasets
```

| Layer | Materialization | Purpose |
|---|---|---|
| `models/staging/` | View | Rename raw TPC-H columns to clean names; no business logic |
| `models/intermediate/` | Ephemeral | Join and enrich; inlined as CTEs, no Snowflake storage cost |
| `models/marts/` | Table | Final analytical tables consumed by BI tools and analysts |

---

## Models

### Staging (7 views)
| Model | Source Table | Rows |
|---|---|---|
| `stg_tpch__orders` | ORDERS | 1,500,000 |
| `stg_tpch__lineitems` | LINEITEM | 6,001,215 |
| `stg_tpch__customers` | CUSTOMER | 150,000 |
| `stg_tpch__parts` | PART | 200,000 |
| `stg_tpch__suppliers` | SUPPLIER | 10,000 |
| `stg_tpch__nations` | NATION | 25 |
| `stg_tpch__regions` | REGION | 5 |

### Intermediate (2 ephemeral CTEs)
| Model | Description |
|---|---|
| `int_orders__enriched` | Orders joined with customers, nations, regions, and aggregated line items |
| `int_lineitems__enriched` | Line items joined with parts, suppliers, nations, regions |

### Marts (4 tables)
| Model | Rows | Business Questions Answered |
|---|---|---|
| `mart_orders` | 1,500,000 | Revenue trends, order volumes, fulfillment rates, return rates by region/segment |
| `mart_customers` | 99,996 | Customer lifetime value, customer tiers (Platinum/Gold/Silver/Bronze), order history |
| `mart_customers_rfm` | 99,996 | Who are our most valuable customers? Who is at risk of churning? RFM segmentation for marketing |
| `mart_revenue_by_month` | ~10,000 | Monthly revenue trends by market segment, nation, region |

---

## Business Questions Answered

1. **Which customers drive the most revenue?** → `mart_customers` (lifetime_revenue, customer_tier)
2. **Who is at risk of churning?** → `mart_customers_rfm` (rfm_segment = 'At Risk' or 'Lost')
3. **Which regions and segments are growing?** → `mart_revenue_by_month` (grouped by region_name, market_segment, month)
4. **How long does it take to fulfill orders?** → `mart_orders` (days_to_first_shipment)
5. **What is the return rate trend?** → `mart_orders`, `mart_revenue_by_month` (return_rate)
6. **Which customers should marketing prioritize?** → `mart_customers_rfm` (Champions, Loyal Customers segments)

---

## Key Design Decisions

### RFM Scoring (Snowpark Python)
`mart_customers_rfm` is built using a **Snowpark Python model** — demonstrates Python-native ML-style scoring inside Snowflake without moving data. Uses `percent_rank()` window functions to compute quintile scores (1–5) for Recency, Frequency, and Monetary value, then segments customers into: Champions, Loyal Customers, Potential Loyalists, At Risk, Lost.

### SCD Type 2 Snapshot
`snapshots/orders_snapshot.sql` tracks historical changes to `order_status` and `order_total_price` using dbt's `check` strategy. Enables point-in-time queries: *"What was the order status on date X?"*

### `safe_divide` Macro
`macros/safe_divide.sql` prevents division-by-zero across all rate calculations (return_rate, discount_vs_retail, actual_unit_price). Used in intermediate and mart models.

---

## Tests (67 total, all passing)

Tests are configured in `.yml` files co-located with each model layer.

| Test Type | Purpose | Where Applied |
|---|---|---|
| `unique` | No duplicate primary keys | All PKs in staging and marts |
| `not_null` | Required fields are populated | All key columns |
| `accepted_values` | Enum validation | order_status (O/F/P), market_segment, customer_tier, rfm_segment, return_flag |
| `dbt_utils.accepted_range` | Numeric bounds | discount_rate (0–1), RFM scores (1–5), rfm_score (3–15) |
| `relationships` | Referential integrity | FK → PK checks across staging and mart layers |

Run all tests:
```bash
dbt test
```

Run tests for a specific model:
```bash
dbt test --select mart_customers_rfm
```

---

## How to Run

### Prerequisites
- Python 3.12+
- Snowflake account with access to `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1`
- `~/.dbt/profiles.yml` configured (see below)

### Setup
```bash
# Clone and set up virtual environment
cd GotPhoto
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Install dbt packages (dbt_utils, elementary)
cd gotphoto
dbt deps
```

### `~/.dbt/profiles.yml`
```yaml
gotphoto:
  outputs:
    dev:
      type: snowflake
      account: <your-account>
      user: <your-user>
      password: <your-password>
      role: ACCOUNTADMIN
      database: GOTPHOTO_DEV
      schema: dbt_dev
      warehouse: COMPUTE_WH
      threads: 4
  target: dev
```

### Run the full pipeline
```bash
dbt run          # Build all models
dbt test         # Run all 67 tests
dbt snapshot     # Run SCD Type 2 snapshot on orders
```

### Run individual layers
```bash
dbt run --select staging
dbt run --select intermediate
dbt run --select marts
dbt run --select mart_customers_rfm   # Python model
```

---

## Observability & Alerting

[Elementary](https://www.elementary-data.com/) is configured for data observability.

### Initialize Elementary (first time only)
```bash
dbt run -s elementary
```

### Send Slack alerts for test failures
```bash
edr monitor \
  --slack-webhook "<your-slack-webhook-url>" \
  --project-dir /path/to/gotphoto \
  --profiles-dir ~/.dbt \
  --days-back 1
```

Elementary monitors all dbt test results and sends Slack notifications when tests fail, including which model, which test, and how many rows failed.

---

## Orchestration Strategy

For production, this pipeline would be orchestrated with **Airflow** (or Dagster):

```
Daily DAG:
  1. source freshness check     → dbt source freshness
  2. run staging models         → dbt run --select staging
  3. run marts                  → dbt run --select marts
  4. run snapshot               → dbt snapshot
  5. run all tests              → dbt test
  6. send Elementary alerts     → edr monitor ...
```

Scheduling rationale:
- **Staging + Marts**: daily (TPC-H is batch; real GotPhoto data would follow upload cadence)
- **Snapshot**: daily to capture any order status changes (SCD Type 2)
- **Tests**: after every run to catch data quality issues before downstream consumers see bad data

For the GotPhoto use case (photo studio orders), the pipeline would trigger on new uploads from studios rather than on a fixed schedule — event-driven via S3/Kafka → Snowpipe → dbt.

---

## Production Readiness Notes

- **Data Contracts**: Source definitions in `src_tpch.yml` act as contracts — if the upstream schema changes, `dbt source freshness` and column-level tests will catch it before data reaches marts.
- **Observability**: Elementary tracks test results over time, enabling anomaly detection and trend-based alerting beyond simple pass/fail.
- **AI-Agent Readiness**: `mart_customers_rfm` is designed as a direct feed for CRM automation or AI targeting agents — one row per customer with pre-computed segments and scores.
- **Scalable Ingestion**: The staging layer is the ingestion boundary. Swapping TPC-H for real GotPhoto data only requires updating `src_tpch.yml` source pointers — all downstream models remain unchanged.
- **Migration Continuity**: SCD Type 2 snapshots ensure historical order state is preserved even as source data mutates, enabling safe migrations and audits.

---

## Project Structure

```
gotphoto/
├── dbt_project.yml              # Project config, materializations by layer
├── packages.yml                 # dbt_utils, elementary
├── elementary_config.yml        # Slack webhook config
├── macros/
│   └── safe_divide.sql          # Division-by-zero safe macro
├── models/
│   ├── staging/tpch/
│   │   ├── src_tpch.yml         # Source definitions + freshness checks
│   │   ├── stg_tpch.yml         # Staging model tests
│   │   └── stg_tpch__*.sql      # 7 staging views
│   ├── intermediate/
│   │   ├── int_orders__enriched.sql
│   │   └── int_lineitems__enriched.sql
│   └── marts/
│       ├── customers/
│       │   ├── mart_customers.sql
│       │   ├── mart_customers_rfm.py    # Snowpark Python model
│       │   └── *.yml
│       ├── orders/
│       │   ├── mart_orders.sql
│       │   └── mart_orders.yml
│       └── finance/
│           ├── mart_revenue_by_month.sql
│           └── mart_revenue_by_month.yml
└── snapshots/
    └── orders_snapshot.sql      # SCD Type 2 on order_status + order_total_price
```
