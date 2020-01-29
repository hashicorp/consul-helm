#!/usr/bin/env bats

load _helpers

@test "snapshot/PersistentVolumeClaim: disabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-persistent-volume-claim.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "snapshot/PersistentVolumeClaim: enabled with snapshot storage enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-persistent-volume-claim.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.storage.enabled=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "snapshot/PersistentVolumeClaim: disabled with snapshot disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-persistent-volume-claim.yaml  \
      --set 'snapshot.enabled=false' \
      --set 'snapshot.storage.enabled=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "snapshot/PersistentVolumeClaim: disabled with snapshot storage disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-persistent-volume-claim.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.storage.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "snapshot/PersistentVolumeClaim: disabled with snapshot enabled and snapshot.existingClaim defined" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-persistent-volume-claim.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.storage.enabled=true' \
      --set 'snapshot.storage.existingClaim=foobar' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}
