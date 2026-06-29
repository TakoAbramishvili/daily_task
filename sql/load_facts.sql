INSERT INTO fact_sales (
    row_hash, customer_id, product_key, store_key,
    transaction_date, sales_date, payment_method,
    quantity, price, discount_applied_pct, total_amount, batch_id
)
SELECT
    s.row_hash,
    s.customer_id,
    dp.product_key,
    ds.store_key,
    s.transaction_date,
    DATE(s.transaction_date),
    s.payment_method,
    s.quantity,
    s.price,
    s.discount_applied_pct,
    s.total_amount,
    s.batch_id
FROM stg_sales s
JOIN dim_store ds ON ds.store_location = s.store_location
JOIN dim_product dp ON dp.source_product_code = s.source_product_id || '-' || s.product_category
WHERE s.loaded_at > :last_run
ON CONFLICT (row_hash) DO NOTHING;
