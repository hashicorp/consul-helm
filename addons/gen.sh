#!/usr/bin/env bash

# Copyright consul Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

WD=$(dirname "$0")
WD=$(cd "$WD"; pwd)

set -eux

# This script sets up the plain text rendered deployments for addons
# See samples/addons/README.md for more information

TEMPLATES="${WD}/../templates"
DASHBOARDS="${WD}/dashboards"
TMP=$(mktemp -d)

# Set up prometheus
helm template prometheus prometheus \
  --namespace "replace-me-namespace" \
  --version 11.16.2 \
  --repo https://prometheus-community.github.io/helm-charts \
  -f "${WD}/values-prometheus.yaml" \
  > "${TEMPLATES}/prometheus.yaml"

function compressDashboard() {
  < "${DASHBOARDS}/$1" jq -c  > "${TMP}/$1"
}

# Set up grafana
{
  helm template grafana grafana \
    --namespace "replace-me-namespace" \
    --version 5.8.10 \
    --repo https://grafana.github.io/helm-charts \
    -f "${WD}/values-grafana.yaml"

  # Set up grafana dashboards. Compress to single line json to avoid Kubernetes size limits
  compressDashboard "consul-server-monitoring.json"
  echo -e "\n---\n"
  kubectl create configmap -n "replace-me-namespace" consul-grafana-dashboards \
    --dry-run=client -oyaml \
    --from-file=consul-server-monitoring.json="${TMP}/consul-server-monitoring.json"

} > "${TEMPLATES}/grafana.yaml"
