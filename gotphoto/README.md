# GotPhoto Data Platform Assignment

A production-minded analytical data product built with dbt and Snowflake, using the TPC-H sample dataset. Submitted for the Data Platform Lead role at GotPhoto.

---

## Architecture

This project follows the Medallion Architecture (Bronze, Silver, Gold):

```
SNOWFLAKE_SAMPLE_DATA.TPCH_SF1   <- Raw source (external, read-only)
         |
         v
  Staging (Bronze)                <- Views: rename and clean raw columns
         |
         v
  Intermediate (Silver)           <- Ephemeral CTEs: joins and enrichment
         |
         v
  Marts (Gold)                    <- Physical tables: business-ready datasets
```

| Layer | Materialization | Purpose |
|---|---|---|
| `models/staging/` | View | Rename raw TPC-H columns to clean names. No business logic. |
| `models/intermediate/` | Ephemeral | Join and enrich data. Inlined as CTEs, no Snowflake storage cost. |
| `models/marts/` | Table | Final analytical tables for BI tools and analysts. |

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

| Model | Grain | Rows | Target Users |
|---|---|---|---|
| `mart_orders` | One row per order | 1,500,000 | Analysts, Operations, Finance |
| `mart_customers` | One row per customer | 99,996 | Analysts, CRM, Finance |
| `mart_customers_rfm` | One row per customer | 99,996 | Marketing, CRM teams |
| `mart_revenue_by_month` | One row per month, segment, region, nation | ~10,000 | Finance, Executives |

---

## Business Questions Answered

1. Which customers drive the most revenue? See `mart_customers` (lifetime_revenue, customer_tier)
2. Who is at risk of churning? See `mart_customers_rfm` (rfm_segment = 'At Risk' or 'Lost')
3. Which regions and segments are growing? See `mart_revenue_by_month` (grouped by region_name, market_segment, month)
4. How long does it take to fulfill orders? See `mart_orders` (days_to_first_shipment)
5. What is the return rate trend? See `mart_orders` and `mart_revenue_by_month` (return_rate)
6. Which customers should marketing prioritize? See `mart_customers_rfm` (Champions, Loyal Customers segments)

---

## Key Design Decisions

### Why SQL for most models?

SQL is the default for all staging, intermediate, and mart models because it is readable, version-controlled, and easy for any analyst to understand and maintain. Business logic is expressed clearly without needing a Python environment.

### Why Python for the RFM model?

The RFM model (`mart_customers_rfm`) is the one exception where Python adds real value. RFM scoring requires computing quintile rankings across the entire customer dataset, which involves chained window functions and conditional scoring logic. Snowpark Python makes this easier to read and maintain compared to deeply nested SQL. It also runs entirely inside Snowflake so no data moves out.

### SCD Type 2 Snapshot

`snapshots/orders_snapshot.sql` tracks historical changes to `order_status` and `order_total_price` using dbt's check strategy. This allows point-in-time queries like "What was the order status on a specific date?" and provides a full audit trail for compliance.

### safe_divide Macro

`macros/safe_divide.sql` prevents division-by-zero errors across all rate calculations (return_rate, discount_vs_retail, actual_unit_price). It is reused across intermediate and mart models instead of repeating the CASE WHEN logic everywhere.

---

## Tests (67 total, all passing)

Tests are configured in `.yml` files placed next to each model.

| Test Type | Purpose | Where Applied |
|---|---|---|
| `unique` | No duplicate primary keys | All PKs in staging and marts |
| `not_null` | Required fields are always populated | All key columns |
| `accepted_values` | Enum fields only contain valid values | order_status (O/F/P), market_segment, customer_tier, rfm_segment, return_flag |
| `dbt_utils.accepted_range` | Numeric fields stay within valid bounds | discount_rate (0 to 1), RFM scores (1 to 5), rfm_score (3 to 15) |
| `relationships` | Foreign keys point to valid primary keys | FK to PK checks across staging and mart layers |

### Why these tests?

- **unique and not_null** catch the most common data quality issues: duplicate records and missing values that would silently break downstream reports.
- **accepted_values** ensures business-critical enums like order_status and customer_tier never contain unexpected values that would make dashboards misleading.
- **accepted_range** validates that calculated scores like RFM quintiles always fall within the expected 1 to 5 range. If the scoring logic breaks, this catches it immediately.
- **relationships** validates referential integrity across models. For example, every order must have a valid customer. Without this, joins in marts would silently drop rows.

Run all tests:
```bash
dbt test
```

Run tests for a specific model:
```bash
dbt test --select mart_customers_rfm
```

---

## Source Validations

Configured in `models/staging/tpch/src_tpch.yml`.

- **Freshness checks**: warn if source data is older than 7 days, error if older than 30 days. This catches upstream pipeline failures before bad data reaches marts.
- **Volume checks**: row count tests on key tables ensure the source did not deliver an empty or truncated load.
- **Value checks**: accepted_values tests on source columns (e.g. order_status, return_flag) catch schema changes or unexpected values at the earliest possible point in the pipeline.

Run source freshness check:
```bash
dbt source freshness
```

---

## How to Run

### Prerequisites
- Python 3.12+
- Snowflake account with access to `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1`
- `~/.dbt/profiles.yml` configured (see below)

### Setup
```bash
git clone https://github.com/sidharthatammineni/gotphoto-data-platform.git
cd gotphoto-data-platform
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cd gotphoto
dbt deps
```

### profiles.yml
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
dbt run --select marts
dbt run --select mart_customers_rfm
```

---

## Observability and Alerting

Elementary is configured for data observability. It tracks test results over time and sends Slack alerts when tests fail.

### Initialize Elementary (first time only)
```bash
dbt run -s elementary
```

### Send Slack alerts
```bash
edr monitor \
  --slack-webhook "<your-slack-webhook-url>" \
  --project-dir /path/to/gotphoto \
  --profiles-dir ~/.dbt \
  --days-back 1
```

---

## CI/CD

GitHub Actions runs on every push to `main` and can also be triggered manually from the Actions tab.

Pipeline steps:
1. Install dependencies
2. dbt compile (syntax check)
3. dbt run and test on staging
4. dbt run and test on marts
5. dbt snapshot
6. Elementary alerts
7. Slack and email notification with run status, duration, and link to results

---

## Orchestration Strategy

For production, this pipeline would be orchestrated with Airflow or Dagster:

```
Daily DAG:
  1. Source freshness check     -> dbt source freshness
  2. Run staging models         -> dbt run --select staging
  3. Run mart models            -> dbt run --select marts
  4. Run snapshot               -> dbt snapshot
  5. Run all tests              -> dbt test
  6. Send Elementary alerts     -> edr monitor
```

Scheduling rationale:
- **Staging and Marts**: daily, following the upload cadence of photo studios
- **Snapshot**: daily to capture order status changes for the audit trail
- **Tests**: after every run so bad data is caught before analysts see it

For GotPhoto specifically, the pipeline would ideally trigger on new uploads from studios rather than a fixed schedule. This would be event-driven: studio uploads files to S3, Snowpipe picks it up, dbt runs automatically.

---

## Production Readiness Notes

### Data Contracts and Schema Evolution

Source definitions in `src_tpch.yml` act as contracts between the pipeline and the upstream data. If a source column is renamed or dropped, dbt will fail at compile time before any data is processed.

For schema evolution in production:
- Adding a new column to a source: update `src_tpch.yml` and the relevant staging model. Marts are unaffected unless they need that column.
- Removing a source column: the contract catches it immediately. The team is alerted before downstream models break.
- Changing a column type: caught by value and range tests at the staging layer.

### Observability and Reliability

Elementary monitors all dbt test results over time. It can detect trends like a slowly increasing number of null values, which a one-time test would miss. Alerts go to Slack and email so issues are caught quickly.

### AI-Agent Readiness

`mart_customers_rfm` is structured for direct consumption by AI agents and CRM automation tools. It has one row per customer, pre-computed segments and scores, and no joins required. Every column has a description and grain documented so an agent can query it without additional human context.

### Scalable Ingestion

The staging layer is the only layer that touches raw source data. Swapping TPC-H for real GotPhoto data only requires updating `src_tpch.yml` source pointers. All downstream models stay the same.

For production GotPhoto, ingestion patterns would vary by source:
- **APIs** (e.g. studio booking systems): pull via Airbyte or custom connectors, land in raw schema, picked up by staging
- **Files** (e.g. CSV uploads from studios): land in S3, Snowpipe auto-ingest, raw tables, staging
- **Databases** (e.g. transactional Postgres): CDC via Debezium or Fivetran, raw schema, staging
- **Event streams** (e.g. order events, photo uploads): Kafka, Snowpipe Streaming, append-only raw tables, incremental staging models

The staging layer abstracts all source complexity. Marts never know or care where the data came from.

### Compliance and Access Control

In a production GotPhoto environment:
- Snowflake row-level security and column masking policies would restrict PII (customer names, emails) to authorized roles only
- dbt schema separation (staging and marts in separate schemas) allows fine-grained GRANT permissions. Analysts get read access to marts only, never raw staging.
- Data retention policies enforced via Snowflake Time Travel and fail-safe settings per table
- SCD Type 2 snapshots provide a full audit trail of data changes for financial and order data

### Migration Continuity

SCD Type 2 snapshots preserve historical order state even when source data changes. During a platform migration, marts keep serving dashboards without interruption because the transformation logic is decoupled from the source system.

---

## Project Structure

```
gotphoto/
├── dbt_project.yml
├── packages.yml
├── elementary_config.yml
├── macros/
│   └── safe_divide.sql
├── models/
│   ├── staging/tpch/
│   │   ├── src_tpch.yml
│   │   ├── stg_tpch.yml
│   │   └── stg_tpch__*.sql (7 files)
│   ├── intermediate/
│   │   ├── int_orders__enriched.sql
│   │   └── int_lineitems__enriched.sql
│   └── marts/
│       ├── customers/
│       │   ├── mart_customers.sql
│       │   ├── mart_customers_rfm.py
│       │   └── *.yml
│       ├── orders/
│       │   ├── mart_orders.sql
│       │   └── mart_orders.yml
│       └── finance/
│           ├── mart_revenue_by_month.sql
│           └── mart_revenue_by_month.yml
└── snapshots/
    └── orders_snapshot.sql
```
