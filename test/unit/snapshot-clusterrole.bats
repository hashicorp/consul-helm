#!/usr/bin/env bats

load _helpers

@test "snapshot/ClusterRole: disabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-clusterrole.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}


@test "snapshot/ClusterRole: disabled with global.enabled=false" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-clusterrole.yaml  \
      --set 'global.enabled=false' \
      --set 'snapshot.enabled=-' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "snapshot/ClusterRole: can be enabled with global.enabled=false" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-clusterrole.yaml  \
      --set 'global.enabled=false' \
      --set 'snapshot.enabled="-"' \
      . | tee /dev/stderr |
      yq -s 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "snapshot/ClusterRole: disabled with snapshot.enabled=false" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-clusterrole.yaml  \
      --set 'snapshot.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "snapshot/ClusterRole: enabled with snapshot.enabled=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-clusterrole.yaml  \
      --set 'snapshot.enabled=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# global.enablePodSecurityPolicies

@test "snapshot/ClusterRole: allows podsecuritypolicies access with global.enablePodSecurityPolicies=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-clusterrole.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'global.enablePodSecurityPolicies=true' \
      . | tee /dev/stderr |
      yq -r '.rules[0].resources[0]' | tee /dev/stderr)
  [ "${actual}" = "podsecuritypolicies" ]
}

#--------------------------------------------------------------------
# global.bootstrapACLs

@test "snapshot/ClusterRole: allows secret access with global.bootsrapACLs=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-clusterrole.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'global.bootstrapACLs=true' \
      . | tee /dev/stderr |
      yq -r '.rules[0].resources[0]' | tee /dev/stderr)
  [ "${actual}" = "secrets" ]
}

@test "snapshot/ClusterRole: allows secret access with global.bootsrapACLs=true and global.enablePodSecurityPolicies=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-clusterrole.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'global.bootstrapACLs=true' \
      --set 'global.enablePodSecurityPolicies=true' \
      . | tee /dev/stderr |
      yq -r '.rules[1].resources[0]' | tee /dev/stderr)
  [ "${actual}" = "secrets" ]
}
