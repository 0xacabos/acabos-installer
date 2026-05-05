#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# topology.sh -- ZFS dataset hierarchy and property definitions.
#
# Defines the expected dataset layout for ACABROOT-XXXX pools.
# Used by ZFS_CREATE (create datasets), probes (verify topology), and doctor.
#
# build_topology(pool_name) populates three globals:
#   TOPOLOGY_DATASETS  -- ordered array of all dataset names
#   TOPOLOGY_PROPS     -- associative array: dataset -> "prop=val:prop=val:..."
#   TOPOLOGY_MOUNTPOINTS -- associative array: dataset -> mountpoint path
#
# Property values use colon-separated key=value pairs. Empty string = inherit all.
# Topology version: TOPOLOGY_VERSION in common.sh. Increment when changing structure.

build_topology() {
  local pool_name="$1"

  TOPOLOGY_DATASETS=(
    "${pool_name}"
    "${pool_name}/ROOT"
    "${pool_name}/ROOT/acabos"
    "${pool_name}/opt"
    "${pool_name}/opt/acab"
    "${pool_name}/opt/acab/models"
    "${pool_name}/opt/acab/state"
    "${pool_name}/opt/acab/logs"
    "${pool_name}/opt/ai-venv"
    "${pool_name}/opt/llama-cpp"
    "${pool_name}/var"
    "${pool_name}/var/lib"
    "${pool_name}/home"
    "${pool_name}/var/lib/containers"
    "${pool_name}/var/lib/acab"
    "${pool_name}/var/log"
    "${pool_name}/var/cache"
    "${pool_name}/var/tmp"
    "${pool_name}/swap"
  )

  declare -gA TOPOLOGY_PROPS
  TOPOLOGY_PROPS=(
    ["${pool_name}"]="compression=zstd:atime=off:xattr=sa"
    ["${pool_name}/ROOT"]="canmount=off"
    ["${pool_name}/ROOT/acabos"]="mountpoint=/:canmount=noauto"
    ["${pool_name}/opt"]="canmount=off"
    ["${pool_name}/opt/acab"]="canmount=off"
    ["${pool_name}/opt/acab/models"]="compression=zstd:atime=off:recordsize=1M"
    ["${pool_name}/opt/acab/state"]="compression=zstd:atime=off:recordsize=16K"
    ["${pool_name}/opt/acab/logs"]="compression=zstd:atime=off:recordsize=16K"
    ["${pool_name}/opt/ai-venv"]="compression=zstd:atime=off"
    ["${pool_name}/opt/llama-cpp"]="compression=zstd:atime=off"
    ["${pool_name}/var"]="canmount=off"
    ["${pool_name}/var/lib"]="canmount=off"
    ["${pool_name}/var/lib/containers"]="compression=zstd:atime=off"
    ["${pool_name}/home"]=""
    ["${pool_name}/var/lib/acab"]=""
    ["${pool_name}/var/log"]=""
    ["${pool_name}/var/cache"]="compression=zstd:atime=off"
    ["${pool_name}/var/tmp"]="compression=zstd:atime=off"
  )

  declare -gA TOPOLOGY_MOUNTPOINTS
  TOPOLOGY_MOUNTPOINTS=(
    ["${pool_name}/ROOT/acabos"]="/"
    ["${pool_name}/opt/acab/models"]="/opt/acab/models"
    ["${pool_name}/opt/acab/state"]="/opt/acab/state"
    ["${pool_name}/opt/acab/logs"]="/opt/acab/logs"
    ["${pool_name}/opt/ai-venv"]="/opt/ai-venv"
    ["${pool_name}/opt/llama-cpp"]="/opt/llama-cpp"
    ["${pool_name}/var/lib/containers"]="/var/lib/containers"
    ["${pool_name}/var/lib/acab"]="/var/lib/acab"
    ["${pool_name}/var/log"]="/var/log"
    ["${pool_name}/var/cache"]="/var/cache"
    ["${pool_name}/var/tmp"]="/var/tmp"
    ["${pool_name}/home"]="/home"
  )
}

get_topology_sorted() {
  printf '%s\n' "${TOPOLOGY_DATASETS[@]}" | sort
}
