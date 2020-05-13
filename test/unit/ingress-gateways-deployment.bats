#!/usr/bin/env bats

load _helpers

@test "ingressGateways/Deployment: disabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "ingressGateways/Deployment: enabled with ingressGateways, connectInject and client.grpc enabled, has default gateway name" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      . | tee /dev/stderr |
      yq -s '.[0]' | tee /dev/stderr)

  local actual=$(echo $object | yq '. | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo $object | yq -r '.metadata.name' | tee /dev/stderr)
  [ "${actual}" = "ingress-gateway" ]
}

#--------------------------------------------------------------------
# prerequisites

@test "ingressGateways/Deployment: fails if connectInject.enabled=false" {
  cd `chart_dir`
  run helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=false' \
      --set 'client.grpc=true' .
  [ "$status" -eq 1 ]
  [[ "$output" =~ "connectInject.enabled must be true" ]]
}

@test "ingressGateways/Deployment: fails if client.grpc=false" {
  cd `chart_dir`
  run helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'client.grpc=false' \
      --set 'connectInject.enabled=true' .
  [ "$status" -eq 1 ]
  [[ "$output" =~ "client.grpc must be true" ]]
}

@test "ingressGateways/Deployment: fails if global.enabled is false and clients are not explicitly enabled" {
  cd `chart_dir`
  run helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'client.grpc=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.enabled=false' .
  [ "$status" -eq 1 ]
  [[ "$output" =~ "clients must be enabled" ]]
}

@test "ingressGateways/Deployment: fails if global.enabled is true but clients are explicitly disabled" {
  cd `chart_dir`
  run helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'client.grpc=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.enabled=true' \
      --set 'client.enabled=false' .
  [ "$status" -eq 1 ]
  [[ "$output" =~ "clients must be enabled" ]]
}

#--------------------------------------------------------------------
# envoyImage

@test "ingressGateways/Deployment: envoy image has default global value" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0].image' | tee /dev/stderr)
  [ "${actual}" = "envoyproxy/envoy:v1.13.0" ]
}

@test "ingressGateways/Deployment: envoy image can be set using the global value" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'global.imageEnvoy=new/image' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0].image' | tee /dev/stderr)
  [ "${actual}" = "new/image" ]
}

#--------------------------------------------------------------------
# global.tls.enabled

@test "ingressGateways/Deployment: sets TLS flags when global.tls.enabled" {
  cd `chart_dir`
  local env=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0].env[]' | tee /dev/stderr)

  local actual=$(echo $env | jq -r '. | select(.name == "CONSUL_HTTP_ADDR") | .value' | tee /dev/stderr)
  [ "${actual}" = 'https://$(HOST_IP):8501' ]

  local actual=$(echo $env | jq -r '. | select(.name == "CONSUL_GRPC_ADDR") | .value' | tee /dev/stderr)
  [ "${actual}" = 'https://$(HOST_IP):8502' ]

  local actual=$(echo $env | jq -r '. | select(.name == "CONSUL_CACERT") | .value' | tee /dev/stderr)
  [ "${actual}" = "/consul/tls/ca/tls.crt" ]
}

@test "ingressGateways/Deployment: can overwrite CA secret with the provided one" {
  cd `chart_dir`
  local ca_cert_volume=$(helm template \
      -x templates/client-snapshot-agent-deployment.yaml  \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.caCert.secretName=foo-ca-cert' \
      --set 'global.tls.caCert.secretKey=key' \
      --set 'global.tls.caKey.secretName=foo-ca-key' \
      --set 'global.tls.caKey.secretKey=key' \
      . | tee /dev/stderr |
      yq -s '.[0].spec.template.spec.volumes[] | select(.name=="consul-ca-cert")' | tee /dev/stderr)

  # check that the provided ca cert secret is attached as a volume
  local actual=$(echo $ca_cert_volume | yq -r '.secret.secretName' | tee /dev/stderr)
  [ "${actual}" = "foo-ca-cert" ]

  # check that the volume uses the provided secret key
  local actual=$(echo $ca_cert_volume | yq -r '.secret.items[0].key' | tee /dev/stderr)
  [ "${actual}" = "key" ]
}

#--------------------------------------------------------------------
# global.tls.enableAutoEncrypt

@test "ingressGateways/Deployment: consul-auto-encrypt-ca-cert volume is added when TLS with auto-encrypt is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.enableAutoEncrypt=true' \
      . | tee /dev/stderr |
      yq -s '.[0].spec.template.spec.volumes[] | select(.name == "consul-auto-encrypt-ca-cert") | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: consul-auto-encrypt-ca-cert volumeMount is added when TLS with auto-encrypt is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.enableAutoEncrypt=true' \
      . | tee /dev/stderr |
      yq -s '.[0].spec.template.spec.containers[0].volumeMounts[] | select(.name == "consul-auto-encrypt-ca-cert") | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: get-auto-encrypt-client-ca init container is created when TLS with auto-encrypt is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.enableAutoEncrypt=true' \
      . | tee /dev/stderr |
      yq -s '.[0].spec.template.spec.initContainers[] | select(.name == "get-auto-encrypt-client-ca") | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: consul-ca-cert volume is not added if externalServers.enabled=true and externalServers.useSystemRoots=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.enableAutoEncrypt=true' \
      --set 'externalServers.enabled=true' \
      --set 'externalServers.hosts[0]=foo.com' \
      --set 'externalServers.useSystemRoots=true' \
      . | tee /dev/stderr |
      yq -s '.[0].spec.template.spec.volumes[] | select(.name == "consul-ca-cert")' | tee /dev/stderr)
  [ "${actual}" = "" ]
}

#--------------------------------------------------------------------
# replicas

@test "ingressGateways/Deployment: replicas defaults to 2" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.replicas' | tee /dev/stderr)
  [ "${actual}" = "2" ]
}

@test "ingressGateways/Deployment: replicas can be set through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.replicas=3' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.replicas' | tee /dev/stderr)
  [ "${actual}" = "3" ]
}

@test "ingressGateways/Deployment: replicas can be set through specific gateway, overrides default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.replicas=3' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].replicas=12' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.replicas' | tee /dev/stderr)
  [ "${actual}" = "12" ]
}

#--------------------------------------------------------------------
# hostPort

@test "ingressGateways/Deployment: no hostPort by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0].ports[0].hostPort' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "ingressGateways/Deployment: can set a hostPort through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.hostPort=443' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0].ports[0].hostPort' | tee /dev/stderr)
  [ "${actual}" = "443" ]
}

@test "ingressGateways/Deployment: can set a hostPort through specific gateway, overrides default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.hostPort=443' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].hostPort=1234' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0].ports[0].hostPort' | tee /dev/stderr)
  [ "${actual}" = "1234" ]
}

#--------------------------------------------------------------------
# resources

@test "ingressGateways/Deployment: resources has default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0].resources' | tee /dev/stderr)

  [ $(echo "${actual}" | yq -r '.requests.memory') = "128Mi" ]
  [ $(echo "${actual}" | yq -r '.requests.cpu') = "250m" ]
  [ $(echo "${actual}" | yq -r '.limits.memory') = "256Mi" ]
  [ $(echo "${actual}" | yq -r '.limits.cpu') = "500m" ]
}

@test "ingressGateways/Deployment: resources can be set through defaults" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.resources.requests.memory=memory' \
      --set 'ingressGateways.defaults.resources.requests.cpu=cpu' \
      --set 'ingressGateways.defaults.resources.limits.memory=memory2' \
      --set 'ingressGateways.defaults.resources.limits.cpu=cpu2' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0].resources' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.requests.memory' | tee /dev/stderr)
  [ "${actual}" = "memory" ]

  local actual=$(echo $object | yq -r '.requests.cpu' | tee /dev/stderr)
  [ "${actual}" = "cpu" ]

  local actual=$(echo $object | yq -r '.limits.memory' | tee /dev/stderr)
  [ "${actual}" = "memory2" ]

  local actual=$(echo $object | yq -r '.limits.cpu' | tee /dev/stderr)
  [ "${actual}" = "cpu2" ]
}

@test "ingressGateways/Deployment: resources can be set through specific gateway, overriding defaults" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.resources.requests.memory=memory' \
      --set 'ingressGateways.defaults.resources.requests.cpu=cpu' \
      --set 'ingressGateways.defaults.resources.limits.memory=memory2' \
      --set 'ingressGateways.defaults.resources.limits.cpu=cpu2' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].resources.requests.memory=gwmemory' \
      --set 'ingressGateways.gateways[0].resources.requests.cpu=gwcpu' \
      --set 'ingressGateways.gateways[0].resources.limits.memory=gwmemory2' \
      --set 'ingressGateways.gateways[0].resources.limits.cpu=gwcpu2' \
      . | tee /dev/stderr |
      yq -s '.[0].spec.template.spec.containers[0].resources' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.requests.memory' | tee /dev/stderr)
  [ "${actual}" = "gwmemory" ]

  local actual=$(echo $object | yq -r '.requests.cpu' | tee /dev/stderr)
  [ "${actual}" = "gwcpu" ]

  local actual=$(echo $object | yq -r '.limits.memory' | tee /dev/stderr)
  [ "${actual}" = "gwmemory2" ]

  local actual=$(echo $object | yq -r '.limits.cpu' | tee /dev/stderr)
  [ "${actual}" = "gwcpu2" ]
}

#--------------------------------------------------------------------
# affinity

@test "ingressGateways/Deployment: affinity defaults to one per node" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey' | tee /dev/stderr)
  [ "${actual}" = "kubernetes.io/hostname" ]
}

@test "ingressGateways/Deployment: affinity can be set through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.affinity=key: value' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.affinity.key' | tee /dev/stderr)
  [ "${actual}" = "value" ]
}

@test "ingressGateways/Deployment: affinity can be set through specific gateway, overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.affinity=key: value' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].affinity=key2: value2' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.affinity.key2' | tee /dev/stderr)
  [ "${actual}" = "value2" ]
}

#--------------------------------------------------------------------
# tolerations

@test "ingressGateways/Deployment: no tolerations by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.tolerations' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "ingressGateways/Deployment: tolerations can be set through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.tolerations[0].key=value' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.tolerations[0].key' | tee /dev/stderr)
  [ "${actual}" = "value" ]
}

@test "ingressGateways/Deployment: tolerations can be set through specific gateway, overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.tolerations[0].key=value' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].tolerations[0].key=value2' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.tolerations[0].key' | tee /dev/stderr)
  [ "${actual}" = "value2" ]
}

#--------------------------------------------------------------------
# nodeSelector

@test "ingressGateways/Deployment: no nodeSelector by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.nodeSelector' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "ingressGateways/Deployment: can set a nodeSelector through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.nodeSelector=key: value' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.nodeSelector.key' | tee /dev/stderr)
  [ "${actual}" = "value" ]
}

@test "ingressGateways/Deployment: can set a nodeSelector through specific gateway, overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.nodeSelector=key: value' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].nodeSelector=key2: value2' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.nodeSelector.key2' | tee /dev/stderr)
  [ "${actual}" = "value2" ]
}

#--------------------------------------------------------------------
# priorityClassName

@test "ingressGateways/Deployment: no priorityClassName by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.priorityClassName' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "ingressGateways/Deployment: can set a priorityClassName through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.priorityClassName=name' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.priorityClassName' | tee /dev/stderr)
  [ "${actual}" = "name" ]
}

@test "ingressGateways/Deployment: can set a priorityClassName per gateway overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.priorityClassName=name' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].priorityClassName=priority' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.priorityClassName' | tee /dev/stderr)
  [ "${actual}" = "priority" ]
}

#--------------------------------------------------------------------
# annotations

@test "ingressGateways/Deployment: no extra annotations by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.metadata.annotations | length' | tee /dev/stderr)
  [ "${actual}" = "1" ]
}

@test "ingressGateways/Deployment: extra annotations can be set through defaults" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.defaults.annotations=key1: value1
key2: value2' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.metadata.annotations' | tee /dev/stderr)

  local actual=$(echo $object | yq '. | length' | tee /dev/stderr)
  [ "${actual}" = "3" ]

  local actual=$(echo $object | yq -r '.key1' | tee /dev/stderr)
  [ "${actual}" = "value1" ]

  local actual=$(echo $object | yq -r '.key2' | tee /dev/stderr)
  [ "${actual}" = "value2" ]
}

@test "ingressGateways/Deployment: extra annotations can be set through specific gateway" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].annotations=key1: value1
key2: value2' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.metadata.annotations' | tee /dev/stderr)

  local actual=$(echo $object | yq '. | length' | tee /dev/stderr)
  [ "${actual}" = "3" ]

  local actual=$(echo $object | yq -r '.key1' | tee /dev/stderr)
  [ "${actual}" = "value1" ]

  local actual=$(echo $object | yq -r '.key2' | tee /dev/stderr)
  [ "${actual}" = "value2" ]
}

@test "ingressGateways/Deployment: extra annotations can be set through defaults and specific gateway" {
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
# service-init init container

@test "ingressGateways/Deployment: service-init init container" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='consul-k8s service-address \
  -k8s-namespace=default \
  -name=ingress-gateway \
  -output-file=/tmp/address.txt
WAN_ADDR="$(cat /tmp/address.txt)"
WAN_PORT="443"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: service-init init container with acls.manageSystemACLs=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.acls.manageSystemACLs=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='consul-k8s acl-init \
  -secret-name="release-name-consul-ingress-gateway-ingress-gateway-acl-token" \
  -k8s-namespace=default \
  -token-sink-file=/consul/service/acl-token

consul-k8s service-address \
  -k8s-namespace=default \
  -name=ingress-gateway \
  -output-file=/tmp/address.txt
WAN_ADDR="$(cat /tmp/address.txt)"
WAN_PORT="443"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  -token-file=/consul/service/acl-token \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: service-init init container with global.federation.enabled=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.federation.enabled=true' \
      --set 'global.tls.enabled=true' \
      --set 'meshGateway.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='consul-k8s service-address \
  -k8s-namespace=default \
  -name=ingress-gateway \
  -output-file=/tmp/address.txt
WAN_ADDR="$(cat /tmp/address.txt)"
WAN_PORT="443"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: service-init init container wanAddress.port can be changed through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.wanAddress.source=NodeIP' \
      --set 'ingressGateways.defaults.wanAddress.port=9999' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='WAN_ADDR="${HOST_IP}"
WAN_PORT="9999"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: service-init init container wanAddress.port can be changed through specific gateway overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.wanAddress.source=NodeIP' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].wanAddress.port=9999' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='WAN_ADDR="${HOST_IP}"
WAN_PORT="9999"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: service-init init container wanAddress.source=NodeIP through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.wanAddress.source=NodeIP' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='WAN_ADDR="${HOST_IP}"
WAN_PORT="443"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: service-init init container wanAddress.source=NodeIP through specific gateway overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.wanAddress.source=Service' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].wanAddress.source=NodeIP' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='WAN_ADDR="${HOST_IP}"
WAN_PORT="443"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: service-init init container wanAddress.source=NodeName through defaults" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.wanAddress.source=NodeName' \
      . | tee /dev/stderr |
      yq -s '.[0]')

  local actual=$(echo "$object" |
      yq -r '.spec.template.spec.containers[0].env | map(select(.name == "NODE_NAME")) | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo "$object" |
      yq -r '.spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='WAN_ADDR="${NODE_NAME}"
WAN_PORT="443"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: service-init init container wanAddress.source=NodeName through specific gateway overriding defaults" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.wanAddress.source=Service' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].wanAddress.source=NodeName' \
      . | tee /dev/stderr |
      yq -s '.[0]')

  local actual=$(echo "$object" |
      yq -r '.spec.template.spec.containers[0].env | map(select(.name == "NODE_NAME")) | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo "$object" |
      yq -r '.spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='WAN_ADDR="${NODE_NAME}"
WAN_PORT="443"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: service-init init container wanAddress.source=Static fails if wanAddress.static is empty in defaults" {
  cd `chart_dir`
  run helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.wanAddress.source=Static' \
      --set 'ingressGateways.defaults.wanAddress.static=' \
      .

  [ "$status" -eq 1 ]
  [[ "$output" =~ "if ingressGateways .wanAddress.source=Static then ingressGateways .wanAddress.static cannot be empty and must be set in either the defaults or in the gateway definition" ]]
}

@test "ingressGateways/Deployment: service-init init container wanAddress.source=Static fails if wanAddress.static is empty in specific gateway" {
  cd `chart_dir`
  run helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.wanAddress.source=Static' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].wanAddress.static=' \
      .

  [ "$status" -eq 1 ]
  [[ "$output" =~ "if ingressGateways .wanAddress.source=Static then ingressGateways .wanAddress.static cannot be empty and must be set in either the defaults or in the gateway definition" ]]
}

@test "ingressGateways/Deployment: service-init init container wanAddress.source=Static through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.wanAddress.source=Static' \
      --set 'ingressGateways.defaults.wanAddress.static=example.com' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='WAN_ADDR="example.com"
WAN_PORT="443"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: service-init init container wanAddress.source=Static through specific gateway, overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.wanAddress.source=Service' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].wanAddress.source=Static' \
      --set 'ingressGateways.gateways[0].wanAddress.static=example.com' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='WAN_ADDR="example.com"
WAN_PORT="443"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: service-init init container wanAddress.source=Service fails if defaults service.enable is false" {
  cd `chart_dir`
  run helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.wanAddress.source=Service' \
      --set 'ingressGateways.defaults.service.enabled=false' \
      .

  [ "$status" -eq 1 ]
  [[ "$output" =~ "if ingressGateways .wanAddress.source=Service then ingressGateways .service.enabled must be set to true in either the defaults or in the gateway definition" ]]
}

@test "ingressGateways/Deployment: service-init init container wanAddress.source=Service fails if specific gateway service.enable is false, overriding defaults" {
  cd `chart_dir`
  run helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.wanAddress.source=Service' \
      --set 'ingressGateways.defaults.service.enabled=true' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].service.enabled=false' \
      .

  [ "$status" -eq 1 ]
  [[ "$output" =~ "if ingressGateways .wanAddress.source=Service then ingressGateways .service.enabled must be set to true in either the defaults or in the gateway definition" ]]
}

@test "ingressGateways/Deployment: service-init init container wanAddress.source=Service, type=LoadBalancer through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.wanAddress.source=Service' \
      --set 'ingressGateways.defaults.wanAddress.port=ignored' \
      --set 'ingressGateways.defaults.service.enabled=true' \
      --set 'ingressGateways.defaults.service.type=LoadBalancer' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='consul-k8s service-address \
  -k8s-namespace=default \
  -name=ingress-gateway \
  -output-file=/tmp/address.txt
WAN_ADDR="$(cat /tmp/address.txt)"
WAN_PORT="443"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: service-init init container wanAddress.source=Service, type=LoadBalancer through specific gateway, overrides defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.wanAddress.source=Static' \
      --set 'ingressGateways.defaults.wanAddress.port=ignored' \
      --set 'ingressGateways.defaults.service.enabled=false' \
      --set 'ingressGateways.defaults.service.type=NodePort' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].wanAddress.source=Service' \
      --set 'ingressGateways.gateways[0].wanAddress.port=ignored' \
      --set 'ingressGateways.gateways[0].service.enabled=true' \
      --set 'ingressGateways.gateways[0].service.type=LoadBalancer' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='consul-k8s service-address \
  -k8s-namespace=default \
  -name=ingress-gateway \
  -output-file=/tmp/address.txt
WAN_ADDR="$(cat /tmp/address.txt)"
WAN_PORT="443"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: service-init init container wanAddress.source=Service, type=NodePort through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.wanAddress.source=Service' \
      --set 'ingressGateways.defaults.service.enabled=true' \
      --set 'ingressGateways.defaults.service.nodePort=9999' \
      --set 'ingressGateways.defaults.service.type=NodePort' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='WAN_ADDR="${HOST_IP}"
WAN_PORT="9999"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: service-init init container wanAddress.source=Service, type=NodePort through specific gateway, overrides default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.wanAddress.source=Service' \
      --set 'ingressGateways.defaults.service.enabled=true' \
      --set 'ingressGateways.defaults.service.nodePort=9999' \
      --set 'ingressGateways.defaults.service.type=NodePort' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.defaults.service.nodePort=1234' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='WAN_ADDR="${HOST_IP}"
WAN_PORT="1234"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: service-init init container wanAddress.source=Service, type=NodePort fails if service.nodePort is null" {
  cd `chart_dir`
  run helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.rpc=true' \
      --set 'ingressGateways.defaults.wanAddress.source=Service' \
      --set 'ingressGateways.defaults.service.enabled=true' \
      --set 'ingressGateways.defaults.service.type=NodePort' \
      .

  [ "$status" -eq 1 ]
  [[ "$output" =~ "if ingressGateways .wanAddress.source=Service and ingressGateways .service.type=NodePort, ingressGateways .service.nodePort must be set in either the defaults or in the gateway definition" ]]
}

@test "ingressGateways/Deployment: service-init init container wanAddress.source=Service, type=ClusterIP through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.rpc=true' \
      --set 'ingressGateways.defaults.wanAddress.source=Service' \
      --set 'ingressGateways.defaults.wanAddress.port=ignored' \
      --set 'ingressGateways.defaults.service.enabled=true' \
      --set 'ingressGateways.defaults.service.type=ClusterIP' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='consul-k8s service-address \
  -k8s-namespace=default \
  -name=ingress-gateway \
  -output-file=/tmp/address.txt
WAN_ADDR="$(cat /tmp/address.txt)"
WAN_PORT="443"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: service-init init container wanAddress.source=Service, type=ClusterIP through specific gateway, overrides defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.rpc=true' \
      --set 'ingressGateways.defaults.wanAddress.source=Static' \
      --set 'ingressGateways.defaults.wanAddress.port=1234' \
      --set 'ingressGateways.defaults.service.enabled=false' \
      --set 'ingressGateways.defaults.service.type=NodePort' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].wanAddress.source=Service' \
      --set 'ingressGateways.gateways[0].wanAddress.port=ignored' \
      --set 'ingressGateways.gateways[0].service.enabled=true' \
      --set 'ingressGateways.gateways[0].service.type=ClusterIP' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='consul-k8s service-address \
  -k8s-namespace=default \
  -name=ingress-gateway \
  -output-file=/tmp/address.txt
WAN_ADDR="$(cat /tmp/address.txt)"
WAN_PORT="443"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: service-init init container gateway name can be changed" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.gateways[0].name=new-name' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='consul-k8s service-address \
  -k8s-namespace=default \
  -name=new-name \
  -output-file=/tmp/address.txt
WAN_ADDR="$(cat /tmp/address.txt)"
WAN_PORT="443"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "new-name"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: service-init init container gateway namespace can be specified through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'global.enableConsulNamespaces=true' \
      --set 'ingressGateways.defaults.consulNamespace=namespace' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='consul-k8s service-address \
  -k8s-namespace=default \
  -name=ingress-gateway \
  -output-file=/tmp/address.txt
WAN_ADDR="$(cat /tmp/address.txt)"
WAN_PORT="443"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  namespace = "namespace"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: service-init init container gateway namespace can be specified through specific gateway overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'global.enableConsulNamespaces=true' \
      --set 'ingressGateways.defaults.consulNamespace=namespace' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].consulNamespace=new-namespace' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "service-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='consul-k8s service-address \
  -k8s-namespace=default \
  -name=ingress-gateway \
  -output-file=/tmp/address.txt
WAN_ADDR="$(cat /tmp/address.txt)"
WAN_PORT="443"

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  namespace = "new-namespace"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 8443
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:8443"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

#--------------------------------------------------------------------
# multiple gateways

@test "ingressGateways/Deployment: multiple gateways" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/ingress-gateways-role.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'client.grpc=true' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[1].name=gateway2' \
      . | tee /dev/stderr |
      yq -s -r '.' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.[0].metadata.name' | tee /dev/stderr)
  [ "${actual}" = "gateway1" ]

  local actual=$(echo $object | yq -r '.[1].metadata.name' | tee /dev/stderr)
  [ "${actual}" = "gateway2" ]

  local actual=$(echo $object | yq '.[0] | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo $object | yq '.[1] | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo $object | yq '.[2] | length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}
