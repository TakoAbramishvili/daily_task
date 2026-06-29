INSERT INTO dim_product (source_product_id, source_product_code, product_category, product_name)
SELECT
    source_product_id,
    source_product_id || '-' || product_category,
    product_category,
    product_category || ' ' || source_product_id
FROM (
    SELECT DISTINCT source_product_id, product_category
    FROM stg_sales
    WHERE source_product_id IS NOT NULL
) sub
ON CONFLICT (source_product_code) DO UPDATE
SET updated_at = CURRENT_TIMESTAMP;
