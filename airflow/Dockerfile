ARG AIRFLOW_VERSION=3.3.2
ARG PYTHON_VERSION=3.12
FROM apache/airflow:${AIRFLOW_VERSION}-python${PYTHON_VERSION}

ARG AIRFLOW_VERSION
ARG DBT_VERSION=">=2.0.5,<2.1"
ARG DUCKDB_CLI_VERSION=1.5.4

USER root

# ceph-fuse: mounts CephFS inside the container (no host kernel module needed)
RUN apt-get update \
 && apt-get install -y --no-install-recommends ceph-fuse curl unzip \
 && rm -rf /var/lib/apt/lists/*

# DuckDB CLI, handy for poking at the lake (`lake` wrapper below)
RUN arch="$(dpkg --print-architecture)" \
 && curl -fsSL -o /tmp/duckdb.zip \
      "https://github.com/duckdb/duckdb/releases/download/v${DUCKDB_CLI_VERSION}/duckdb_cli-linux-${arch}.zip" \
 && unzip -o /tmp/duckdb.zip -d /usr/local/bin \
 && rm /tmp/duckdb.zip

# dbt v2 (open-source `dbt-oss` build, Rust engine with DuckDB built in) in its own venv so it
# never fights with Airflow's dependencies. Cosmos calls it via dbt_executable_path.
# The bundled DuckDB driver can't load extensions (DuckLake needs `ducklake` + `postgres`), so we
# also install the system DuckDB ADBC driver with dbc; dbt v2 prefers it over the bundled one.
RUN python -m venv /opt/dbt \
 && /opt/dbt/bin/pip install --no-cache-dir "dbt-oss${DBT_VERSION}" dbc \
 && /opt/dbt/bin/dbc install --level system duckdb \
 && ln -s /opt/dbt/bin/dbt /usr/local/bin/dbt \
 && /opt/dbt/bin/dbt --version

COPY bin/ /usr/local/bin/
RUN chmod +x /usr/local/bin/teratai-entrypoint /usr/local/bin/lake \
 && mkdir -p /lakehouse

USER airflow

RUN pip install --no-cache-dir "apache-airflow==${AIRFLOW_VERSION}" "astronomer-cosmos>=1.13"

# Pre-download DuckDB extensions for the CLI so the first DAG run doesn't race on installs.
RUN duckdb -c "INSTALL ducklake; INSTALL postgres;"

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/teratai-entrypoint"]
CMD ["airflow", "standalone"]
