#!/usr/bin/env bats

load _helpers

@test "server/ClusterRole: enabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-clusterrole.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/ClusterRole: disabled with global.enabled=false" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-clusterrole.yaml  \
      --set 'global.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "server/ClusterRole: can be enabled with global.enabled=false" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-clusterrole.yaml  \
      --set 'global.enabled=false' \
      --set 'server.enabled=true' \
      . | tee /dev/stderr |
      yq -s 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/ClusterRole: disabled with server.enabled=false" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-clusterrole.yaml  \
      --set 'server.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "server/ClusterRole: enabled with server.enabled=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-clusterrole.yaml  \
      --set 'server.enabled=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

# The rules key must always be set (#178).
@test "server/ClusterRole: rules empty with server.enabled=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-clusterrole.yaml  \
      --set 'server.enabled=true' \
      . | tee /dev/stderr |
      yq '.rules' | tee /dev/stderr)
  [ "${actual}" = "[]" ]
}

#--------------------------------------------------------------------
# global.tls.enabled

@test "client/ClusterRole: allows read-only access to Consul CA and server cert with global.tls.enabled=true" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/server-clusterrole.yaml  \
      --set 'server.enabled=true' \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.rules[] | select(.resourceNames==["release-name-consul-ca-cert", "release-name-consul-server-cert"])' | tee /dev/stderr)

  # check read-only access
  local actual=$(echo ${object} | yq -r '.verbs==["get"]' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "client/ClusterRole: adds rules when both global.tls.enabled=true and global.bootstrapACLs=true" {
  cd `chart_dir`
  local has_tls_rules=$(helm template \
      -x templates/server-clusterrole.yaml  \
      --set 'server.enabled=true' \
      --set 'global.tls.enabled=true' \
      --set 'global.enablePodSecurityPolicies=true' \
      . | tee /dev/stderr |
      yq -r '.rules[] | select(.resourceNames==["release-name-consul-ca-cert", "release-name-consul-server-cert"]) | length > 0' | tee /dev/stderr)

  [ "${has_tls_rules}" = "true" ]

  local has_psp_rules=$(helm template \
        -x templates/server-clusterrole.yaml  \
        --set 'server.enabled=true' \
        --set 'global.tls.enabled=true' \
        --set 'global.enablePodSecurityPolicies=true' \
        . | tee /dev/stderr |
        yq -r '.rules[] | select(.resources==["podsecuritypolicies"]) | length > 0' | tee /dev/stderr)

  [ "${has_psp_rules}" = "true" ]
}
