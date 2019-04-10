#!/usr/bin/env bats

load _helpers

@test "client/networkpolicy: disabled by default" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/client-networkpolicy.yaml \
                        . | tee /dev/stderr |
                       yq 'length == 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "client/networkpolicy: enabled with global.enableNetworkPolicies" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/client-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true'\
                        . | tee /dev/stderr |
                       yq 'length > 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "client/networkpolicy: disabled with client.enabled=false" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/client-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'client.enabled=false' \
                        . | tee /dev/stderr |
                       yq 'length == 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "client/networkpolicy: enabled when not global.enabled and client.enabled" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/client-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'client.enabled=true' \
                        --set 'global.enabled=false' \
                        --set 'networkPolicies.additionalServerSelectors[0].ipBlock.cidr="toto"' \
                        . | tee /dev/stderr |
                       yq 'length > 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

#---------------------------------
# gossip
@test "client/networkpolicy: open gossip ports by default" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/client-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        . | tee /dev/stderr |
                       yq '[
                       (.spec.ingress[0].from[1].podSelector.matchLabels.component | test("server")),
                       (.spec.egress[1].to[0].podSelector.matchLabels.component | test("server"))
                       ] | all' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "client/networkpolicy: open gossip ports when client.enabled and server.enabled" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/client-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'global.enabled=false' \
                        --set 'client.enabled=true' \
                        --set 'server.enabled=true' \
                        . | tee /dev/stderr |
                       yq '[
                       (.spec.ingress[0].from[1].podSelector.matchLabels.component | test("server")),
                       (.spec.egress[1].to[0].podSelector.matchLabels.component | test("server"))
                       ] | all' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "client/networkpolicy: append additional gossip clients" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/client-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'networkPolicies.additionalClientSelectors[0].podSelector.matchLabels.mylabel=toto' \
                        . | tee /dev/stderr |
                       yq '[
                       (.spec.ingress[0].from[2].podSelector.matchLabels.mylabel | test("toto")),
                       (.spec.egress[0].to[2].podSelector.matchLabels.mylabel | test("toto"))
                       ] | all' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "client/networkpolicy: append additional gossip servers" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/client-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'networkPolicies.additionalServerSelectors[0].podSelector.matchLabels.mylabel=toto' \
                        . | tee /dev/stderr |
                       yq '[
                       (.spec.ingress[0].from[2].podSelector.matchLabels.mylabel | test("toto")),
                       (.spec.egress[0].to[2].podSelector.matchLabels.mylabel | test("toto"))
                       ] | all' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

#----------------------------------
# http
@test "client/networkpolicy: allow HTTP traffic with clientHTTPSelectors" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/client-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'networkPolicies.clientHTTPSelectors[0].podSelector.matchLabels.mylabel=toto' \
                        . | tee /dev/stderr |
                       yq '.spec.ingress[1].from[0].podSelector.matchLabels.mylabel' | tee /dev/stderr)
    [ "${actual}" = "\"toto\"" ]
}

@test "client/networkpolicy: allow sync-catalog traffic" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/client-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'networkPolicies.kubernetesMasterSelector=toto' \
                        --set 'syncCatalog.enabled=true' \
                        . | tee /dev/stderr |
                       yq '.spec.ingress[1].from[0].podSelector.matchLabels.component' | tee /dev/stderr)
    [ "${actual}" = "\"sync-catalog\"" ]
}

#----------------------------
# rpc
@test "client/networkpolicy: allow egress rpc when server.enabled " {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/client-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        . | tee /dev/stderr |
                       yq '.spec.egress[1].to[0].podSelector.matchLabels.component' | tee /dev/stderr)
    [ "${actual}" = "\"server\"" ]
}

@test "client/networkpolicy: allow egress to additional servers when server.enabled" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/client-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'networkPolicies.additionalServerSelectors[0].podSelector.matchLabels.mylabel=toto' \
                        . | tee /dev/stderr |
                       yq '.spec.egress[1].to[1].podSelector.matchLabels.mylabel' | tee /dev/stderr)
    [ "${actual}" = "\"toto\"" ]
}

@test "client/networkpolicy: allow egress to additional servers when not server.enabled" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/client-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'server.enabled=false' \
                        --set 'networkPolicies.additionalServerSelectors[0].podSelector.matchLabels.mylabel=toto' \
                        . | tee /dev/stderr |
                       yq '.spec.egress[1].to[0].podSelector.matchLabels.mylabel' | tee /dev/stderr)
    [ "${actual}" = "\"toto\"" ]
}

@test "client/networkpolicy: fail when not server.enabled and networkPolicies.additionalServerSelectors empty" {
    cd `chart_dir`
    run helm template \
        -x templates/client-networkpolicy.yaml \
        --set 'global.enableNetworkPolicies=true' \
        --set 'server.enabled=false' \
        .
    [ $status = 1 ]
}
