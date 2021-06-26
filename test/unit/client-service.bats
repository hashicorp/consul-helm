#!/usr/bin/env bats

load _helpers

@test "client/Service: disabled by default" {
  cd `chart_dir`
  assert_empty helm template \
      -s templates/client-service.yaml  \
      .
}

@test "client/Service: disabled with global.enabled=true" {
  cd `chart_dir`
  assert_empty helm template \
      -s templates/client-service.yaml  \
      --set 'global.enabled=true' \
      .
}

@test "client/Service: disabled with client.enabled=true" {
  cd `chart_dir`
  assert_empty helm template \
      -s templates/client-service.yaml  \
      --set 'client.enabled=true' \
      .
}

@test "client/Service: enabled with global.enabled=true and client.service.enabled=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'global.enabled=true' \
      --set 'client.service.enabled=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "client/Service: enabled with client.enabled=true and client.service.enabled=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# global.tls.enabled

@test "client/Service: no HTTPS listener when TLS is disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'global.tls.enabled=false' \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[] | select(.name == "https") | .port' | tee /dev/stderr)
  [ "${actual}" == "" ]
}

@test "client/Service: HTTPS listener set when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'global.tls.enabled=true' \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[] | select(.name == "https") | .port' | tee /dev/stderr)
  [ "${actual}" == "8501" ]
}

@test "client/Service: HTTP listener still active when httpsOnly is disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.httpsOnly=false' \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[] | select(.name == "http") | .port' | tee /dev/stderr)
  [ "${actual}" == "8500" ]
}

@test "client/Service: no HTTP listener when httpsOnly is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.httpsOnly=true' \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[] | select(.name == "http") | .port' | tee /dev/stderr)
  [ "${actual}" == "" ]
}

#--------------------------------------------------------------------
# nodePorts http

@test "client/Service: has default HTTP port" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[0].port' | tee /dev/stderr)
  [ "${actual}" = "8500" ]
}

@test "client/Service: can set HTTP port" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      --set 'client.service.nodePorts.http.port=32500' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[0].port' | tee /dev/stderr)
  [ "${actual}" = "32500" ]
}

@test "client/Service: has default HTTP nodePort" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[0].nodePort' | tee /dev/stderr)
  [ "${actual}" = "8500" ]
}

@test "client/Service: can set HTTP nodePort" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      --set 'client.service.nodePorts.http.nodePort=32500' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[0].nodePort' | tee /dev/stderr)
  [ "${actual}" = "32500" ]
}

@test "client/Service: has default HTTP targetPort" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[0].targetPort' | tee /dev/stderr)
  [ "${actual}" = "8500" ]
}

@test "client/Service: can set HTTP targetPort" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      --set 'client.service.nodePorts.http.targetPort=32500' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[0].targetPort' | tee /dev/stderr)
  [ "${actual}" = "32500" ]
}

#--------------------------------------------------------------------
# nodePorts https

@test "client/Service: has default HTTPS port" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'global.tls.enabled=true' \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[0].port' | tee /dev/stderr)
  [ "${actual}" = "8501" ]
}

@test "client/Service: can set HTTPS port" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'global.tls.enabled=true' \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      --set 'client.service.nodePorts.https.port=32501' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[0].port' | tee /dev/stderr)
  [ "${actual}" = "32501" ]
}

@test "client/Service: has default HTTPS nodePort" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'global.tls.enabled=true' \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[0].nodePort' | tee /dev/stderr)
  [ "${actual}" = "8501" ]
}

@test "client/Service: can set HTTPS nodePort" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'global.tls.enabled=true' \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      --set 'client.service.nodePorts.https.nodePort=32501' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[0].nodePort' | tee /dev/stderr)
  [ "${actual}" = "32501" ]
}

@test "client/Service: has default HTTPS targetPort" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'global.tls.enabled=true' \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[0].targetPort' | tee /dev/stderr)
  [ "${actual}" = "8501" ]
}

@test "client/Service: can set HTTPS targetPort" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'global.tls.enabled=true' \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      --set 'client.service.nodePorts.https.targetPort=32501' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[0].targetPort' | tee /dev/stderr)
  [ "${actual}" = "32501" ]
}

#--------------------------------------------------------------------
# nodePorts grpc

@test "client/Service: has default GRPC port" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[1].port' | tee /dev/stderr)
  [ "${actual}" = "8502" ]
}

@test "client/Service: can set GRPC port" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      --set 'client.service.nodePorts.grpc.port=32502' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[1].port' | tee /dev/stderr)
  [ "${actual}" = "32502" ]
}

@test "client/Service: has default GRPC nodePort" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[1].nodePort' | tee /dev/stderr)
  [ "${actual}" = "8502" ]
}

@test "client/Service: can set GRPC nodePort" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      --set 'client.service.nodePorts.grpc.nodePort=32502' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[1].nodePort' | tee /dev/stderr)
  [ "${actual}" = "32502" ]
}

@test "client/Service: has default GRPC targetPort" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[1].targetPort' | tee /dev/stderr)
  [ "${actual}" = "8502" ]
}

@test "client/Service: can set GRPC targetPort" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      --set 'client.service.nodePorts.grpc.targetPort=32502' \
      . | tee /dev/stderr |
      yq -r '.spec.ports[1].targetPort' | tee /dev/stderr)
  [ "${actual}" = "32502" ]
}

#--------------------------------------------------------------------
# annotations

@test "client/Service: no annotations by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.metadata.annotations' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "client/Service: can set annotations" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      --set 'client.service.annotations=key: value' \
      . | tee /dev/stderr |
      yq -r '.metadata.annotations.key' | tee /dev/stderr)
  [ "${actual}" = "value" ]
}

#--------------------------------------------------------------------
# topologyKeys

@test "client/Service: no topologyKeys by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.topologyKeys' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "client/Service: can add topologyKeys" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      --set 'client.service.topologyKeys=key: value' \
      . | tee /dev/stderr |
      yq -r '.spec.topologyKeys.key' | tee /dev/stderr)
  [ "${actual}" = "value" ]
}

#--------------------------------------------------------------------
# additionalSpec

@test "client/Service: can add additionalSpec" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/client-service.yaml  \
      --set 'client.enabled=true' \
      --set 'client.service.enabled=true' \
      --set 'client.service.additionalSpec=key: value' \
      . | tee /dev/stderr |
      yq -r '.spec.key' | tee /dev/stderr)
  [ "${actual}" = "value" ]
}
