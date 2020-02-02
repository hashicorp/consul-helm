#!/usr/bin/env bats

load _helpers

#--------------------------------------------------------------------
# secret

@test "ui/ingress/tls/secret: disabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress-tls-secret.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "ui/ingress/tls/secret: enabled when certificats is provided" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress-tls-secret.yaml  \
      --set 'ui.ingress.secrets[0].key=foo' \
      --set 'ui.ingress.secrets[0].certificate=bar' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ui/ingress/tls/secret: disable with server.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress-tls-secret.yaml  \
      --set 'ui.ingress.secrets[0].key=foo' \
      --set 'ui.ingress.secrets[0].certificate=bar' \
      --set 'server.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "ui/ingress/tls/secret: disable with ui.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress-tls-secret.yaml  \
      --set 'ui.ingress.secrets[0].key=foo' \
      --set 'ui.ingress.secrets[0].certificate=bar' \
      --set 'ui.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "ui/ingress/tls/secret: disable with ui.ingress.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress-tls-secret.yaml  \
      --set 'ui.ingress.secrets[0].key=foo' \
      --set 'ui.ingress.secrets[0].certificate=bar' \
      --set 'ui.ingress.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "ui/ingress/tls/secret: disable with global.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress-tls-secret.yaml  \
      --set 'ui.ingress.secrets[0].key=foo' \
      --set 'ui.ingress.secrets[0].certificate=bar' \
      --set 'global.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}