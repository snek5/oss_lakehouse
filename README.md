# Teratai Lakehouse Local Stack

This repository provides a local lakehouse environment for experimenting with Apache Spark, Apache Iceberg, MinIO, PostgreSQL, and dbt. The stack is designed to run with Docker Compose and is suitable for local analytics pipelines, SQL testing, and transformation workflows.

## What is included

The core platform consists of:

- PostgreSQL as the Iceberg metadata catalog
- MinIO as an S3-compatible warehouse for table data
- An Iceberg REST catalog service for Spark metadata access
- Spark master and worker nodes for distributed execution
- A Spark Thrift Server for SQL and JDBC-style access
- A dbt project under the cosmos folder with staging, intermediate, mart, and analytics models
- An example Airflow/Cosmos DAG definition for orchestration

## Architecture

```mermaid
flowchart LR
    A[Raw / Source Data] --> B[Airflow + Cosmos]
    B --> C[dbt Project]
    C --> D[Spark Thrift Server]
    D --> E[Iceberg REST Catalog]
    E --> F[PostgreSQL Metadata Catalog]
    D --> G[MinIO / S3 Warehouse]
    G --> H[Analytics Consumers]
```
```mermaid
architecture-beta
    group server_group(server)[Python Container]
    group spark_group(server)[Spark Cluster]
    
    junction junctionRight

    service storage(disk)[S3 Storage]
    service laut(cloud)[Analytics]
    service db(database)[Source Database]
    service db2(database)[Metadata Catalog]
    service orchestrator(server)[Airflow] in server_group
    service transformation(server)[dbt] in server_group

    service engine(server)[Master] in spark_group
    service worker(server)[Worker] in spark_group
    service thrift(server)[Thrift] in spark_group

    db:R --> L:orchestrator
    orchestrator:B --> T:transformation
    transformation:R --> L:thrift
    thrift:R --> L:junctionRight
    thrift:T --> B:engine
    engine:T --> B:worker
    junctionRight:B --> T:storage
    junctionRight:T --> B:db2
    laut:L --> R:db2
```
## Services

- `postgres`
  - PostgreSQL 15 with `POSTGRES_DB=iceberg_catalog`
  - stores Iceberg catalog metadata
- `minio`
  - S3-compatible object store for Iceberg table files
  - exposes the MinIO API on port `9000` and the console on `9001`
- `minio-init`
  - creates the `warehouse` (Iceberg data) and `landing` (raw CSV) buckets
  - mirrors `./data/landing` into the `landing` bucket on every start
- `iceberg-rest`
  - Iceberg REST catalog service
  - connects to PostgreSQL at `jdbc:postgresql://postgres:5432/iceberg_catalog`
  - uses MinIO as the storage backend
- `spark-master`
  - Spark master node that schedules work
- `spark-worker-1` and `spark-worker-2`
  - Spark workers that execute tasks
- `spark-thrift`
  - Spark Thrift Server for SQL clients
  - depends on `spark-master` and `iceberg-rest`

## Repository layout

- `docker-compose.yml` defines the local infrastructure stack
- `data/landing/` is where raw CSVs go, one folder per source table (git-ignored)
- `cosmos/dbt/teratai/dbt_project.yml` defines the dbt project
- `cosmos/dbt/teratai/profiles.yml` configures the Spark Thrift connection
- `cosmos/dbt/teratai/models/` contains staging, intermediate, mart, and analytics dbt models
- `cosmos/dbt/teratai/macros/stage_raw_sources.sql` loads the landing CSVs into `raw.*` Iceberg tables
- `cosmos/dags/teratai_dag.py` contains an example Airflow Cosmos DAG
- `spark/` contains the Spark image build context and entrypoint scripts

## How it works

1. PostgreSQL starts and initializes the `iceberg_catalog` database.
2. MinIO starts and exposes an S3-compatible object store.
3. The Iceberg REST catalog starts after PostgreSQL and MinIO are healthy.
4. Spark master and workers register with the cluster.
5. Spark Thrift starts and connects to the Spark master and the Iceberg REST catalog.
6. The dbt project targets Spark Thrift and uses the Iceberg REST catalog together with MinIO storage.

## Local usage

1. Put your CSVs in `data/landing/<table>/` (customers, accounts, branches,
   cards, loans, merchants, transactions).

2. Start the stack (this also builds the `spark-base` image):

   ```bash
   docker compose up --build -d
   docker compose ps
   ```

3. Run dbt from the cosmos container. The first run creates the `raw.*`
   Iceberg tables from the CSVs, then builds every model:

   ```bash
   docker compose exec cosmos bash -c "cd /app/dbt/teratai && dbt deps && dbt run"
   ```

   Or trigger `teratai_dag` in Airflow, which runs `stage_raw_sources` first
   and then one task per model.

Reload raw tables after changing the CSVs:

```bash
docker compose exec cosmos bash -c "cd /app/dbt/teratai && dbt run-operation stage_raw_sources --args '{refresh: true}'"
```

Stop the stack:

```bash
docker compose down
```

## Optional testing container

If you want to test dbt or Cosmos from a separate container, you can attach a temporary container to the same Docker network:

```bash
docker run -d \
  --name cosmos-test \
  --restart unless-stopped \
  --network lakehouse-net \
  -v "$PWD/cosmos:/workspace" \
  -w /workspace \
  -p 123:8080 \
  python:3.12 \
  sleep infinity
```

After that, copy or mount the relevant files such as `profiles.yml` and `models/sources.yml` into the container as needed for local testing.

## Important notes

- `spark-thrift` waits for `iceberg-rest` to answer on `/v1/config` before starting.
- Iceberg, MinIO and the default catalog (`lakehouse`) are configured in `spark/base/conf/spark-defaults.conf`, which is baked into the `spark-base` image. Rebuild after changing it: `docker compose build spark-master`.
- A missing landing folder makes the raw load fail with `PATH_NOT_FOUND: s3a://landing/<table>`. Add the CSVs, then `docker compose up minio-init`.
- The Spark entrypoint scripts should be executable:
  - `chmod +x spark/spark-thrift/scripts/entrypoint.sh`
- Do not use MySQL-style SQL in PostgreSQL initialization scripts. For example, `CREATE DATABASE IF NOT EXISTS` is invalid in PostgreSQL.

## Ports

- `5432` → PostgreSQL
- `9000` → MinIO API
- `9001` → MinIO console
- `8181` → Iceberg REST catalog
- `7077` → Spark Master
- `8080` → Spark Master UI
- `8081` → Spark Worker 1 UI
- `8082` → Spark Worker 2 UI
- `10000` → Spark Thrift Server
- `4040` → Spark application UI
