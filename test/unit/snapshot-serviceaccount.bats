#!/usr/bin/env bats

load _helpers

@test "snapshot/ServiceAccount: disabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-serviceaccount.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "snapshot/ServiceAccount: disabled with global.enabled=false" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-serviceaccount.yaml  \
      --set 'snabled.enabled="-"' \
      --set 'global.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "snapshot/ServiceAccount: disabled with snapshot disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-serviceaccount.yaml  \
      --set 'snapshot.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "snapshot/ServiceAccount: enabled with snapshot enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-serviceaccount.yaml  \
      --set 'snapshot.enabled=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "snapshot/ServiceAccount: enabled with snapshot enabled and global.enabled=false" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-serviceaccount.yaml  \
      --set 'global.enabled=false' \
      --set 'snapshot.enabled=true' \
      . | tee /dev/stderr |
      yq -s 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}
