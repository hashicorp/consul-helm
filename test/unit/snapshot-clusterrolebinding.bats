#!/usr/bin/env bats

load _helpers

@test "snapshot/ClusterRoleBinding: disabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-clusterrolebinding.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "snapshot/ClusterRoleBinding: disabled with global.enabled=false" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-clusterrolebinding.yaml  \
      --set 'global.enabled=false' \
      --set 'snapshot.enabled=-' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "snapshot/ClusterRoleBinding: disabled with snapshot disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-clusterrolebinding.yaml  \
      --set 'snapshot.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "snapshot/ClusterRoleBinding: enabled with snapshot enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-clusterrolebinding.yaml  \
      --set 'snapshot.enabled=true' \
      . | tee /dev/stderr |
      yq -s 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "snapshot/ClusterRoleBinding: enabled with snapshot enabled and global.enabled=false" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-clusterrolebinding.yaml  \
      --set 'global.enabled=false' \
      --set 'snapshot.enabled=true' \
      . | tee /dev/stderr |
      yq -s 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}
