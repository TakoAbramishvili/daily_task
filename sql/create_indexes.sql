-- Indexes for performance optimization

-- fact_sales indexes
CREATE INDEX IF NOT EXISTS idx_fact_sales_loaded_at
  ON fact_sales(loaded_at);

CREATE INDEX IF NOT EXISTS idx_fact_sales_sales_date
  ON fact_sales(sales_date);

CREATE INDEX IF NOT EXISTS idx_fact_sales_sales_date_store_product
  ON fact_sales(sales_date, store_key, product_key);

CREATE INDEX IF NOT EXISTS idx_fact_sales_product_key
  ON fact_sales(product_key);

CREATE INDEX IF NOT EXISTS idx_fact_sales_store_key
  ON fact_sales(store_key);

-- stg_sales indexes
CREATE INDEX IF NOT EXISTS idx_stg_sales_loaded_at
  ON stg_sales(loaded_at);

CREATE INDEX IF NOT EXISTS idx_stg_sales_batch_id
  ON stg_sales(batch_id);

-- agg_sales_daily_store_product indexes
CREATE INDEX IF NOT EXISTS idx_agg_sales_product_key
  ON agg_sales_daily_store_product(product_key);

CREATE INDEX IF NOT EXISTS idx_agg_sales_store_key
  ON agg_sales_daily_store_product(store_key);

-- dim_lfl_store indexes
CREATE INDEX IF NOT EXISTS idx_dim_lfl_store_store_key
  ON dim_lfl_store(store_key);
