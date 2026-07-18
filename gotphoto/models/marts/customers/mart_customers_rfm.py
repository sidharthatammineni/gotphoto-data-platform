import snowflake.snowpark.functions as F
from snowflake.snowpark.functions import col
from snowflake.snowpark import Window


def model(dbt, session):
    dbt.config(
        materialized="table",
        packages=["snowflake-snowpark-python"],
    )

    df = dbt.ref("mart_customers")

    # Compute RFM components
    # Recency: days since last order (lower = better, so invert rank)
    # Frequency: total number of orders
    # Monetary: lifetime revenue
    df = df.with_column(
        "days_since_last_order",
        F.datediff("day", col("LAST_ORDER_DATE"), F.current_date()),
    )

    # Score each dimension into quintiles 1-5 using percent_rank
    window_recency   = F.percent_rank().over(Window.order_by(col("DAYS_SINCE_LAST_ORDER").desc()))
    window_frequency = F.percent_rank().over(Window.order_by(col("TOTAL_ORDERS")))
    window_monetary  = F.percent_rank().over(Window.order_by(col("LIFETIME_REVENUE")))

    df = (
        df
        .with_column("r_pct", window_recency)
        .with_column("f_pct", window_frequency)
        .with_column("m_pct", window_monetary)
    )

    def quintile(pct_col):
        return (
            F.when(pct_col <= 0.20, F.lit(1))
            .when(pct_col <= 0.40, F.lit(2))
            .when(pct_col <= 0.60, F.lit(3))
            .when(pct_col <= 0.80, F.lit(4))
            .otherwise(F.lit(5))
        )

    df = (
        df
        .with_column("r_score", quintile(col("R_PCT")))
        .with_column("f_score", quintile(col("F_PCT")))
        .with_column("m_score", quintile(col("M_PCT")))
    )

    df = df.with_column(
        "rfm_score",
        col("R_SCORE") + col("F_SCORE") + col("M_SCORE"),
    )

    df = df.with_column(
        "rfm_segment",
        F.when(col("RFM_SCORE") >= 13, F.lit("Champions"))
        .when(col("RFM_SCORE") >= 10, F.lit("Loyal Customers"))
        .when(col("RFM_SCORE") >= 7,  F.lit("Potential Loyalists"))
        .when(col("RFM_SCORE") >= 5,  F.lit("At Risk"))
        .otherwise(F.lit("Lost")),
    )

    return df.select(
        col("CUSTOMER_ID"),
        col("CUSTOMER_NAME"),
        col("MARKET_SEGMENT"),
        col("NATION_NAME"),
        col("REGION_NAME"),
        col("CUSTOMER_TIER"),
        col("TOTAL_ORDERS"),
        col("LIFETIME_REVENUE"),
        col("LAST_ORDER_DATE"),
        col("DAYS_SINCE_LAST_ORDER"),
        col("R_SCORE").alias("recency_score"),
        col("F_SCORE").alias("frequency_score"),
        col("M_SCORE").alias("monetary_score"),
        col("RFM_SCORE").alias("rfm_score"),
        col("RFM_SEGMENT").alias("rfm_segment"),
    )
