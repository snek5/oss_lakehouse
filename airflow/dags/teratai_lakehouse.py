"""Teratai lakehouse pipeline: CephFS landing CSVs -> DuckLake (raw -> staging -> marts -> analytics).

Each dbt model/test becomes its own Airflow task via astronomer-cosmos. dbt v2 (dbt-oss) runs
DuckDB in-process and writes every model to the DuckLake catalog `lake`
(metadata in Postgres, Parquet on CephFS).
"""

import os
from datetime import datetime
from pathlib import Path

from airflow.exceptions import AirflowFailException
from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import dag, task
from cosmos import DbtTaskGroup, ExecutionConfig, ProfileConfig, ProjectConfig, RenderConfig
from cosmos.constants import InvocationMode, LoadMode, TestBehavior

AIRFLOW_HOME = Path(os.getenv("AIRFLOW_HOME", "/opt/airflow"))
DBT_PROJECT_DIR = AIRFLOW_HOME / "dbt" / "teratai"
DBT_EXECUTABLE = "/opt/dbt/bin/dbt"  # dbt v2, installed in its own venv (see airflow/Dockerfile)
LANDING_PATH = Path(os.getenv("LANDING_PATH", "/lakehouse/landing"))

SOURCE_TABLES = ["customers", "accounts", "branches", "cards", "loans", "merchants", "transactions"]
LAKE_SCHEMAS = ["raw", "staging", "intermediate", "marts", "analytics"]

profile_config = ProfileConfig(
    profile_name="teratai",
    target_name="dev",
    profiles_yml_filepath=DBT_PROJECT_DIR / "profiles.yml",
)

execution_config = ExecutionConfig(
    dbt_executable_path=DBT_EXECUTABLE,
    # dbt v2 is a Rust binary, not the dbt-core Python package -> always shell out to it.
    invocation_mode=InvocationMode.SUBPROCESS,
)

render_config = RenderConfig(
    load_method=LoadMode.DBT_LS,
    dbt_executable_path=DBT_EXECUTABLE,
    test_behavior=TestBehavior.AFTER_EACH,
)


@dag(
    dag_id="teratai_lakehouse",
    schedule=None,
    start_date=datetime(2026, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=["teratai", "dbt", "ducklake"],
)
def teratai_lakehouse():
    @task
    def check_landing() -> None:
        """Fail early with a clear message if a source table has no CSVs on CephFS."""
        missing = [t for t in SOURCE_TABLES if not any((LANDING_PATH / t).glob("*.csv"))]
        if missing:
            raise AirflowFailException(
                f"No CSVs in {LANDING_PATH} for: {', '.join(missing)}. "
                "Trigger the `teratai_sample_data` DAG or copy files into <landing>/<table>/*.csv."
            )

    # Attach the DuckLake catalog once, serially, before dbt fans out into parallel tasks:
    # creates the catalog tables in Postgres on first run and the schemas the models write to.
    prepare_lake = BashOperator(
        task_id="prepare_lake",
        bash_command="lake -c \"" + " ".join(f"create schema if not exists {s};" for s in LAKE_SCHEMAS) + "\"",
    )

    transform = DbtTaskGroup(
        group_id="dbt",
        project_config=ProjectConfig(DBT_PROJECT_DIR),
        profile_config=profile_config,
        execution_config=execution_config,
        render_config=render_config,
        operator_args={"install_deps": False},
    )

    check_landing() >> prepare_lake >> transform


teratai_lakehouse()
