#!/usr/bin/env bats

load _helpers

@test "testRunner/Pod: enabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/tests/test-runner.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "testRunner/Pod: disabled when tests.enabled=false" {
  cd `chart_dir`
  assert_empty helm template \
      -s templates/tests/test-runner.yaml  \
      --set 'tests.enabled=false' \
      .
}

#--------------------------------------------------------------------
# global.tls.enabled

@test "testRunner/Pod: sets Consul environment variables when global.tls.enabled=false" {
  cd `chart_dir`
  local env=$(helm template \
      -s templates/tests/test-runner.yaml  \
      --set 'tests.enabled=true' \
      --set 'global.tls.enabled=false' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.containers[0].env[]' | tee /dev/stderr)

  local actual=$(echo $env | jq -r '. | select(.name == "CONSUL_HTTP_ADDR") | .value' | tee /dev/stderr)
  [ "${actual}" = 'http://$(HOST_IP):8500' ]
}

@test "testRunner/Pod: sets Consul environment variables when global.tls.enabled=false and custom client HTTP port set" {
  cd `chart_dir`
  local env=$(helm template \
      -s templates/tests/test-runner.yaml  \
      --set 'tests.enabled=true' \
      --set 'global.tls.enabled=false' \
      --set 'client.ports.http.port=32500' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.containers[0].env[]' | tee /dev/stderr)

  local actual=$(echo $env | jq -r '. | select(.name == "CONSUL_HTTP_ADDR") | .value' | tee /dev/stderr)
  [ "${actual}" = 'http://$(HOST_IP):32500' ]
}

@test "testRunner/Pod: sets Consul environment variables when global.tls.enabled" {
  cd `chart_dir`
  local env=$(helm template \
      -s templates/tests/test-runner.yaml  \
      --set 'tests.enabled=true' \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.containers[0].env[]' | tee /dev/stderr)

  local actual=$(echo $env | jq -r '. | select(.name == "CONSUL_HTTP_ADDR") | .value' | tee /dev/stderr)
  [ "${actual}" = 'https://$(HOST_IP):8501' ]

  local actual=$(echo $env | jq -r '. | select(.name == "CONSUL_CACERT") | .value' | tee /dev/stderr)
  [ "${actual}" = "/consul/tls/ca/tls.crt" ]
}

@test "testRunner/Pod: sets Consul environment variables when global.tls.enabled and custom client HTTPS port set" {
  cd `chart_dir`
  local env=$(helm template \
      -s templates/tests/test-runner.yaml  \
      --set 'tests.enabled=true' \
      --set 'global.tls.enabled=true' \
      --set 'client.ports.https.port=32501' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.containers[0].env[]' | tee /dev/stderr)

  local actual=$(echo $env | jq -r '. | select(.name == "CONSUL_HTTP_ADDR") | .value' | tee /dev/stderr)
  [ "${actual}" = 'https://$(HOST_IP):32501' ]

  local actual=$(echo $env | jq -r '. | select(.name == "CONSUL_CACERT") | .value' | tee /dev/stderr)
  [ "${actual}" = "/consul/tls/ca/tls.crt" ]
}
