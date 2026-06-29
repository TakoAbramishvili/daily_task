import os
import kaggle

DATA_DIR = "/opt/airflow/data"
DATASET = "fahadrehman07/retail-transaction-dataset"
CSV_FILE = os.path.join(DATA_DIR, "Retail_Transaction_Dataset.csv")


def download_data():
    if os.path.exists(CSV_FILE):
        print("Data already downloaded, skipping")
        return

    os.makedirs(DATA_DIR, exist_ok=True)
    kaggle.api.authenticate()
    kaggle.api.dataset_download_files(DATASET, path=DATA_DIR, unzip=True)
    print(f"Downloaded dataset to {DATA_DIR}")