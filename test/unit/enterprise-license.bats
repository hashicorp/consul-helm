#!/usr/bin/env bats

load _helpers

@test "server/EnterpriseLicense: disabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/enterprise-license.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "server/EnterpriseLicense: disabled when servers are disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/enterprise-license.yaml  \
      --set 'server.enabled=false' \
      --set 'server.enterpriseLicense.secretName=foo' \
      --set 'server.enterpriseLicense.secretKey=bar' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "server/EnterpriseLicense: disabled when secretName is missing" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/enterprise-license.yaml  \
      --set 'server.enterpriseLicense.secretKey=bar' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "server/EnterpriseLicense: disabled when secretKey is missing" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/enterprise-license.yaml  \
      --set 'server.enterpriseLicense.secretName=foo' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "server/EnterpriseLicense: enabled when secretName and secretKey is provided" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/enterprise-license.yaml  \
      --set 'server.enterpriseLicense.secretName=foo' \
      --set 'server.enterpriseLicense.secretKey=bar' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# TLS

@test "server/EnterpriseLicense: no volumes when TLS is disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/enterprise-license.yaml  \
      --set 'server.enterpriseLicense.secretName=foo' \
      --set 'server.enterpriseLicense.secretKey=bar' \
      --set 'global.tls.enabled=false' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.volumes | length' | tee /dev/stderr)
  [ "${actual}" = "0" ]
}

@test "server/EnterpriseLicense: volumes present when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/enterprise-license.yaml  \
      --set 'server.enterpriseLicense.secretName=foo' \
      --set 'server.enterpriseLicense.secretKey=bar' \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.volumes | length' | tee /dev/stderr)
  [ "${actual}" = "2" ]
}

@test "server/EnterpriseLicense: no volumes mounted when TLS is disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/enterprise-license.yaml  \
      --set 'server.enterpriseLicense.secretName=foo' \
      --set 'server.enterpriseLicense.secretKey=bar' \
      --set 'global.tls.enabled=false' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].volumeMounts | length' | tee /dev/stderr)
  [ "${actual}" = "0" ]
}

@test "server/EnterpriseLicense: volumes mounted when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/enterprise-license.yaml  \
      --set 'server.enterpriseLicense.secretName=foo' \
      --set 'server.enterpriseLicense.secretKey=bar' \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].volumeMounts | length' | tee /dev/stderr)
  [ "${actual}" = "2" ]
}

@test "server/EnterpriseLicense: URL is http when TLS is disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/enterprise-license.yaml  \
      --set 'server.enterpriseLicense.secretName=foo' \
      --set 'server.enterpriseLicense.secretKey=bar' \
      --set 'global.tls.enabled=false' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | join(" ") | contains("http://")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/EnterpriseLicense: Port is 8500 when TLS is disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/enterprise-license.yaml  \
      --set 'server.enterpriseLicense.secretName=foo' \
      --set 'server.enterpriseLicense.secretKey=bar' \
      --set 'global.tls.enabled=false' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | join(" ") | contains(":8500")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/EnterpriseLicense: URL is https when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/enterprise-license.yaml  \
      --set 'server.enterpriseLicense.secretName=foo' \
      --set 'server.enterpriseLicense.secretKey=bar' \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | join(" ") | contains("https://")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/EnterpriseLicense: Port is 8501 when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/enterprise-license.yaml  \
      --set 'server.enterpriseLicense.secretName=foo' \
      --set 'server.enterpriseLicense.secretKey=bar' \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | join(" ") | contains(":8501")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/EnterpriseLicense: CA certificate is specified when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/enterprise-license.yaml  \
      --set 'server.enterpriseLicense.secretName=foo' \
      --set 'server.enterpriseLicense.secretKey=bar' \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | join(" ") | contains("--cacert /consul/tls/ca/tls.crt")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/EnterpriseLicense: client certificate is specified when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/enterprise-license.yaml  \
      --set 'server.enterpriseLicense.secretName=foo' \
      --set 'server.enterpriseLicense.secretKey=bar' \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | join(" ") | contains("--cert /consul/tls/cli/tls.crt")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/EnterpriseLicense: client key is specified when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/enterprise-license.yaml  \
      --set 'server.enterpriseLicense.secretName=foo' \
      --set 'server.enterpriseLicense.secretKey=bar' \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | join(" ") | contains("--key /consul/tls/cli/tls.key")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

