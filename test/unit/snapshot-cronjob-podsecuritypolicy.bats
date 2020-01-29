#!/usr/bin/env bats

load _helpers

@test "snapshot/PodSecurityPolicy: disabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob-podsecuritypolicy.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "snapshot/PodSecurityPolicy: disabled by default with snapshot enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob-podsecuritypolicy.yaml  \
      --set 'snapshot.enabled=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "snapshot/PodSecurityPolicy: disabled with snapshot disabled and global.enablePodSecurityPolicies=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob-podsecuritypolicy.yaml  \
      --set 'snapshot.enabled=false' \
      --set 'global.enablePodSecurityPolicies=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "snapshot/PodSecurityPolicy: enabled with snapshot enabled and global.enablePodSecurityPolicies=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob-podsecuritypolicy.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'global.enablePodSecurityPolicies=true' \
      . | tee /dev/stderr |
      yq -s 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}
