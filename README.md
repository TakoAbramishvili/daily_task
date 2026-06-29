# Retail Transaction Data Pipeline

A production-ready data engineering pipeline that downloads retail transaction data from [Kaggle](https://www.kaggle.com/datasets/fahadrehman07/retail-transaction-dataset), transforms it into a dimensional warehouse, and orchestrates all jobs with Apache Airflow — everything runs inside Docker.

## Quick Start

### 1. Get Kaggle API Credentials

1. Go to [kaggle.com/settings/account](https://www.kaggle.com/settings/account)
2. Scroll to **API** section
3. Click **Create New Token**
4. A `kaggle.json` file will download (save it somewhere safe)
5. Extract your credentials:
   - **KAGGLE_USERNAME**: your Kaggle username
   - **KAGGLE_KEY**: your API key from the downloaded file

### 2. Export Credentials to Terminal

```bash
export KAGGLE_USERNAME=your_kaggle_username
export KAGGLE_KEY=your_kaggle_api_key
```

**Replace** `your_kaggle_username` and `your_kaggle_api_key` with actual values.

### 3. Build and Start

Navigate to project directory, then:

```bash
docker compose build
```

```bash
docker compose up -d
```

Wait 30 seconds, then trigger DAG:

**Option A: Command line**

```bash
docker compose exec airflow-scheduler airflow dags trigger retail_pipeline
```

**Option B: Web UI**
- Go to http://localhost:8080
- Login: `admin` / `admin`
- Click **retail_pipeline** DAG
- Click **Trigger DAG** button

### 4. Monitor Progress

```bash
docker compose logs -f airflow-scheduler
```

### 5. View Data

**Airflow UI:** http://localhost:8080 (admin / admin)

**pgAdmin:** http://localhost:5050 (admin@admin.com / admin)

#### How to Use pgAdmin

1. Open http://localhost:5050
2. Login: `admin@admin.com` / `admin`
3. Click **Add New Server**
   - **General tab:**
     - Name: `postgres`
   - **Connection tab:**
     - Host: `postgres`, Port: `5432`
     - Username: `postgresadmin`, Password: `postgresadmin`
   - **Maintenance database:** `sales` ⚠️ (important!)
4. Click **Save**
5. Expand **Servers > postgres > Databases**

**⚠️ Important:** 2 databases exist:
- **airflow** — Airflow internal metadata (ignore)
- **sales** — Our retail data warehouse (click here!) ✅

Set **Maintenance database** to `sales` when connecting server.

---

## Database Schema

All tables live in the `sales` PostgreSQL database.

### 1. **stg_sales** — Staging (Raw Data)

Raw data from Kaggle before transformation. One row per transaction.

| Column | Type | Description |
|--------|------|-------------|
| customer_id | BIGINT | Customer identifier |
| source_product_id | TEXT | Product letter (A, B, C, D) |
| quantity | INTEGER | Units sold |
| price | NUMERIC(12,4) | Unit price |
| transaction_date | TIMESTAMP | Full transaction datetime |
| payment_method | TEXT | Payment method (Cash, PayPal, Debit Card) |
| store_location | TEXT | Store address (city, state) |
| product_category | TEXT | Product category (Books, Electronics, etc) |
| discount_applied_pct | NUMERIC(8,4) | Discount percentage |
| total_amount | NUMERIC(14,4) | Final transaction amount |
| batch_id | TEXT | Airflow run identifier |
| loaded_at | TIMESTAMP | When row was loaded |
| source_file_name | TEXT | Source file name |
| row_hash | TEXT | MD5 hash for deduplication |

**Idempotency:** `ON CONFLICT (row_hash) DO NOTHING` — prevents duplicates on rerun.

---

### 2. **dim_store** — Store Dimension

One row per unique store location.

| Column | Type | Description |
|--------|------|-------------|
| store_key | BIGSERIAL | Surrogate key (warehouse ID) |
| store_name | TEXT | Generated name (Store 001, Store 002, etc) |
| store_location | TEXT | Full address from source data |
| created_at | TIMESTAMP | When record was created |
| updated_at | TIMESTAMP | Last update timestamp |

**Key:** `UNIQUE (store_location)` — one store per address.

**Example:**
```
store_key: 1
store_name: Store 001
store_location: 176 Andrew Cliffs, Baileyfort, HI 93354
```

---

### 3. **dim_product** — Product Dimension

One row per unique product (source_product_id + product_category).

| Column | Type | Description |
|--------|------|-------------|
| product_key | BIGSERIAL | Surrogate key (warehouse ID) |
| source_product_id | TEXT | Original product ID (A, B, C, D) |
| source_product_code | TEXT | Unique business key (A-Books, B-Electronics) |
| product_category | TEXT | Product category |
| product_name | TEXT | Generated name (Books A, Electronics B) |
| abc_quantity | CHAR(1) | ABC class by quantity sold (A/B/C) |
| abc_amount | CHAR(1) | ABC class by revenue (A/B/C) |
| created_at | TIMESTAMP | When record was created |
| updated_at | TIMESTAMP | Last update timestamp |

**Key:** `UNIQUE (source_product_code)` — one product per code.

---

### 4. **fact_sales** — Sales Fact Table

One row per transaction. Contains measures and foreign keys to dimensions.

| Column | Type | Description |
|--------|------|-------------|
| sales_key | BIGSERIAL | Surrogate key |
| row_hash | TEXT | MD5 hash of transaction (unique) |
| customer_id | BIGINT | Customer ID from source |
| product_key | BIGINT | FK to dim_product |
| store_key | BIGINT | FK to dim_store |
| transaction_date | TIMESTAMP | Full transaction datetime |
| sales_date | DATE | Date part (for aggregation) |
| payment_method | TEXT | Payment method |
| quantity | INTEGER | Units sold |
| price | NUMERIC(12,4) | Unit price |
| discount_applied_pct | NUMERIC(8,4) | Discount % |
| total_amount | NUMERIC(14,4) | Total revenue |
| batch_id | TEXT | Airflow run ID |
| loaded_at | TIMESTAMP | When loaded |

**Idempotency:** `UNIQUE (row_hash)` — prevents duplicate transactions.

**Measures:** quantity, price, discount_applied_pct, total_amount

---

### 5. **dim_lfl_store** — Like-For-Like Analysis

Monthly Like-For-Like status per store. Compares current year vs previous year selling days.

| Column | Type | Description |
|--------|------|-------------|
| year | INTEGER | Year of analysis |
| month | INTEGER | Month (1-12) |
| store_key | BIGINT | FK to dim_store |
| is_lfl | BOOLEAN | Store is LFL this month (by store location) |
| is_lfl_by_state | BOOLEAN | State is LFL this month (by state) |
| current_store_days | INTEGER | Selling days in current year/month |
| previous_store_days | INTEGER | Selling days in previous year/same month |
| current_state_days | INTEGER | State selling days in current year/month |
| previous_state_days | INTEGER | State selling days in previous year/same month |
| calculated_at | TIMESTAMP | When LFL was calculated |

**LFL Logic:**
- `is_lfl = TRUE` only if: `current_store_days > 0 AND previous_store_days > 0 AND current_store_days = previous_store_days`
- `is_lfl = FALSE` otherwise (including when 0 = 0)

**⚠️ Important Note — `is_lfl` is Always FALSE:**

The source dataset contains 100,000 rows with 100,000 unique `StoreLocation` values. This means:
- Every store location is unique (appears only once in the entire dataset)
- A store cannot appear in both 2023 and 2024 (each location is distinct)
- Year-over-year comparison is impossible at store level
- **Expected result: `is_lfl` is FALSE for ALL rows**

This is not a bug — it's a data characteristic. The dataset does not have repeating store locations, so LFL status cannot be meaningfully calculated by store.

---

### 6. **agg_sales_daily_store_product** — Aggregation Table

Daily metrics grouped by date, store, and product.

| Column | Type | Description |
|--------|------|-------------|
| sales_date | DATE | Sales date |
| store_key | BIGINT | FK to dim_store |
| product_key | BIGINT | FK to dim_product |
| total_revenue | NUMERIC(14,4) | SUM(total_amount) |
| total_quantity | INTEGER | SUM(quantity) |
| total_transactions | INTEGER | COUNT(*) |
| unique_customers | INTEGER | COUNT(DISTINCT customer_id) |
| weighted_discount_pct | NUMERIC(8,4) | Revenue-weighted discount % |
| calculated_at | TIMESTAMP | When aggregation was calculated |

**Weighted Discount Formula:**
```
SUM(discount_pct * total_amount) / SUM(total_amount)
```

**Key:** `PRIMARY KEY (sales_date, store_key, product_key)` — one row per day/store/product.

**⚠️ Note — Aggregation Close to Transaction Level:**

The aggregation table is created at daily store-product level as required. However, in the provided dataset, `StoreLocation` is unique for almost every transaction. Since `store_key` is generated from `StoreLocation`, most `store_key` values appear only once. As a result, the aggregation table is close to transaction-level granularity, with most rows having `total_transactions = 1` and `unique_customers = 1`. This behavior is caused by the source data structure, not by an issue in the aggregation logic.

---

## Airflow DAG

The `retail_pipeline` DAG runs daily at **00:00 UTC**.

**Tasks (in order):**
1. `init_schema` — Create/update tables
2. `download_data` — Download CSV from Kaggle (once)
3. `load_raw` — Load CSV into stg_sales
4. `fill_dim_store` → `fill_dim_product` — Build dimensions
5. `load_facts` — Load fact_sales from staging + dimensions
6. `compute_aggregations` → `compute_lfl` — Aggregations + LFL in parallel
7. `compute_abc` — Calculate ABC analysis

**Idempotency:** Every run is safe to rerun. No duplicates, no data loss.


