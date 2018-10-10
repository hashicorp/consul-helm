#!/usr/bin/env bats

load _helpers

@test "server-external/Service: disabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-external-service.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "server-external/Service: enable with global.enabled false" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-external-service.yaml  \
      --set 'global.enabled=false' \
      --set 'server.external.enabled=true' \
      . | tee /dev/stderr |
      yq -s 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server-external/Service: disable with server.external.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-external-service.yaml  \
      --set 'server.external.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "server-external/Service: disable with global.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-external-service.yaml  \
      --set 'global.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "server-external/Service: tolerates unready endpoints" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-external-service.yaml  \
      --set 'server.external.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[1].metadata.annotations["service.alpha.kubernetes.io/tolerate-unready-endpoints"]' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(helm template \
      -x templates/server-external-service.yaml  \
      --set 'server.external.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[1].spec.publishNotReadyAddresses' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}
