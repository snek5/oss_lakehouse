FROM spark:4.1.2-scala2.13-java21-python3-ubuntu

USER root

# -----------------------------
# System utilities
# -----------------------------
RUN apt-get update && apt-get install -y \
    curl \
    bash \
    ca-certificates \
    tini \
 && rm -rf /var/lib/apt/lists/*

# -----------------------------
# Spark / Iceberg versions
# -----------------------------
ARG ICEBERG_VERSION=1.11.0
ARG AWS_SDK_VERSION=2.25.60
ARG POSTGRES_JDBC_VERSION=42.7.3
ARG MAVEN=https://repo1.maven.org/maven2

# -----------------------------
# Extra jars go straight into $SPARK_HOME/jars so the master, workers and
# thrift server all have them on the classpath. (Spark does not read a
# SPARK_EXTRA_JARS variable, so a separate jars-extra folder is never loaded.)
# curl -f makes the build fail loudly if a download 404s.
# -----------------------------

# Iceberg runtime for Spark 4.1 / Scala 2.13
RUN curl -fL -o /opt/spark/jars/iceberg-spark-runtime.jar \
    ${MAVEN}/org/apache/iceberg/iceberg-spark-runtime-4.1_2.13/${ICEBERG_VERSION}/iceberg-spark-runtime-4.1_2.13-${ICEBERG_VERSION}.jar

# hadoop-aws must match the Hadoop version bundled with Spark exactly,
# so detect it from the hadoop-client-api jar instead of hardcoding it.
RUN HADOOP_VERSION=$(ls /opt/spark/jars/hadoop-client-api-*.jar | sed -E 's/.*hadoop-client-api-(.*)\.jar/\1/') \
 && echo "Detected Hadoop ${HADOOP_VERSION}" \
 && curl -fL -o /opt/spark/jars/hadoop-aws.jar \
    ${MAVEN}/org/apache/hadoop/hadoop-aws/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar

# AWS SDK v2 bundle (used by both hadoop-aws/S3A and Iceberg S3FileIO)
RUN curl -fL -o /opt/spark/jars/aws-sdk-bundle.jar \
    ${MAVEN}/software/amazon/awssdk/bundle/${AWS_SDK_VERSION}/bundle-${AWS_SDK_VERSION}.jar

# PostgreSQL JDBC driver
RUN curl -fL -o /opt/spark/jars/postgresql.jar \
    ${MAVEN}/org/postgresql/postgresql/${POSTGRES_JDBC_VERSION}/postgresql-${POSTGRES_JDBC_VERSION}.jar

# -----------------------------
# Spark configuration (Iceberg catalog, MinIO, event logs)
# -----------------------------
COPY conf/spark-defaults.conf /opt/spark/conf/spark-defaults.conf
COPY conf/spark-env.sh /opt/spark/conf/spark-env.sh
RUN chmod +x /opt/spark/conf/spark-env.sh \
 && mkdir -p /tmp/spark-events /tmp/spark-logs

# -----------------------------
# Entrypoint handling
# -----------------------------
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash"]
