#!/usr/bin/env bats

load _helpers

@test "snapshot/CronJob: disabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "snapshot/CronJob: enable with global.enabled false" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'global.enabled=false' \
      --set 'snapshot.enabled=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "snapshot/CronJob: disable with snapshot.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "snapshot/CronJob: disable with global.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'global.enabled=false' \
      --set 'snapshot.enabled=-' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "snapshot/CronJob: image defaults to global.imageSnapshot" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'global.imageSnapshot=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.jobTemplate.spec.template.spec.containers[0].image' | tee /dev/stderr)
  [ "${actual}" = "foo" ]
}

@test "snapshot/CronJob: image can be overridden with snapshot.image" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'global.imageSnapshot=foo' \
      --set 'snapshot.image=bar' \
      . | tee /dev/stderr |
      yq -r '.spec.jobTemplate.spec.template.spec.containers[0].image' | tee /dev/stderr)
  [ "${actual}" = "bar" ]
}

#--------------------------------------------------------------------
# concurrencyPolicy

@test "snapshot/CronJob: concurrencyPolicy Forbid by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.concurrencyPolicy == "Forbid"' | tee /dev/stderr)

  [ "${actual}" = "true" ]
}

@test "snapshot/CronJob: concurrencyPolicy can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.concurrencyPolicy=Replace' \
      . | tee /dev/stderr |
      yq -r '.spec.concurrencyPolicy == "Replace"' | tee /dev/stderr)

  [ "${actual}" = "true" ]
}


#--------------------------------------------------------------------
# jobHistory

@test "snapshot/CronJob: failedJobsHistoryLimit is 3 by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.failedJobsHistoryLimit == 3' | tee /dev/stderr)

  [ "${actual}" = "true" ]
}

@test "snapshot/CronJob: failedJobsHistoryLimit can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.failedJobsHistoryLimit=1' \
      . | tee /dev/stderr |
      yq -r '.spec.failedJobsHistoryLimit == 1' | tee /dev/stderr)

  [ "${actual}" = "true" ]
}

@test "snapshot/CronJob: successfulJobsHistoryLimit is 3 by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.successfulJobsHistoryLimit == 3' | tee /dev/stderr)

  [ "${actual}" = "true" ]
}

@test "snapshot/CronJob: successfulJobsHistoryLimit can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.successfulJobsHistoryLimit=1' \
      . | tee /dev/stderr |
      yq -r '.spec.successfulJobsHistoryLimit == 1' | tee /dev/stderr)

  [ "${actual}" = "true" ]
}


#--------------------------------------------------------------------
# schedule

@test "snapshot/CronJob: by default schedule is set to every 5 minutes" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.schedule == "*/5 * * * *"' | tee /dev/stderr)

  [ "${actual}" = "true" ]
}

@test "snapshot/CronJob: schedule can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set "snapshot.schedule=*/2 * * * *" \
      . | tee /dev/stderr |
      yq -r '.spec.schedule == "*/2 * * * *"' | tee /dev/stderr)

  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# s3 upload

@test "snapshot/CronJob: renders script to upload to s3 if you set snapshot.s3.bucket" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.s3.bucket=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.jobTemplate.spec.template.spec.containers[0].command | any(contains("BUCKET=\"foo\""))' | tee /dev/stderr)

  [ "${actual}" = "true" ]
}

@test "snapshot/CronJob: renders s3 upload script with endpoint" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.s3.bucket=foo' \
      --set 'snapshot.s3.endpoint=foo.com' \
      . | tee /dev/stderr |
      yq -r '.spec.jobTemplate.spec.template.spec.containers[0].command | any(contains("--endpoint \"foo.com\""))' | tee /dev/stderr)

  [ "${actual}" = "true" ]
}

@test "snapshot/CronJob: will define AWS_DEFAULT_REGION in snapshot script" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.s3.bucket=foo' \
      --set 'snapshot.s3.region=us-east-1' \
      . | tee /dev/stderr |
      yq -r '.spec.jobTemplate.spec.template.spec.containers[0].command | any(contains(": \"${AWS_DEFAULT_REGION:=us-east-1}\""))' | tee /dev/stderr)

  [ "${actual}" = "true" ]
}

@test "snapshot/CronJob: renders s3 upload script with access_key" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.s3.bucket=foo' \
      --set 'snapshot.s3.access_key=bar' \
      . | tee /dev/stderr |
      yq -r '.spec.jobTemplate.spec.template.spec.containers[0].command | any(contains(": \"${AWS_ACCESS_KEY_ID:=bar}\""))' | tee /dev/stderr)

  [ "${actual}" = "true" ]
}
#--------------------------------------------------------------------
# allow_stale

@test "snapshot/CronJob: will allow stale snapshots to be made" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.allow_stale=true' \
      . | tee /dev/stderr |
      yq -r '.spec.jobTemplate.spec.template.spec.containers[0].command | any(contains("&stale=true"))' | tee /dev/stderr)

  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# backup_retention

@test "snapshot/CronJob: will not cleanup up backups if backup_retention isn't set" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.backup_retention=null' \
      . | tee /dev/stderr |
      yq -r '.spec.jobTemplate.spec.template.spec.containers[0].command | any(contains("-mtime"))' | tee /dev/stderr)

  [ "${actual}" = "false" ]
}

@test "snapshot/CronJob: backup_retention value will be used to delete old backups" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.backup_retention=20' \
      . | tee /dev/stderr |
      yq -r '.spec.jobTemplate.spec.template.spec.containers[0].command | any(contains("-mtime +20"))' | tee /dev/stderr)

  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# resources

@test "snapshot/CronJob: no resources defined by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.jobTemplate.spec.template.spec.containers[0].resources' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "snapshot/CronJob: resources can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.resources=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.jobTemplate.spec.template.spec.containers[0].resources' | tee /dev/stderr)
  [ "${actual}" = "foo" ]
}

#--------------------------------------------------------------------
# nodeSelector

@test "snapshot/CronJob: nodeSelector is not set by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.jobTemplate.spec.nodeSelector' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "snapshot/CronJob: specified nodeSelector" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.nodeSelector=testing' \
      . | tee /dev/stderr |
      yq -r '.spec.jobTemplate.spec.template.spec.nodeSelector' | tee /dev/stderr)
  [ "${actual}" = "testing" ]
}

#--------------------------------------------------------------------
# affinity

@test "snapshot/CronJob: affinity not set by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.jobTemplate.spec.template.spec | .affinity? == null' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "snapshot/CronJob: specified affinity" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.affinity=foobar' \
      --set 'snapshot.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.jobTemplate.spec.template.spec | .affinity == "foobar"' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# annotations

@test "snapshot/CronJob: no annotations defined by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.jobTemplate.spec.template.metadata.annotations | del(."consul.hashicorp.com/connect-inject")' | tee /dev/stderr)
  [ "${actual}" = "{}" ]
}

@test "snapshot/CronJob: annotations can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.annotations=foo: bar' \
      --set 'snapshot.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.jobTemplate.spec.template.metadata.annotations.foo' | tee /dev/stderr)
  [ "${actual}" = "bar" ]
}

#--------------------------------------------------------------------
# tolerations

@test "snapshot/CronJob: tolerations not set by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.jobTemplate.spec.template.spec | .tolerations? == null' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "snapshot/CronJob: tolerations can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.tolerations=foobar' \
      . | tee /dev/stderr |
      yq '.spec.jobTemplate.spec.template.spec.tolerations == "foobar"' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# pvc

@test "snapshot/CronJob: uses an existing pvc if set" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.storage.enabled=true' \
      --set 'snapshot.storage.existingClaim=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.jobTemplate.spec.template.spec.volumes[] | select(.name == "snapshot")' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.persistentVolumeClaim.claimName' | tee /dev/stderr)
  [ "${actual}" = "foo" ]
}

@test "snapshot/CronJob: uses a newly created pvc if storage is enabled" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.storage.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.jobTemplate.spec.template.spec.volumes[] | select(.name == "snapshot")' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.persistentVolumeClaim.claimName' | tee /dev/stderr)
  [ "${actual}" = "release-name-consul-snapshot" ]
}

@test "snapshot/CronJob: does not use a pvc by default" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.jobTemplate.spec.template.spec.volumes[] | select(.name == "snapshot")' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.emptyDir.medium' | tee /dev/stderr)
  [ "${actual}" = "Memory" ]
}

#--------------------------------------------------------------------
# global.tls.enabled

@test "snapshot/CronJob: CA volume present when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.jobTemplate.spec.template.spec.volumes[] | select(.name == "tls-ca-cert")' | tee /dev/stderr)
  [ "${actual}" != "" ]
}

@test "snapshot/CronJob: snapshot certificate volume present when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.jobTemplate.spec.template.spec.volumes[] | select(.name == "tls-client-cert")' | tee /dev/stderr)
  [ "${actual}" != "" ]
}

@test "snapshot/CronJob: init container is created when global.tls.enabled=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.jobTemplate.spec.template.spec.initContainers[] | select(.name == "client-tls-init") | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# extraEnvironmentVariables

@test "snapshot/CronJob: custom environment variables" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.extraEnvironmentVars.custom_proxy=fakeproxy' \
      --set 'snapshot.extraEnvironmentVars.no_proxy=custom_no_proxy' \
      . | tee /dev/stderr |
      yq -r '.spec.jobTemplate.spec.template.spec.containers[0].env' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.[1].name' | tee /dev/stderr)
  [ "${actual}" = "custom_proxy" ]

  local actual=$(echo $object |
      yq -r '.[1].value' | tee /dev/stderr)
  [ "${actual}" = "fakeproxy" ]

  local actual=$(echo $object |
      yq -r '.[2].name' | tee /dev/stderr)
  [ "${actual}" = "no_proxy" ]

  local actual=$(echo $object |
      yq -r '.[2].value' | tee /dev/stderr)
  [ "${actual}" = "custom_no_proxy" ]
}

#--------------------------------------------------------------------
# extraSecretEnvironmentVariables

@test "snapshot/CronJob: mount a predefined secret env var" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'snapshot.extraSecretEnvironmentVars[0].envName=AWS_SECRET_ACCESS_KEY' \
      --set 'snapshot.extraSecretEnvironmentVars[0].secretName=consul-snapshot' \
      --set 'snapshot.extraSecretEnvironmentVars[0].secretKey=AWS_SECRET_ACCESS_KEY' \
      . | tee /dev/stderr |
      yq -r '.spec.jobTemplate.spec.template.spec.containers[0].env' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.[1].name' | tee /dev/stderr)
  [ "${actual}" = "AWS_SECRET_ACCESS_KEY" ]

  local actual=$(echo $object |
      yq -r '.[1].valueFrom.secretKeyRef.name' | tee /dev/stderr)
  [ "${actual}" = "consul-snapshot" ]

   local actual=$(echo $object |
      yq -r '.[1].valueFrom.secretKeyRef.key' | tee /dev/stderr)
  [ "${actual}" = "AWS_SECRET_ACCESS_KEY" ]

}

#--------------------------------------------------------------------
# global.bootstrapACLs

@test "snapshot/CronJob: bootstrap-acl-token volume is created when global.bootstrapACLs=true" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'global.bootstrapACLs=true' \
      . | tee /dev/stderr |
      yq '.spec.jobTemplate.spec.template.spec.volumes[] | select(.name == "bootstrap-acl-token")' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.name' | tee /dev/stderr)
  [ "${actual}" = "bootstrap-acl-token" ]

  local actual=$(echo $object |
      yq -r '.secret.secretName' | tee /dev/stderr)
  [ "${actual}" = "release-name-consul-bootstrap-acl-token" ]

}

@test "snapshot/CronJob: bootstrap-acl-token volumeMount is created when global.bootstrapACLs=true" {
  cd `chart_dir`
  local object=$(helm template \
      -x templates/snapshot-cronjob.yaml  \
      --set 'snapshot.enabled=true' \
      --set 'global.bootstrapACLs=true' \
      . | tee /dev/stderr |
      yq '.spec.jobTemplate.spec.template.spec.containers[0].volumeMounts[] | select(.name == "bootstrap-acl-token")' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.name' | tee /dev/stderr)
  [ "${actual}" = "bootstrap-acl-token" ]

  local actual=$(echo $object |
      yq -r '.mountPath' | tee /dev/stderr)
  [ "${actual}" = "/consul/bootstrap-acl-token" ]
}
