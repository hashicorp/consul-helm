#!/usr/bin/env bats

load _helpers

@test "connect-inject/networkpolicy: disabled by default when connect-inject is enabled" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/connect-inject-networkpolicy.yaml \
                        --set 'connectInject.enabled=true' \
                        . | tee /dev/stderr |
                       yq 'length == 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "connect-inject/networkpolicy: enabled with global.enableNetworkPolicies" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/connect-inject-networkpolicy.yaml \
                        --set 'connectInject.enabled=true' \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'networkPolicies.kubernetesMasterSelector[0].ipBlock.cidr=toto' \
                        . | tee /dev/stderr |
                       yq 'length > 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "connect-inject/networkpolicy: enabled with connectInject.enabled=true and global.enableNetworkPolicies" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/connect-inject-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'connectInject.enabled=true' \
                        --set 'networkPolicies.kubernetesMasterSelector[0].ipBlock.cidr=toto' \
                        . | tee /dev/stderr |
                       yq 'length > 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "connect-inject/networkpolicy: enabled when not global.enabled and connectInject.enabled" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/connect-inject-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'connectInject.enabled=true' \
                        --set 'global.enabled=false' \
                        --set 'networkPolicies.kubernetesMasterSelector[0].ipBlock.cidr=toto' \
                        . | tee /dev/stderr |
                       yq 'length > 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

#---------------------------------------
#

@test "connect-inject/networkpolicy: fail when kubernetes master selector not set" {
    cd `chart_dir`
    run helm template \
        -x templates/client-networkpolicy.yaml \
        --set 'global.enableNetworkPolicies=true' \
        --set 'connectInject.enabled=true' \
        .
    [ $status = 1 ]
}

@test "connect-inject/networkpolicy: sets the selector of the kubernetes master" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/connect-inject-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'connectInject.enabled=true' \
                        --set 'networkPolicies.kubernetesMasterSelector[0].ipBlock.cidr=toto' \
                        . | tee /dev/stderr |
                       yq '.spec.egress[0].to[0].ipBlock.cidr | test("toto")' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}
