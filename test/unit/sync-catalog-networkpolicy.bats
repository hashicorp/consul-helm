#!/usr/bin/env bats

load _helpers

@test "sync-catalog/networkpolicy: disabled by default" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/sync-catalog-networkpolicy.yaml \
                        . | tee /dev/stderr |
                       yq 'length == 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "sync-catalog/networkpolicy: disabled with global.enableNetworkPolicies" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/sync-catalog-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        . | tee /dev/stderr |
                       yq 'length == 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "sync-catalog/networkpolicy: enabled with syncCatalog.enabled and global.enableNetworkPolicies" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/sync-catalog-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'syncCatalog.enabled=true' \
                        --set 'networkPolicies.kubernetesMasterSelector[0].ipBlock.cidr=toto' \
                        . | tee /dev/stderr |
                       yq 'length > 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "sync-catalog/networkpolicy: enabled when not global.enabled and syncCatalog.enabled" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/sync-catalog-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'syncCatalog.enabled=true' \
                        --set 'networkPolicies.kubernetesMasterSelector[0].ipBlock.cidr=toto' \
                        --set 'global.enabled=false' \
                        --set 'networkPolicies.additionalServerSelectors[0].ipBlock.cidr="toto"' \
                        . | tee /dev/stderr |
                       yq 'length > 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

#--------------------------------------------
#

@test "sync-catalog/networkpolicy: fail when kubernetes master selector not set" {
    cd `chart_dir`
    run helm template \
        -x templates/sync-catalog-networkpolicy.yaml \
        --set 'global.enableNetworkPolicies=true' \
        --set 'syncCatalog.enabled=true' \
        .
    [ $status = 1 ]
}

@test "sync-catalog/networkpolicy: sets the selector of the kubernetes master" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/sync-catalog-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'syncCatalog.enabled=true' \
                        --set 'networkPolicies.kubernetesMasterSelector[0].ipBlock.cidr=toto' \
                        . | tee /dev/stderr |
                       yq '.spec.egress[0].to[0].ipBlock.cidr | test("toto")' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}


@test "sync-catalog/networkpolicy: sets the server egress selector" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/sync-catalog-networkpolicy.yaml \
                        --set 'global.enabled=false' \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'syncCatalog.enabled=true' \
                        --set 'networkPolicies.kubernetesMasterSelector[0].ipBlock.cidr=toto' \
                        --set 'server.enabled=true' \
                        . | tee /dev/stderr |
                       yq '.spec.egress[1].to[0].podSelector.matchLabels.component | test("server")' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "sync-catalog/networkpolicy: sets the client egress selector" {
    cd `chart_dir`
    # either additionalServerSelector must be set or server.enabled in order to
    # enable the client
    local actual=$(helm template \
                        -x templates/sync-catalog-networkpolicy.yaml \
                        --set 'global.enabled=false' \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'syncCatalog.enabled=true' \
                        --set 'networkPolicies.kubernetesMasterSelector[0].ipBlock.cidr=toto' \
                        --set 'client.enabled=true' \
                        --set 'networkPolicies.additionalServerSelectors[0].ipBlock.cidr=test' \
                        . | tee /dev/stderr |
                       yq '.spec.egress[1].to[0].podSelector.matchLabels.component | test("client")' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}
