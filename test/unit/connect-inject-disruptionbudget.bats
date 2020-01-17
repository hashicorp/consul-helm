#!/usr/bin/env bats

load _helpers

@test "connectInject/DisruptionBudget: enabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/connect-inject-disruptionbudget.yaml  \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "connectInject/DisruptionBudget: enabled with global.enabled=false and client.enabled=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/connect-inject-disruptionbudget.yaml  \
      --set 'global.enabled=false' \
      --set 'client.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "connectInject/DisruptionBudget: disabled with connectInject.enabled=false" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/connect-inject-disruptionbudget.yaml  \
      --set 'connectInject.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "connectInject/DisruptionBudget: disabled with connectInject.disruptionBudget.enabled=false" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/connect-inject-disruptionbudget.yaml  \
      --set 'connectInject.enabled=true' \
      --set 'connectInject.disruptionBudget.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "connectInject/DisruptionBudget: disabled with global.enabled=false" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/connect-inject-disruptionbudget.yaml  \
      --set 'global.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "connectInject/DisruptionBudget: disabled when connectInject.replicas=1" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/connect-inject-disruptionbudget.yaml  \
      --set 'connectInject.enabled=true' \
      --set 'connectInject.replicas=1' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

#--------------------------------------------------------------------
# minUnavailable

@test "connectInject/DisruptionBudget: minAvailable default to 1" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/connect-inject-disruptionbudget.yaml  \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.minAvailable' | tee /dev/stderr)
  [ "${actual}" = "1" ]
}

@test "connectInject/DisruptionBudget: minAvailable can be overridden" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/connect-inject-disruptionbudget.yaml  \
      --set 'connectInject.enabled=true' \
      --set 'connectInject.replicas=3' \
      --set 'connectInject.disruptionBudget.minAvailable=2' \
      . | tee /dev/stderr |
      yq '.spec.minAvailable' | tee /dev/stderr)
  [ "${actual}" = "2" ]
}
