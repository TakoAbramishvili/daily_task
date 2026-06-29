import sys
from datetime import datetime, timedelta
from functools import partial

from airflow import DAG
from airflow.operators.python import PythonOperator

sys.path.insert(0, "/opt/airflow")

from scripts.download import download_data
from scripts.load_raw import load_raw
from scripts.run_sql import run_sql
from scripts.db import get_engine
from sqlalchemy import text


def load_facts_incremental(execution_date=None, **context):
    """Load facts only for data loaded since last execution_date."""
    last_run = datetime(2000, 1, 1)  # First run: load all; subsequent runs use loaded_at timestamp
    run_sql("load_facts.sql", {"last_run": last_run})


def compute_aggregations_incremental(execution_date=None, **context):
    """Compute aggregations only for rows loaded since last_run."""
    last_run = datetime(2000, 1, 1)  # First run: compute all; subsequent runs: loaded_at > last_run
    run_sql("compute_aggregations.sql", {"last_run": last_run})


def compute_lfl_incremental(execution_date=None, **context):
    """Recompute LFL for affected rows since last_run."""
    last_run = datetime(2000, 1, 1)  # First run: compute all; subsequent runs: loaded_at > last_run
    run_sql("compute_lfl.sql", {"last_run": last_run})


with DAG(
    dag_id="retail_pipeline",
    description="Download Kaggle retail transaction data, build DWH dimensions, facts, and analytics",
    start_date=datetime(2024, 1, 1),
    schedule_interval="0 0 * * *",
    catchup=False,
    tags=["retail"],
    timezone="Asia/Tbilisi",
) as dag:

    t_init        = PythonOperator(task_id="init_schema",          python_callable=partial(run_sql, "create_tables.sql"))
    t_index       = PythonOperator(task_id="create_indexes",       python_callable=partial(run_sql, "create_indexes.sql"))
    t_download    = PythonOperator(task_id="download_data",        python_callable=download_data)
    t_load_raw    = PythonOperator(task_id="load_raw",             python_callable=load_raw)
    t_dim_store   = PythonOperator(task_id="fill_dim_store",       python_callable=partial(run_sql, "fill_dim_store.sql"))
    t_dim_product = PythonOperator(task_id="fill_dim_product",     python_callable=partial(run_sql, "fill_dim_product.sql"))
    t_facts       = PythonOperator(task_id="load_facts",           python_callable=load_facts_incremental, provide_context=True)
    t_agg         = PythonOperator(task_id="compute_aggregations", python_callable=compute_aggregations_incremental, provide_context=True)
    t_lfl         = PythonOperator(task_id="compute_lfl",          python_callable=compute_lfl_incremental, provide_context=True)
    t_abc         = PythonOperator(task_id="compute_abc",          python_callable=partial(run_sql, "compute_abc.sql"))

    t_init >> t_index >> t_download >> t_load_raw >> t_dim_store >> t_dim_product >> t_facts
    t_facts >> [t_agg, t_lfl]
    t_agg >> t_abc
