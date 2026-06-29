INSERT INTO agg_sales_daily_store_product (
    sales_date, store_key, product_key,
    total_revenue, total_quantity, total_transactions, unique_customers, weighted_discount_pct
)
SELECT
    sales_date,
    store_key,
    product_key,
    SUM(total_amount),
    SUM(quantity),
    COUNT(*),
    COUNT(DISTINCT customer_id),
    CASE
        WHEN SUM(total_amount) > 0
        THEN ROUND(SUM(discount_applied_pct * total_amount) / SUM(total_amount), 4)
        ELSE 0
    END
FROM fact_sales
WHERE loaded_at > :last_run
GROUP BY sales_date, store_key, product_key
ON CONFLICT (sales_date, store_key, product_key) DO UPDATE SET
    total_revenue = EXCLUDED.total_revenue,
    total_quantity = EXCLUDED.total_quantity,
    total_transactions = EXCLUDED.total_transactions,
    unique_customers = EXCLUDED.unique_customers,
    weighted_discount_pct = EXCLUDED.weighted_discount_pct,
    calculated_at = CURRENT_TIMESTAMP;
