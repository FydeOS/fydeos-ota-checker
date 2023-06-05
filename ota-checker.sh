#!/bin/bash

VERSION="0.0.1"
kernelA=2
kernelB=4
rootA=3
rootB=5

EEXIST=17
MNT="$(mktemp -d)"

cleanup() {
    umount -lf "$MNT" 2>/dev/null || :
}

get_cur_part() {
  /usr/bin/rootdev
}

get_disk_dev() {
  /usr/bin/rootdev -d
}

get_part_num_of() {
  local dev=$1
  echo ${dev##*[a-z]}
}

get_another_slot() {
  local cur_part="$(get_cur_part)"
  local cur_slot="$(get_part_num_of $cur_part)"

  if [ "$cur_slot" == "$rootA" ]; then
    echo "$rootB"
  elif [ "$cur_slot" == "$rootB" ]; then
    echo "$rootA"
  else
    exit 1
  fi
}

get_another_part() {
  local part="$(get_cur_part)"
  local slot="$(get_another_slot)"

  part=${part%[0-9]}
  part=${part%[0-9]}
  part="$part""$slot"

  echo "$part"
}

get_os_version() {
  local lsbfile=$1
  local version=$(cat $lsbfile | grep CHROMEOS_RELEASE_VERSION)
  echo ${version#*=}
}

get_part_priority() {
  cgpt show -i $1 -P $2
}

determin_root_num() {
  local current_dev=$(get_disk_dev)
  local priorityA=$(get_part_priority $kernelA $current_dev)
  local priorityB=$(get_part_priority $kernelB $current_dev)

  if [ "$priorityA" -ge "$priorityB" ]; then
    echo $rootA
  else
    echo $rootB
  fi
}

error() {
  echo $@
  exit 1
}

compare_versions() {
    if [[ $1 == $2 ]]; then
        return 0
    fi
    local IFS=.
    # Everything after the first character not in [^0-9.] is compared
    local i a=(${1%%[^0-9.]*}) b=(${2%%[^0-9.]*})
    local arem=${1#${1%%[^0-9.]*}} brem=${2#${2%%[^0-9.]*}}
    for ((i=0; i<${#a[@]} || i<${#b[@]}; i++)); do
        if ((10#${a[i]:-0} < 10#${b[i]:-0})); then
            return 2
        elif ((10#${a[i]:-0} > 10#${b[i]:-0})); then
            return 1
        fi
    done
    if [ "$arem" '<' "$brem" ]; then
        return 2
    elif [ "$arem" '>' "$brem" ]; then
        return 1
    fi
    return 0
}

main() {
  local ahama_version=$1

  local target_part="$(get_another_part)"
  local target_partnum=$(get_part_num_of $target_part)

  # It means the last OTA install was not finished.
  # [ "$(determin_root_num)" != "$target_partnum" ] && error "kernel priority is not right, let OTA continue"

  trap cleanup EXIT

  mount -oro $target_part $MNT || error "failed to mount ${target_part}, let OTA continue"

  local target_version="$(get_os_version ${MNT}/etc/lsb-release)"

  echo "target_version ${target_version} ahama_version: ${ahama_version}"

  compare_versions $target_version $ahama_version

  if [[ "$target_version" == "$ahama_version" ]]; then
      echo "target version: ${target_version} is samee as ohama response version. Stop OTA."
      exit $EEXIST
  fi

  umount $MNT
}

main "$@"
