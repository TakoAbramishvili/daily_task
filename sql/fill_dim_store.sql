INSERT INTO dim_store (store_name, store_location)
SELECT
    'Store ' || LPAD(ROW_NUMBER() OVER (ORDER BY store_location)::TEXT, 3, '0'),
    store_location
FROM (
    SELECT DISTINCT store_location
    FROM stg_sales
    WHERE store_location IS NOT NULL
) sub
ON CONFLICT (store_location) DO UPDATE
SET updated_at = CURRENT_TIMESTAMP;
