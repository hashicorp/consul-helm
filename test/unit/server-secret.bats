#!/usr/bin/env bats

load _helpers

#--------------------------------------------------------------------
# secret

@test "server/secret: enabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-secret.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/secret: enable with global.enabled false and server.enabled true" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-secret.yaml  \
      --set 'global.enabled=false' \
      --set 'server.enabled=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/secret: disable with server.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-secret.yaml  \
      --set 'server.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "server/secret: disable with global.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-secret.yaml  \
      --set 'global.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

#--------------------------------------------------------------------
# secret gossip encryption

@test "server/secret: gossip encryption not created in server Secret by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-secret.yaml  \
      . | tee /dev/stderr |
      yq '.data? == null' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/secret: gossip encryption created in server Secret when secret is provider" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-secret.yaml  \
      --set 'global.gossipEncryption.secret=foo' \
      . | tee /dev/stderr |
      yq '.data["gossip-key"] != ""' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

