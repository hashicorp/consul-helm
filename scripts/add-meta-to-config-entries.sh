#!/usr/bin/env bash

# Usage:
# ./add-meta-to-config-entries.sh <datacenter>
#
# This script will add metadata to service-defaults and proxy-defaults
# config entries so they can be managed by CRDs.

set -eo pipefail

if ! command -v consul &> /dev/null; then
    echo "consul cli must be installed"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "jq must be installed"
    exit 1
fi

if [ ! "$1" ]; then
  echo "Error: datacenter name must be passed as first argument"
  exit 1
fi

if [ ! "$CONSUL_HTTP_ADDR" ]; then
  echo "Using default CONSUL_HTTP_ADDR: http://127.0.0.1:8500"
fi

if [ ! "$CONSUL_HTTP_TOKEN" ]; then
  echo "CONSUL_HTTP_TOKEN is not set, proceding without ACLs"
  echo
fi

set -u

datacenter="$1"

for svc_default in $(consul config list -kind service-defaults); do
  echo "Adding metadata key to service-defaults/$svc_default"
  old_entry=$(mktemp)
  new_entry=$(mktemp)
  consul config read -kind service-defaults -name "$svc_default" > "$old_entry"
  jq --arg datacenter "$datacenter" '. + {"Meta": {"consul.hashicorp.com/source-datacenter": $datacenter}}' "$old_entry" > "$new_entry"
  consul config write "$new_entry"
  rm "$new_entry" "$old_entry"
  echo
done

if [ "$(consul config list -kind proxy-defaults)" ]; then
  echo "Adding metadata key to proxy-defaults/global"
  old_entry=$(mktemp)
  new_entry=$(mktemp)
  consul config read -kind proxy-defaults -name global > "$old_entry"
  jq --arg datacenter "$datacenter" '. + {"Meta": {"consul.hashicorp.com/source-datacenter": $datacenter}}' "$old_entry" > "$new_entry"
  consul config write "$new_entry"
  rm "$new_entry" "$old_entry"
fi
