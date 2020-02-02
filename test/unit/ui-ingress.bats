#!/usr/bin/env bats

load _helpers

#--------------------------------------------------------------------
# secret

@test "ui/ingress: enabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ui/ingress: enable with global.enabled false" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress.yaml  \
      --set 'global.enabled=false' \
      --set 'server.enabled=true' \
      --set 'ui.enabled=true' \
      --set 'ui.ingress.enabled=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ui/ingress: disable with server.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress.yaml  \
      --set 'server.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "ui/ingress: disable with ui.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress.yaml  \
      --set 'ui.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "ui/ingress: disable with ui.ingress.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress.yaml  \
      --set 'ui.ingress.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "ui/ingress: disable with global.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-secret.yaml  \
      --set 'global.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}


@test "ui/ingress: no cert manager by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress.yaml  \
      . | tee /dev/stderr |
      yq '.metadata.annotations["kubernetes.io/tls-acme"]? == null' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ui/ingress: cert manager when is specified" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress.yaml  \
      --set 'ui.ingress.certManager=true' \
      . | tee /dev/stderr |
      yq '.metadata.annotations["kubernetes.io/tls-acme"] == "true" ' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ui/ingress: not set https bakend when tls is disable" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress.yaml  \
      --set 'global.tls.enabled=false' \
      . | tee /dev/stderr |
      yq '.metadata.annotations["nginx.ingress.kubernetes.io/backend-protocol"]? == null ' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ui/ingress: set https bakend when tls is disable" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.metadata.annotations["nginx.ingress.kubernetes.io/backend-protocol"] == "HTTPS" ' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}


@test "ui/ingress: set default host" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress.yaml  \
      . | tee /dev/stderr |
      yq '.spec.rules[] | length > 0 ' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ui/ingress: disable tls per default when global.tls.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress.yaml  \
      --set 'global.tls.enabled=false' \
      . | tee /dev/stderr |
      yq '.spec.tls? == null ' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ui/ingress: enabled tls per default when global.tls.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.tls[] | length > 0 ' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ui/ingress: force tls when global.tls.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress.yaml  \
      --set 'global.tls.enabled=true' \
      --set 'ui.ingress.hosts[0].tls=false' \
      . | tee /dev/stderr |
      yq '.spec.tls[] | length > 0 ' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ui/ingress: set tls when is specified" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress.yaml  \
      --set 'global.tls.enabled=false' \
      --set 'ui.ingress.hosts[0].tls=true' \
      . | tee /dev/stderr |
      yq '.spec.tls[] | length > 0 ' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}


@test "ui/ingress: default secret name" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.tls[0].secretName != "" ' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ui/ingress: default host name" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.tls[0].hosts[0] != "" ' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ui/ingress: service port to use is https when global.tls.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.rules[0].http.paths[0].backend.servicePort == "https" ' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ui/ingress: service port to use is http when global.tls.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ui-ingress.yaml  \
      --set 'global.tls.enabled=false' \
      . | tee /dev/stderr |
      yq '.spec.rules[0].http.paths[0].backend.servicePort == "http" ' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}