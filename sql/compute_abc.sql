WITH product_totals AS (
    SELECT
        product_key,
        SUM(total_revenue) AS total_amount,
        SUM(total_transactions) AS total_quantity
    FROM agg_sales_daily_store_product
    GROUP BY product_key
),
abc_amount AS (
    SELECT
        product_key,
        ROUND(
            SUM(total_amount) OVER (ORDER BY total_amount DESC, product_key ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) /
            NULLIF(SUM(total_amount) OVER (), 0) * 100, 2
        ) AS cumulative_pct
    FROM product_totals
),
abc_quantity AS (
    SELECT
        product_key,
        ROUND(
            SUM(total_quantity) OVER (ORDER BY total_quantity DESC, product_key ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) /
            NULLIF(SUM(total_quantity) OVER (), 0) * 100, 2
        ) AS cumulative_pct
    FROM product_totals
),
classified AS (
    SELECT
        aa.product_key,
        CASE
            WHEN aa.cumulative_pct <= 50 THEN 'A'
            WHEN aa.cumulative_pct <= 70 THEN 'B'
            ELSE 'C'
        END AS abc_amount,
        CASE
            WHEN aq.cumulative_pct <= 50 THEN 'A'
            WHEN aq.cumulative_pct <= 70 THEN 'B'
            ELSE 'C'
        END AS abc_quantity
    FROM abc_amount aa
    JOIN abc_quantity aq ON aq.product_key = aa.product_key
)
UPDATE dim_product dp
SET
    abc_amount = c.abc_amount,
    abc_quantity = c.abc_quantity,
    updated_at = CURRENT_TIMESTAMP
FROM classified c
WHERE dp.product_key = c.product_key
  AND (
      dp.abc_amount IS DISTINCT FROM c.abc_amount
      OR dp.abc_quantity IS DISTINCT FROM c.abc_quantity
  );
