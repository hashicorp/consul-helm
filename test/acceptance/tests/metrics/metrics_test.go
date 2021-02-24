package metrics

import (
	"context"
	"fmt"
	"testing"

	"github.com/hashicorp/consul-helm/test/acceptance/framework/consul"
	"github.com/hashicorp/consul-helm/test/acceptance/framework/helpers"
	"github.com/hashicorp/consul-helm/test/acceptance/framework/k8s"
	"github.com/hashicorp/consul-helm/test/acceptance/framework/logger"
	"github.com/stretchr/testify/require"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const staticClientName = "static-client"

// Test that Connect and wan federation over mesh gateways work in a default installation
// i.e. without ACLs because TLS is required for WAN federation over mesh gateways
func TestMetrics(t *testing.T) {
	env := suite.Environment()
	cfg := suite.Config()

	ctx := env.DefaultContext(t)

	helmValues := map[string]string{
		"global.datacenter":                 "dc1",
		"global.metrics.enabled":            "true",
		"global.metrics.enableAgentMetrics": "true",

		"connectInject.enabled": "true",
		"controller.enabled":    "true",

		"meshGateway.enabled":  "true",
		"meshGateway.replicas": "1",

		"ingressGateways.enabled":              "true",
		"ingressGateways.gateways[0].name":     "ingress-gateway",
		"ingressGateways.gateways[0].replicas": "1",

		"terminatingGateways.enabled":              "true",
		"terminatingGateways.gateways[0].name":     "terminating-gateway",
		"terminatingGateways.gateways[0].replicas": "1",
	}

	if cfg.UseKind {
		helmValues["meshGateway.service.type"] = "NodePort"
		helmValues["meshGateway.service.nodePort"] = "30000"
		helmValues["ingressGateways.service.type"] = "NodePort"
		helmValues["ingressGateways.service.nodePort"] = "31000"
		helmValues["terminatingGateways.service.type"] = "NodePort"
		helmValues["terminatingGateways.service.nodePort"] = "32000"
	}

	releaseName := helpers.RandomName()

	// Install the consul cluster in the default kubernetes ctx
	consulCluster := consul.NewHelmCluster(t, helmValues, ctx, cfg, releaseName)
	consulCluster.Create(t)

	_ = consulCluster.SetupConsulClient(t, false)

	logger.Log(t, "creating static-client")
	k8s.DeployKustomize(t, ctx.KubectlOptions(t), cfg.NoCleanupOnFailure, cfg.DebugDirectory, "../fixtures/cases/static-client-inject")

	// Server Metrics
	ns := ctx.KubectlOptions(t).Namespace
	servers, err := ctx.KubernetesClient(t).CoreV1().Pods(ns).List(context.Background(), metav1.ListOptions{LabelSelector: "component=server"})
	require.NoError(t, err)
	for _, pod := range servers.Items {
		podIP := pod.Status.PodIP
		metricsOutput, err := k8s.RunKubectlAndGetOutputE(t, ctx.KubectlOptions(t), "exec", "deploy/"+staticClientName, "--", "curl", fmt.Sprintf("http://%s:8500/v1/agent/metrics?format=prometheus", podIP))
		require.NoError(t, err)
		require.Contains(t, metricsOutput, `consul_acl_ResolveToken{quantile="0.5"}`)
	}

	// Client Metrics
	clients, err := ctx.KubernetesClient(t).CoreV1().Pods(ns).List(context.Background(), metav1.ListOptions{LabelSelector: "component=client"})
	require.NoError(t, err)
	for _, pod := range clients.Items {
		podIP := pod.Status.PodIP
		metricsOutput, err := k8s.RunKubectlAndGetOutputE(t, ctx.KubectlOptions(t), "exec", "deploy/"+staticClientName, "--", "curl", fmt.Sprintf("http://%s:8500/v1/agent/metrics?format=prometheus", podIP))
		require.NoError(t, err)
		require.Contains(t, metricsOutput, `consul_acl_ResolveToken{quantile="0.5"}`)
	}

	// Ingress Gateway Metrics
	igGateways, err := ctx.KubernetesClient(t).CoreV1().Pods(ns).List(context.Background(), metav1.ListOptions{LabelSelector: "component=ingress-gateway"})
	require.NoError(t, err)
	for _, pod := range igGateways.Items {
		podIP := pod.Status.PodIP
		metricsOutput, err := k8s.RunKubectlAndGetOutputE(t, ctx.KubectlOptions(t), "exec", "deploy/"+staticClientName, "--", "curl", fmt.Sprintf("http://%s:20200/metrics", podIP))
		require.NoError(t, err)
		require.Contains(t, metricsOutput, `envoy_cluster_assignment_stale{local_cluster="ingress-gateway",consul_source_service="ingress-gateway",consul_source_namespace="default",consul_source_datacenter="dc1",envoy_cluster_name="local_agent"} 0`)
	}

	// Terminating Gateway Metrics
	termGateways, err := ctx.KubernetesClient(t).CoreV1().Pods(ns).List(context.Background(), metav1.ListOptions{LabelSelector: "component=terminating-gateway"})
	require.NoError(t, err)
	for _, pod := range termGateways.Items {
		podIP := pod.Status.PodIP
		metricsOutput, err := k8s.RunKubectlAndGetOutputE(t, ctx.KubectlOptions(t), "exec", "deploy/"+staticClientName, "--", "curl", fmt.Sprintf("http://%s:20200/metrics", podIP))
		require.NoError(t, err)
		require.Contains(t, metricsOutput, `envoy_cluster_assignment_stale{local_cluster="terminating-gateway",consul_source_service="terminating-gateway",consul_source_namespace="default",consul_source_datacenter="dc1",envoy_cluster_name="local_agent"} 0`)
	}

	// Mesh Gateway Metrics
	meshGateways, err := ctx.KubernetesClient(t).CoreV1().Pods(ns).List(context.Background(), metav1.ListOptions{LabelSelector: "component=mesh-gateway"})
	require.NoError(t, err)
	for _, pod := range meshGateways.Items {
		podIP := pod.Status.PodIP
		metricsOutput, err := k8s.RunKubectlAndGetOutputE(t, ctx.KubectlOptions(t), "exec", "deploy/"+staticClientName, "--", "curl", fmt.Sprintf("http://%s:20200/metrics", podIP))
		require.NoError(t, err)
		require.Contains(t, metricsOutput, `envoy_cluster_assignment_stale{local_cluster="mesh-gateway",consul_source_service="mesh-gateway",consul_source_namespace="default",consul_source_datacenter="dc1",envoy_cluster_name="local_agent"} 0`)
	}

}
