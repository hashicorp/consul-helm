#!/usr/bin/env bats

load _helpers

@test "dns/networkpolicy: disabled by default" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/dns-networkpolicy.yaml \
                        . | tee /dev/stderr |
                       yq 'length == 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "dns/networkpolicy: enabled with global.enableNetworkPolicies" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/dns-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        . | tee /dev/stderr |
                       yq 'length > 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "dns/networkpolicy: disabled with dns.enabled=false" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/dns-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'dns.enabled=false' \
                        . | tee /dev/stderr |
                       yq 'length == 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "dns/networkpolicy: enabled when not global.enabled and dns.enabled" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/dns-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'dns.enabled=true' \
                        --set 'global.enabled=false' \
                        . | tee /dev/stderr |
                       yq 'length > 0' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}

#-------------------------------------
# sets the right selectors

@test "dns/networkpolicy: correctly sets the dns namespace selector" {
    cd `chart_dir`
    local actual=$(helm template \
                        -x templates/dns-networkpolicy.yaml \
                        --set 'global.enableNetworkPolicies=true' \
                        --set 'networkPolicies.dnsNamespaceSelector.matchLabels.name=toto' \
                        . | tee /dev/stderr |
                       yq '.spec.ingress[0].from[0].namespaceSelector.matchLabels.name | test("toto")' | tee /dev/stderr)
    [ "${actual}" = "true" ]
}
