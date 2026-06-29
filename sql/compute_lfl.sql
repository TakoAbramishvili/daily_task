WITH max_year AS (
    SELECT MAX(EXTRACT(YEAR FROM sales_date)::int) AS current_year
    FROM fact_sales
),

store_monthly_days AS (
    SELECT
        EXTRACT(YEAR FROM sales_date)::int AS year,
        EXTRACT(MONTH FROM sales_date)::int AS month,
        fs.store_key,
        COUNT(DISTINCT sales_date) AS sales_days
    FROM fact_sales fs
    GROUP BY
        EXTRACT(YEAR FROM sales_date)::int,
        EXTRACT(MONTH FROM sales_date)::int,
        fs.store_key
),

lfl_calc AS (
    SELECT
        cur.year,
        cur.month,
        cur.store_key,
        cur.sales_days AS current_store_days,
        COALESCE(prev_store.sales_days, 0) AS previous_store_days,
        CASE
            WHEN cur.sales_days > 0
             AND prev_store.sales_days > 0
             AND cur.sales_days = prev_store.sales_days
            THEN true
            ELSE false
        END AS is_lfl
    FROM store_monthly_days cur
    JOIN max_year my ON cur.year = my.current_year
    LEFT JOIN store_monthly_days prev_store
        ON prev_store.store_key = cur.store_key
       AND prev_store.month = cur.month
       AND prev_store.year = cur.year - 1
)

INSERT INTO dim_lfl_store (
    year, month, store_key, is_lfl,
    current_store_days, previous_store_days,
    calculated_at
)
SELECT
    year, month, store_key, is_lfl,
    current_store_days, previous_store_days,
    CURRENT_TIMESTAMP
FROM lfl_calc
ON CONFLICT (year, month, store_key)
DO UPDATE SET
    is_lfl = EXCLUDED.is_lfl,
    current_store_days = EXCLUDED.current_store_days,
    previous_store_days = EXCLUDED.previous_store_days,
    calculated_at = CURRENT_TIMESTAMP;
