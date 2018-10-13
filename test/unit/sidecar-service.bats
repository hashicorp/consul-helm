#!/usr/bin/env bats

load _helpers

@test "sidecar/Service: disabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/sidecar-service.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "sidecar/Service: enable with server.prometheusSidecar.enable true" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/sidecar-service.yaml  \
      --set 'server.prometheusSidecar.enabled=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}
