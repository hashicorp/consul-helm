# Consul Helm Chart

⚠️ The Consul Helm chart has been moved to [`hashicorp/consul-k8s`](https://github.com/hashicorp/consul-k8s) under the [`charts/consul`](https://github.com/hashicorp/consul-k8s/tree/main/charts/consul) directory. ⚠️

Please direct all pull requests and issues to that repository.

### Why We Moved consul-helm

For users, the separate repositories lead to difficulty on new releases and confusion surrounding versioning. Most of the time new releases that include changes to `consul-k8s` also change `consul-helm`. But separate repositories mean separate GitHub PR's and added confusion in opening new Github Issues. In addition, we maintain separate versions of the `consul-k8s` binary and the Consul Helm chart, which in most cases are more tightly coupled together with dependencies. This versioning strategy has also led to confusion as to which Helm charts are compatible with which versions of `consul-k8s`.
