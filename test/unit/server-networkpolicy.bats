#!/usr/bin/env bats

load _helpers


@test "server/networkpolicy: disabled by default" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/server-networkpolicy.yaml \
                        . | tee /dev/stderr |
                       yq 'length == 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "server/networkpolicy: enabled with global.enableNetworkPolicies" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/server-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        . | tee /dev/stderr |
                       yq 'length > 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "server/networkpolicy: disabled with server.enabled=false" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/server-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'server.enabled=false' \
                        --set 'networkPolicies.additionalServerSelectors=toto' \
                        . | tee /dev/stderr |
                       yq 'length == 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "server/networkpolicy: enabled when not global.enabled and server.enabled" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/server-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'server.enabled=true' \
                        --set 'global.enabled=false' \
                        . | tee /dev/stderr |
                       yq 'length > 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}


#------------------------------
# gossip
@test "server/networkpolicy: add client selector if client.enabled" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/server-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'server.enabled=true' \
                        --set 'client.enabled=true' \
                        --set 'global.enabled=false' \
                        . | tee /dev/stderr |
                       yq '.spec.ingress[0].from[1].podSelector.matchLabels.component | test("client")' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "server/networkpolicy: add additionalClientSlectors gossip/rpc" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/server-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'server.enabled=true' \
                        --set 'client.enabled=true' \
                        --set 'global.enabled=false' \
                        --set 'networkPolicies.additionalClientSelectors[0].ipBlock.cidr=127.0.0.1/32' \
                        . | tee /dev/stderr |
                       yq '[
                       (.spec.ingress[0].from[2].ipBlock.cidr | test("127.0.0.1/32")),
                       (.spec.egress[0].to[2].ipBlock.cidr | test("127.0.0.1/32"))
                       ] | all' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "server/networkpolicy: add additionalServerSlectors gossip/rpc" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/server-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'server.enabled=true' \
                        --set 'client.enabled=true' \
                        --set 'global.enabled=false' \
                        --set 'networkPolicies.additionalServerSelectors[0].ipBlock.cidr=127.0.0.1/32' \
                        . | tee /dev/stderr |
                       yq '[
                       (.spec.ingress[0].from[2].ipBlock.cidr | test("127.0.0.1/32")),
                       (.spec.egress[0].to[2].ipBlock.cidr | test("127.0.0.1/32"))
                       ] | all' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

#------------------------------
# wan
@test "server/networkpolicy: add wan servers" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/server-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'server.enabled=true' \
                        --set 'client.enabled=true' \
                        --set 'global.enabled=false' \
                        --set 'networkPolicies.serverWanSelectors[0].ipBlock.cidr=127.0.0.1/32' \
                        . | tee /dev/stderr |
                       yq -r '[
                       (.spec.ingress[1].from[0].ipBlock.cidr | test("127.0.0.1/32")),
                       (.spec.egress[2].to[0].ipBlock.cidr | test("127.0.0.1/32"))
                       ] | all' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

#---------------------------------
# http
@test "server/networkpolicy: add wan servers" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/server-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'networkPolicies.serverHTTPSelectors[0].ipBlock.cidr=127.0.0.1/32' \
                        . | tee /dev/stderr |
                       yq -r '.spec.ingress[1].from[0].ipBlock.cidr | test("127.0.0.1/32")' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}
