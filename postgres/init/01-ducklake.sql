-- The Postgres container hosts two databases:
--   airflow   -> Airflow metadata (created via POSTGRES_DB)
--   ducklake  -> DuckLake catalog (table/snapshot metadata; the Parquet data lives on CephFS)
CREATE DATABASE ducklake;
