#!/usr/bin/env bats

load _helpers

@test "serverACLInit/PodSecurityPolicy: disabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-acl-init-podsecuritypolicy.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "serverACLInit/PodSecurityPolicy: disabled with global.acls.manageSystemACLs=true and global.enablePodSecurityPolicies=false" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-acl-init-podsecuritypolicy.yaml  \
      --set 'global.acls.manageSystemACLs=true' \
      --set 'global.enablePodSecurityPolicies=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "serverACLInit/PodSecurityPolicy: enabled with global.acls.manageSystemACLs=true and global.enablePodSecurityPolicies=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-acl-init-podsecuritypolicy.yaml  \
      --set 'global.acls.manageSystemACLs=true' \
      --set 'global.enablePodSecurityPolicies=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "serverACLInit/PodSecurityPolicy: enabled with externalServers.enabled=true and global.acls.manageSystemACLs=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-acl-init-podsecuritypolicy.yaml  \
      --set 'global.acls.manageSystemACLs=true' \
      --set 'global.enablePodSecurityPolicies=true' \
      --set 'externalServers.enabled=true' \
      --set 'externalServers.https.address=foo.com' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}