#!/usr/bin/env bash
# Bootstraps (first run) and starts a single-node Ceph cluster with one CephFS filesystem.
#
# On first start it creates: mon, mgr, one BlueStore OSD backed by a sparse file, an MDS,
# the CephFS pools/filesystem, and a client key. The client config + keyring are written to
# /ceph-client so other containers (Airflow) can mount the filesystem with ceph-fuse.
# On later starts it just launches the daemons again from the persisted volumes.
set -euo pipefail

MON_IP="${MON_IP:?MON_IP must be set to the static IP of this container}"
PUBLIC_NETWORK="${PUBLIC_NETWORK:?PUBLIC_NETWORK must be set, e.g. 172.29.10.0/24}"
MON_NAME="${MON_NAME:-mon0}"
MGR_NAME="${MGR_NAME:-mgr0}"
MDS_NAME="${MDS_NAME:-mds0}"
FS_NAME="${CEPHFS_NAME:-lakehouse}"
CLIENT_NAME="${CEPHFS_CLIENT:-lakehouse}"
OSD_SIZE_GB="${OSD_SIZE_GB:-20}"
OSD_MEMORY_TARGET="${OSD_MEMORY_TARGET:-1073741824}"
CLIENT_DIR=/ceph-client

log() { echo "[ceph-aio] $*"; }
uuid() { cat /proc/sys/kernel/random/uuid; }

rm -f "${CLIENT_DIR}/ready"

bootstrap_config() {
  local fsid; fsid="$(uuid)"
  log "writing /etc/ceph/ceph.conf (fsid ${fsid})"
  cat > /etc/ceph/ceph.conf <<EOF
[global]
fsid = ${fsid}
mon_initial_members = ${MON_NAME}
mon_host = [v2:${MON_IP}:3300,v1:${MON_IP}:6789]
public_network = ${PUBLIC_NETWORK}
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx
# single node, single OSD: no replication
osd_pool_default_size = 1
osd_pool_default_min_size = 1
osd_pool_default_pg_num = 16
osd_crush_chooseleaf_type = 0
mon_allow_pool_size_one = true
mon_allow_pool_delete = true
mon_warn_on_pool_no_redundancy = false
mon_data_avail_warn = 5
mon_data_avail_crit = 2

[osd]
osd_objectstore = bluestore
bluestore_block_create = true
bluestore_block_size = $((OSD_SIZE_GB * 1024 * 1024 * 1024))
osd_memory_target = ${OSD_MEMORY_TARGET}

[mds]
mds_cache_memory_limit = 268435456
EOF
}

bootstrap_mon() {
  log "bootstrapping monitor ${MON_NAME}"
  local fsid; fsid="$(awk '/^fsid/ {print $3}' /etc/ceph/ceph.conf)"
  mkdir -p /var/lib/ceph/bootstrap-osd "/var/lib/ceph/mon/ceph-${MON_NAME}"
  ceph-authtool --create-keyring /tmp/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'
  ceph-authtool --create-keyring /etc/ceph/ceph.client.admin.keyring --gen-key -n client.admin \
    --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow *' --cap mgr 'allow *'
  ceph-authtool --create-keyring /var/lib/ceph/bootstrap-osd/ceph.keyring --gen-key -n client.bootstrap-osd \
    --cap mon 'profile bootstrap-osd' --cap mgr 'allow r'
  ceph-authtool /tmp/ceph.mon.keyring --import-keyring /etc/ceph/ceph.client.admin.keyring
  ceph-authtool /tmp/ceph.mon.keyring --import-keyring /var/lib/ceph/bootstrap-osd/ceph.keyring
  monmaptool --create --addv "${MON_NAME}" "[v2:${MON_IP}:3300,v1:${MON_IP}:6789]" --fsid "${fsid}" /tmp/monmap
  ceph-mon --mkfs -i "${MON_NAME}" --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring
  rm -f /tmp/ceph.mon.keyring /tmp/monmap
}

wait_for_mon() {
  for _ in $(seq 1 60); do
    ceph -s --connect-timeout 5 >/dev/null 2>&1 && return 0
    sleep 2
  done
  log "monitor did not come up"; exit 1
}

start_mgr() {
  local dir="/var/lib/ceph/mgr/ceph-${MGR_NAME}"
  if [ ! -f "${dir}/keyring" ]; then
    mkdir -p "${dir}"
    ceph auth get-or-create "mgr.${MGR_NAME}" mon 'allow profile mgr' osd 'allow *' mds 'allow *' \
      -o "${dir}/keyring"
  fi
  ceph-mgr -f -i "${MGR_NAME}" &
}

start_osd() {
  local id
  if [ ! -f /var/lib/ceph/osd/osd_id ]; then
    log "creating OSD (${OSD_SIZE_GB}G sparse BlueStore file)"
    local osd_uuid; osd_uuid="$(uuid)"
    id="$(ceph osd new "${osd_uuid}")"
    local dir="/var/lib/ceph/osd/ceph-${id}"
    mkdir -p "${dir}"
    ceph auth get-or-create "osd.${id}" osd 'allow *' mon 'allow profile osd' mgr 'allow profile osd' \
      -o "${dir}/keyring"
    ceph-osd -i "${id}" --mkfs --osd-uuid "${osd_uuid}"
    echo "${id}" > /var/lib/ceph/osd/osd_id
  fi
  id="$(cat /var/lib/ceph/osd/osd_id)"
  ceph-osd -f -i "${id}" &
}

start_mds() {
  local dir="/var/lib/ceph/mds/ceph-${MDS_NAME}"
  if [ ! -f "${dir}/keyring" ]; then
    mkdir -p "${dir}"
    ceph auth get-or-create "mds.${MDS_NAME}" mon 'profile mds' mgr 'profile mds' mds 'allow *' osd 'allow *' \
      -o "${dir}/keyring"
  fi
  ceph-mds -f -i "${MDS_NAME}" &
}

ensure_filesystem() {
  if ! ceph fs ls 2>/dev/null | grep -q "name: ${FS_NAME},"; then
    log "creating CephFS '${FS_NAME}'"
    for pool in "${FS_NAME}_metadata" "${FS_NAME}_data"; do
      ceph osd pool create "${pool}" 16
      ceph osd pool set "${pool}" size 1 --yes-i-really-mean-it
    done
    ceph fs new "${FS_NAME}" "${FS_NAME}_metadata" "${FS_NAME}_data"
  fi
}

export_client_config() {
  mkdir -p "${CLIENT_DIR}"
  if ! ceph auth get "client.${CLIENT_NAME}" >/dev/null 2>&1; then
    ceph fs authorize "${FS_NAME}" "client.${CLIENT_NAME}" / rw >/dev/null
  fi
  ceph auth get "client.${CLIENT_NAME}" -o "${CLIENT_DIR}/ceph.client.${CLIENT_NAME}.keyring"
  ceph config generate-minimal-conf > "${CLIENT_DIR}/ceph.conf"
  chmod 644 "${CLIENT_DIR}/ceph.conf" "${CLIENT_DIR}/ceph.client.${CLIENT_NAME}.keyring"
}

# ---- main ----------------------------------------------------------------
[ -f /etc/ceph/ceph.conf ] || bootstrap_config
[ -d "/var/lib/ceph/mon/ceph-${MON_NAME}/store.db" ] || bootstrap_mon

ceph-mon -f -i "${MON_NAME}" --public-addr "${MON_IP}" &
wait_for_mon
ceph config set mon auth_allow_insecure_global_id_reclaim false >/dev/null 2>&1 || true

start_mgr
start_osd
start_mds
ensure_filesystem

log "waiting for MDS to become active"
until ceph mds stat 2>/dev/null | grep -q "up:active"; do sleep 2; done

export_client_config
touch "${CLIENT_DIR}/ready"
log "CephFS '${FS_NAME}' is ready; client config exported to ${CLIENT_DIR}"
ceph -s || true

# Exit (and let Docker restart us) if any daemon dies.
wait -n
log "a ceph daemon exited; shutting down"
exit 1
