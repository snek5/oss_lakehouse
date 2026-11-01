# Single-node Ceph (mon + mgr + osd + mds) that exposes one CephFS filesystem.
# For local development only: one OSD on a file-backed BlueStore device, replication size 1.
ARG CEPH_IMAGE=quay.io/ceph/ceph:v19
FROM ${CEPH_IMAGE}

COPY entrypoint.sh /usr/local/bin/ceph-aio
RUN chmod +x /usr/local/bin/ceph-aio

VOLUME ["/etc/ceph", "/var/lib/ceph", "/ceph-client"]
EXPOSE 3300 6789

HEALTHCHECK --interval=10s --timeout=10s --start-period=60s --retries=30 \
  CMD test -f /ceph-client/ready && ceph mds stat 2>/dev/null | grep -q "up:active"

ENTRYPOINT ["/usr/local/bin/ceph-aio"]
