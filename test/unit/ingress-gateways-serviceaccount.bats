#!/usr/bin/env bats

load _helpers

@test "ingressGateways/ServiceAccount: disabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-serviceaccount.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "ingressGateways/ServiceAccount: enabled with ingressGateways, connectInject and client.grpc enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-serviceaccount.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      . | tee /dev/stderr |
      yq -s 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# global.imagePullSecrets

@test "ingressGateways/ServiceAccount: can set image pull secrets" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/ingress-gateways-serviceaccount.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.imagePullSecrets[0].name=my-secret' \
      --set 'global.imagePullSecrets[1].name=my-secret2' \
      . | tee /dev/stderr)

  local actual=$(echo "$object" |
      yq -s -r '.[0].imagePullSecrets[0].name' | tee /dev/stderr)
  [ "${actual}" = "my-secret" ]

  local actual=$(echo "$object" |
      yq -s -r '.[0].imagePullSecrets[1].name' | tee /dev/stderr)
  [ "${actual}" = "my-secret2" ]
}

#--------------------------------------------------------------------
# multiple gateways

@test "ingressGateways/ServiceAccount: multiple gateways" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/ingress-gateways-serviceaccount.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[1].name=gateway2' \
      . | tee /dev/stderr)

  local actual=$(echo "$object" |
      yq -s -r '.[0] | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo "$object" |
      yq -s -r '.[1] | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo "$object" |
      yq -s -r '.[2] | length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}
