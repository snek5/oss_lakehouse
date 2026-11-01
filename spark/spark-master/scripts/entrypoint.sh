#!/usr/bin/env bash
set -e

echo "Starting Spark Master..."

# SPARK_NO_DAEMONIZE (spark-env.sh) keeps this in the foreground
exec $SPARK_HOME/sbin/start-master.sh --host spark-master

# Keep container alive
