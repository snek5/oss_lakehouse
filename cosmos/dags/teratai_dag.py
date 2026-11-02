"""
Teratai pipeline: land raw CSVs as Iceberg tables, then run the dbt project.

1. stage_raw_sources  - `dbt run-operation stage_raw_sources` creates raw.<table>
                        Iceberg tables from s3a://landing/<table>/ (skips tables
                        that already exist).
2. transform          - one Airflow task per dbt model, rendered by Cosmos.
                        The on-run-start hook is disabled here (skip_raw_staging)
                        so parallel model tasks don't race to create raw tables.

To reload raw tables from CSV, run inside the cosmos container:
    dbt run-operation stage_raw_sources --args '{refresh: true}' 
"""

import os
import pathlib
from datetime import datetime

from airflow import DAG
from cosmos import DbtTaskGroup, ProfileConfig, ProjectConfig
from cosmos.operators.local import DbtRunOperationLocalOperator

DBT_PROJECT_PATH = (
    pathlib.Path(os.getenv("AIRFLOW_HOME", pathlib.Path(__file__).parent.parent))
    / "dbt/teratai"
)

profile_config = ProfileConfig(
    profile_name="lakehouse",
    target_name="dev",
    profiles_yml_filepath=DBT_PROJECT_PATH / "profiles.yml",
)

with DAG(
    dag_id="teratai_dag",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=["teratai", "dbt", "iceberg"],
) as dag:

    stage_raw = DbtRunOperationLocalOperator(
        task_id="stage_raw_sources",
        macro_name="stage_raw_sources",
        project_dir=DBT_PROJECT_PATH,
        profile_config=profile_config,
    )

    transform = DbtTaskGroup(
        group_id="transform",
        project_config=ProjectConfig(
            dbt_project_path=DBT_PROJECT_PATH,
            dbt_vars={"skip_raw_staging": True},
        ),
        profile_config=profile_config,
    )

    stage_raw >> transform
