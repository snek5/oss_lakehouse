#!/usr/bin/env bash
set -e

if [ -z "$SPARK_MASTER_URL" ]; then
  export SPARK_MASTER_URL="spark://spark-master:7077"
fi

ICEBERG_REST_URL="${ICEBERG_REST_URL:-http://iceberg-rest:8181}"

# The Iceberg catalog must answer before Spark tries to use it.
echo "Waiting for Iceberg REST catalog at ${ICEBERG_REST_URL}..."
for i in $(seq 1 60); do
  if curl -sf "${ICEBERG_REST_URL}/v1/config" > /dev/null; then
    echo "Iceberg REST catalog is up."
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "Iceberg REST catalog did not come up after 120s" >&2
    exit 1
  fi
  sleep 2
done

echo "Starting Spark Thrift Server..."

# SPARK_NO_DAEMONIZE (spark-env.sh) keeps this in the foreground
exec $SPARK_HOME/sbin/start-thriftserver.sh \
  --master $SPARK_MASTER_URL \
  --hiveconf hive.server2.thrift.port=10000 \
  --hiveconf hive.server2.thrift.bind.host=0.0.0.0
