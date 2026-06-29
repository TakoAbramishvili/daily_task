import csv
import hashlib
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from uuid import uuid4

from sqlalchemy import text

from scripts.db import get_engine

CSV_PATH = Path("/opt/airflow/data/Retail_Transaction_Dataset.csv")
BATCH_SIZE = 5000


def load_raw():
    batch_id = f"batch_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    source_file_name = "Retail_Transaction_Dataset.csv"

    processed = 0
    inserted = 0

    engine = get_engine()
    with engine.begin() as conn:
        with CSV_PATH.open("r", encoding="utf-8", newline="") as f:
            reader = csv.DictReader(f)
            batch = []

            for row in reader:
                # Parse and validate
                transaction_date = datetime.strptime(row["TransactionDate"].strip(), "%m/%d/%Y %H:%M")

                # Create row hash for deduplication
                hash_input = "||".join([
                    row["CustomerID"].strip(),
                    row["ProductID"].strip(),
                    row["Quantity"].strip(),
                    row["Price"].strip(),
                    transaction_date.strftime("%Y-%m-%d %H:%M:%S"),
                    row["PaymentMethod"].strip(),
                    row["StoreLocation"].strip(),
                    row["ProductCategory"].strip(),
                    row["DiscountApplied(%)"].strip(),
                    row["TotalAmount"].strip(),
                ])
                row_hash = hashlib.md5(hash_input.encode()).hexdigest()

                batch.append({
                    "row_hash": row_hash,
                    "customer_id": int(row["CustomerID"].strip()),
                    "source_product_id": row["ProductID"].strip(),
                    "quantity": int(row["Quantity"].strip()),
                    "price": Decimal(row["Price"].strip()),
                    "transaction_date": transaction_date,
                    "payment_method": row["PaymentMethod"].strip(),
                    "store_location": row["StoreLocation"].strip(),
                    "product_category": row["ProductCategory"].strip(),
                    "discount_applied_pct": Decimal(row["DiscountApplied(%)"].strip()),
                    "total_amount": Decimal(row["TotalAmount"].strip()),
                    "batch_id": batch_id,
                    "source_file_name": source_file_name,
                })

                processed += 1

                if len(batch) >= BATCH_SIZE:
                    result = conn.execute(text("""
                        INSERT INTO stg_sales (
                            row_hash, customer_id, source_product_id, quantity, price,
                            transaction_date, payment_method, store_location,
                            product_category, discount_applied_pct, total_amount,
                            batch_id, source_file_name
                        ) VALUES (
                            :row_hash, :customer_id, :source_product_id, :quantity, :price,
                            :transaction_date, :payment_method, :store_location,
                            :product_category, :discount_applied_pct, :total_amount,
                            :batch_id, :source_file_name
                        ) ON CONFLICT (row_hash) DO NOTHING
                    """), batch)
                    inserted += max(result.rowcount or 0, 0)
                    batch = []

            # Insert remaining batch
            if batch:
                result = conn.execute(text("""
                    INSERT INTO stg_sales (
                        row_hash, customer_id, source_product_id, quantity, price,
                        transaction_date, payment_method, store_location,
                        product_category, discount_applied_pct, total_amount,
                        batch_id, source_file_name
                    ) VALUES (
                        :row_hash, :customer_id, :source_product_id, :quantity, :price,
                        :transaction_date, :payment_method, :store_location,
                        :product_category, :discount_applied_pct, :total_amount,
                        :batch_id, :source_file_name
                    ) ON CONFLICT (row_hash) DO NOTHING
                """), batch)
                inserted += max(result.rowcount or 0, 0)

    print(f"Processed {processed} rows, inserted {inserted} new rows (batch_id: {batch_id})")
