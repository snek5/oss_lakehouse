#!/usr/bin/env bash

export SPARK_HOME=/opt/spark
export SPARK_CONF_DIR=/opt/spark/conf

# JAVA_HOME is already set by the official spark image (/opt/java/openjdk).
# Do not hardcode a distro path here; it does not exist in this image.

export PATH=$SPARK_HOME/bin:$SPARK_HOME/sbin:$PATH

# Run daemons in the foreground so logs go to `docker compose logs`
# and the container stops if the process dies.
export SPARK_NO_DAEMONIZE=true

export SPARK_LOG_DIR=/tmp/spark-logs

# Ensure consistent hostname resolution inside docker network
export SPARK_LOCAL_IP=$(hostname -i | awk '{print $1}')
