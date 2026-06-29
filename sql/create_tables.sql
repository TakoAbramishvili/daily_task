CREATE TABLE IF NOT EXISTS stg_sales (
    customer_id BIGINT,
    source_product_id TEXT,
    quantity INTEGER,
    price NUMERIC(12, 4),
    transaction_date TIMESTAMP,
    payment_method TEXT,
    store_location TEXT,
    product_category TEXT,
    discount_applied_pct NUMERIC(8, 4),
    total_amount NUMERIC(14, 4),
    batch_id TEXT NOT NULL,
    loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_file_name TEXT,
    row_hash TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS dim_store (
    store_key BIGSERIAL PRIMARY KEY,
    store_name TEXT NOT NULL,
    store_location TEXT NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dim_product (
    product_key BIGSERIAL PRIMARY KEY,
    source_product_id TEXT NOT NULL,
    source_product_code TEXT NOT NULL UNIQUE,
    product_category TEXT NOT NULL,
    product_name TEXT NOT NULL,
    abc_quantity CHAR(1),
    abc_amount CHAR(1),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS fact_sales (
    sales_key BIGSERIAL PRIMARY KEY,
    row_hash TEXT NOT NULL UNIQUE,
    customer_id BIGINT NOT NULL,
    product_key BIGINT NOT NULL,
    store_key BIGINT NOT NULL,
    transaction_date TIMESTAMP NOT NULL,
    sales_date DATE NOT NULL,
    payment_method TEXT,
    quantity INTEGER NOT NULL,
    price NUMERIC(12, 4) NOT NULL,
    discount_applied_pct NUMERIC(8, 4),
    total_amount NUMERIC(14, 4) NOT NULL,
    batch_id TEXT NOT NULL,
    loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (store_key) REFERENCES dim_store(store_key)
);

CREATE TABLE IF NOT EXISTS dim_lfl_store (
    year INTEGER NOT NULL,
    month INTEGER NOT NULL,
    store_key BIGINT NOT NULL,
    is_lfl BOOLEAN NOT NULL,
    current_store_days INTEGER,
    previous_store_days INTEGER,
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (year, month, store_key),
    FOREIGN KEY (store_key) REFERENCES dim_store(store_key)
);

CREATE TABLE IF NOT EXISTS agg_sales_daily_store_product (
    sales_date DATE NOT NULL,
    store_key BIGINT NOT NULL,
    product_key BIGINT NOT NULL,
    total_revenue NUMERIC(14, 4) NOT NULL,
    total_quantity INTEGER NOT NULL,
    total_transactions INTEGER NOT NULL,
    unique_customers INTEGER NOT NULL,
    weighted_discount_pct NUMERIC(8, 4),
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (sales_date, store_key, product_key),
    FOREIGN KEY (store_key) REFERENCES dim_store(store_key),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key)
);
