#!/usr/bin/env bats

load _helpers

@test "ingressGateways/Service: disabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-service.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "ingressGateways/Service: disabled with ingressGateways.enabled=true .service.enabled set to false through specific gateway overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-service.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.service.enabled=true' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].service.enabled=false' \
      . | tee /dev/stderr |
      yq -s '.[0] | length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "ingressGateways/Service: enabled by default with ingressGateways, connectInject and client.grpc enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-service.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      . | tee /dev/stderr |
      yq -s '.[0] | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Service: enabled with ingressGateways.enabled=true .service.enabled set through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-service.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.service.enabled=true' \
      . | tee /dev/stderr |
      yq -s '.[0] | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Service: enabled with ingressGateways.enabled=true .service.enabled set through specific gateway overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-service.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.service.enabled=false' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].service.enabled=true' \
      . | tee /dev/stderr |
      yq -s '.[0] | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# annotations

@test "ingressGateways/Service: no annotations by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-service.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.service.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].metadata.annotations' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "ingressGateways/Deployment: annotations can be set through defaults" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/ingress-gateways-service.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.service.annotations=key1: value1
key2: value2' \
      . | tee /dev/stderr |
      yq -s -r '.[0].metadata.annotations' | tee /dev/stderr)

  local actual=$(echo $object | yq '. | length' | tee /dev/stderr)
  [ "${actual}" = "2" ]

  local actual=$(echo $object | yq -r '.key1' | tee /dev/stderr)
  [ "${actual}" = "value1" ]

  local actual=$(echo $object | yq -r '.key2' | tee /dev/stderr)
  [ "${actual}" = "value2" ]
}

@test "ingressGateways/Service: annotations can be set through specific gateway" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/ingress-gateways-service.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].service.annotations=key1: value1
key2: value2' \
      . | tee /dev/stderr |
      yq -s -r '.[0].metadata.annotations' | tee /dev/stderr)

  local actual=$(echo $object | yq '. | length' | tee /dev/stderr)
  [ "${actual}" = "2" ]

  local actual=$(echo $object | yq -r '.key1' | tee /dev/stderr)
  [ "${actual}" = "value1" ]

  local actual=$(echo $object | yq -r '.key2' | tee /dev/stderr)
  [ "${actual}" = "value2" ]
}

@test "ingressGateways/Service: annotations can be set through defaults and specific gateway" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.annotations=defaultkey: defaultvalue' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].annotations=key1: value1
key2: value2' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.metadata.annotations' | tee /dev/stderr)

  local actual=$(echo $object | yq '. | length' | tee /dev/stderr)
  [ "${actual}" = "4" ]

  local actual=$(echo $object | yq -r '.defaultkey' | tee /dev/stderr)
  [ "${actual}" = "defaultvalue" ]

  local actual=$(echo $object | yq -r '.key1' | tee /dev/stderr)
  [ "${actual}" = "value1" ]

  local actual=$(echo $object | yq -r '.key2' | tee /dev/stderr)
  [ "${actual}" = "value2" ]
}

#--------------------------------------------------------------------
# port

@test "ingressGateways/Service: has default port" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-service.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.service.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.ports[0].port' | tee /dev/stderr)
  [ "${actual}" = "443" ]
}

@test "ingressGateways/Service: can set port through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-service.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.service.enabled=true' \
      --set 'ingressGateways.defaults.service.port=8443' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.ports[0].port' | tee /dev/stderr)
  [ "${actual}" = "8443" ]
}

@test "ingressGateways/Service: can set port through specific gateway, overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-service.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.service.enabled=true' \
      --set 'ingressGateways.defaults.service.port=8443' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].service.port=1234' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.ports[0].port' | tee /dev/stderr)
  [ "${actual}" = "1234" ]
}

#--------------------------------------------------------------------
# nodePort

@test "ingressGateways/Service: no nodePort by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-service.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.service.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.ports[0].nodePort' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "ingressGateways/Service: can set a nodePort through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-service.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.service.enabled=true' \
      --set 'ingressGateways.defaults.service.nodePort=8443' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.ports[0].nodePort' | tee /dev/stderr)
  [ "${actual}" = "8443" ]
}

@test "ingressGateways/Service: can set a nodePort through specific gateway overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-service.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.service.enabled=true' \
      --set 'ingressGateways.defaults.service.nodePort=8443' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].service.nodePort=1234' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.ports[0].nodePort' | tee /dev/stderr)
  [ "${actual}" = "1234" ]
}

#--------------------------------------------------------------------
# Service type

@test "ingressGateways/Service: defaults to type LoadBalancer" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-service.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.service.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.type' | tee /dev/stderr)
  [ "${actual}" = "LoadBalancer" ]
}

@test "ingressGateways/Service: can set type through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-service.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.service.enabled=true' \
      --set 'ingressGateways.defaults.service.type=ClusterIP' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.type' | tee /dev/stderr)
  [ "${actual}" = "ClusterIP" ]
}

@test "ingressGateways/Service: can set type through specific gateway overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-service.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.service.enabled=true' \
      --set 'ingressGateways.defaults.service.type=NodePort' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].service.type=ClusterIP' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.type' | tee /dev/stderr)
  [ "${actual}" = "ClusterIP" ]
}

#--------------------------------------------------------------------
# additionalSpec

@test "ingressGateways/Service: can add additionalSpec through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-service.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.service.enabled=true' \
      --set 'ingressGateways.defaults.service.additionalSpec=key: value' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.key' | tee /dev/stderr)
  [ "${actual}" = "value" ]
}

@test "ingressGateways/Service: can add additionalSpec through specific gateway overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-service.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.service.enabled=true' \
      --set 'ingressGateways.defaults.service.additionalSpec=key: value' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].service.additionalSpec=key2: value2' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.key2' | tee /dev/stderr)
  [ "${actual}" = "value2" ]
}
