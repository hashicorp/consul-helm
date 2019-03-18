#!/usr/bin/env bats

load _helpers

@test "client/DaemonSet: enabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "client/DaemonSet: enable with global.enabled false" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.enabled=false' \
      --set 'client.enabled=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "client/DaemonSet: disable with client.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'client.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "client/DaemonSet: disable with global.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "client/DaemonSet: image defaults to global.image" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.image=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].image' | tee /dev/stderr)
  [ "${actual}" = "foo" ]
}

@test "client/DaemonSet: image can be overridden with client.image" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.image=foo' \
      --set 'client.image=bar' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].image' | tee /dev/stderr)
  [ "${actual}" = "bar" ]
}

@test "client/DaemonSet: no updateStrategy when not updating" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.updateStrategy' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

#--------------------------------------------------------------------
# grpc

@test "client/DaemonSet: grpc is disabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | any(contains("grpc"))' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "client/DaemonSet: grpc can be enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'client.grpc=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | any(contains("grpc"))' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# resources

@test "client/DaemonSet: no resources defined by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].resources' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "client/DaemonSet: resources can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'client.resources=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].resources' | tee /dev/stderr)
  [ "${actual}" = "foo" ]
}

#--------------------------------------------------------------------
# extraVolumes

@test "client/DaemonSet: adds extra volume" {
  cd `chart_dir`

  # Test that it defines it
  local object=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'client.extraVolumes[0].type=configMap' \
      --set 'client.extraVolumes[0].name=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.volumes[] | select(.name == "userconfig-foo")' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.configMap.name' | tee /dev/stderr)
  [ "${actual}" = "foo" ]

  local actual=$(echo $object |
      yq -r '.configMap.secretName' | tee /dev/stderr)
  [ "${actual}" = "null" ]

  # Test that it mounts it
  local object=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'client.extraVolumes[0].type=configMap' \
      --set 'client.extraVolumes[0].name=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "userconfig-foo")' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.readOnly' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo $object |
      yq -r '.mountPath' | tee /dev/stderr)
  [ "${actual}" = "/consul/userconfig/foo" ]

  # Doesn't load it
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'client.extraVolumes[0].type=configMap' \
      --set 'client.extraVolumes[0].name=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].command | map(select(test("userconfig"))) | length' | tee /dev/stderr)
  [ "${actual}" = "0" ]
}

@test "client/DaemonSet: adds extra secret volume" {
  cd `chart_dir`

  # Test that it defines it
  local object=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'client.extraVolumes[0].type=secret' \
      --set 'client.extraVolumes[0].name=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.volumes[] | select(.name == "userconfig-foo")' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.secret.name' | tee /dev/stderr)
  [ "${actual}" = "null" ]

  local actual=$(echo $object |
      yq -r '.secret.secretName' | tee /dev/stderr)
  [ "${actual}" = "foo" ]

  # Test that it mounts it
  local object=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'client.extraVolumes[0].type=configMap' \
      --set 'client.extraVolumes[0].name=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "userconfig-foo")' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.readOnly' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo $object |
      yq -r '.mountPath' | tee /dev/stderr)
  [ "${actual}" = "/consul/userconfig/foo" ]

  # Doesn't load it
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'client.extraVolumes[0].type=configMap' \
      --set 'client.extraVolumes[0].name=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].command | map(select(test("userconfig"))) | length' | tee /dev/stderr)
  [ "${actual}" = "0" ]
}

@test "client/DaemonSet: adds loadable volume" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'client.extraVolumes[0].type=configMap' \
      --set 'client.extraVolumes[0].name=foo' \
      --set 'client.extraVolumes[0].load=true' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].command | map(select(test("/consul/userconfig/foo"))) | length' | tee /dev/stderr)
  [ "${actual}" = "1" ]
}

#--------------------------------------------------------------------
# priorityClassName

@test "client/DaemonSet: priorityClassName is not set by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      . | tee /dev/stderr |
      yq '.spec.template.spec.priorityClassName' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "client/DaemonSet: specified priorityClassName" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'client.priorityClassName=testing' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.priorityClassName' | tee /dev/stderr)
  [ "${actual}" = "testing" ]
}

#--------------------------------------------------------------------
# annotations

@test "client/DaemonSet: no annotations defined by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.template.metadata.annotations | del(."consul.hashicorp.com/connect-inject")' | tee /dev/stderr)
  [ "${actual}" = "{}" ]
}

@test "client/DaemonSet: annotations can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'client.annotations=foo: bar' \
      . | tee /dev/stderr |
      yq -r '.spec.template.metadata.annotations.foo' | tee /dev/stderr)
  [ "${actual}" = "bar" ]
}

#--------------------------------------------------------------------
# tolerations

@test "client/DaemonSet: tolerations not set by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      . | tee /dev/stderr |
      yq '.spec.template.spec | .tolerations? == null' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "client/DaemonSet: tolerations can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'client.tolerations=foobar' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.tolerations == "foobar"' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# TLS

@test "client/DaemonSet: no secret volumes when TLS is disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.tls.enabled=false' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.volumes[] | select(.secret)' | tee /dev/stderr)
  [ "${actual}" == "" ]
}

@test "client/DaemonSet: CA volume present when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.volumes[] | select(.name == "tls-ca-cert")' | tee /dev/stderr)
  [ "${actual}" != "" ]
}

@test "client/DaemonSet: client volume present when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.volumes[] | select(.name == "tls-client-cert")' | tee /dev/stderr)
  [ "${actual}" != "" ]
}

@test "client/DaemonSet: no volumes mounted when TLS is disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.tls.enabled=false' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].volumeMounts[] | select(.secret)' | tee /dev/stderr)
  [ "${actual}" == "" ]
}

@test "client/DaemonSet: CA volume mounted when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "tls-ca-cert")' | tee /dev/stderr)
  [ "${actual}" != "" ]
}

@test "client/DaemonSet: Client volume mounted when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "tls-client-cert")' | tee /dev/stderr)
  [ "${actual}" != "" ]
}

@test "client/DaemonSet: port 8500 is exposed when TLS is disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.tls.enabled=false' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].ports[] | select (.containerPort == 8500)' | tee /dev/stderr)
  [ "${actual}" != "" ]
}

@test "client/DaemonSet: port 8501 is not exposed when TLS is disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.tls.enabled=false' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].ports[] | select (.containerPort == 8501)' | tee /dev/stderr)
  [ "${actual}" == "" ]
}

@test "client/DaemonSet: port 8501 is exposed when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].ports[] | select (.containerPort == 8501)' | tee /dev/stderr)
  [ "${actual}" != "" ]
}

@test "client/DaemonSet: port 8500 is still exposed when httpsOnly is not enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.httpsOnly=false' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].ports[] | select (.containerPort == 8500)' | tee /dev/stderr)
  [ "${actual}" != "" ]
}

@test "client/DaemonSet: port 8500 is not exposed when httpsOnly is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.httpsOnly=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].ports[] | select (.containerPort == 8500)' | tee /dev/stderr)
  [ "${actual}" == "" ]
}

@test "client/DaemonSet: Readiness probe URL is http when TLS is disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.tls.enabled=false' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].readinessProbe.exec.command | join(" ") | contains("http://")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "client/DaemonSet: Readiness probe port is 8500 when TLS is disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.tls.enabled=false' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].readinessProbe.exec.command | join(" ") | contains(":8500")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "client/DaemonSet: Readiness probe URL is https when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].readinessProbe.exec.command | join(" ") | contains("https://")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "client/DaemonSet: Readiness probe port is 8501 when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].readinessProbe.exec.command | join(" ") | contains(":8501")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "client/DaemonSet: CA certificate is specified when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].readinessProbe.exec.command | join(" ") | contains("--cacert /consul/tls/ca/tls.crt")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "client/DaemonSet: client certificate is specified when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].readinessProbe.exec.command | join(" ") | contains("--cert /consul/tls/client/tls.crt")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "client/DaemonSet: client key is specified when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].readinessProbe.exec.command | join(" ") | contains("--key /consul/tls/client/tls.key")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "client/DaemonSet: HTTP is disabled in agent when httpsOnly is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/client-daemonset.yaml  \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.httpsOnly=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | join(" ") | contains("ports { http = -1 }")' | tee /dev/stderr)
