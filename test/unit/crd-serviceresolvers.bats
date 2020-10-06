#!/usr/bin/env bats

load _helpers

@test "serviceResolvers/CustomerResourceDefinition: disabled by default" {
  cd `chart_dir`
  assert_empty helm template \
      -s templates/crd-serviceresolvers.yaml  \
      .
}

@test "serviceResolvers/CustomerResourceDefinition: enabled with controller.enabled=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/crd-serviceresolvers.yaml  \
      --set 'controller.enabled=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}
