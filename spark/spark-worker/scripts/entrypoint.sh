#!/usr/bin/env bash
set -e

echo "Starting Spark Worker..."

if [ -z "$SPARK_MASTER_URL" ]; then
  export SPARK_MASTER_URL="spark://spark-master:7077"
fi

# SPARK_NO_DAEMONIZE (spark-env.sh) keeps this in the foreground
exec $SPARK_HOME/sbin/start-worker.sh $SPARK_MASTER_URL
