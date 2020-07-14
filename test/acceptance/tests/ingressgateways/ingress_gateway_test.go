package connect

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/hashicorp/consul-helm/test/acceptance/framework"
	"github.com/hashicorp/consul-helm/test/acceptance/helpers"
	"github.com/hashicorp/consul/api"
	"github.com/hashicorp/consul/sdk/testutil/retry"
	"github.com/stretchr/testify/require"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func TestIngressGatewayDefault(t *testing.T) {
	env := suite.Environment()

	helmValues := map[string]string{
		"connectInject.enabled": "true",
		"server.replicas": "1",
		"server.bootstrapExpect": "1",
	}

	releaseName := helpers.RandomName()
	consulCluster := framework.NewHelmCluster(t, helmValues, env.DefaultContext(), releaseName)

	consulCluster.Create(t)

	t.Log("creating server")
	createServer(t, env.DefaultContext().KubectlOptions())
	t.Log("creating bounce")
	createBouncePod(t, env.DefaultContext().KubectlOptions())

	// setup Consul client
	t.Log("creating config entry")
	consulClient := consulCluster.SetupConsulClient(t, false)

	// create config entries
	created, _, err := consulClient.ConfigEntries().Set(&api.IngressGatewayConfigEntry{
		Kind:        api.IngressGateway,
		Name:        "ingress-gateway",
		Listeners:   []api.IngressListener{
			{
				Port:     8080,
				Protocol: "tcp",
				Services: []api.IngressService{
					{
						Name:      "static-server",
					},
				},
			},
		},
	}, nil)
	require.NoError(t, err)
	require.Equal(t, true, created, "config entry failed")

	// Bring up ingress gateways
	consulCluster.Upgrade(t, map[string]string{
		"connectInject.enabled": "true",
		"server.replicas": "1",
		"server.bootstrapExpect": "1",
		"ingressGateways.enabled": "1",
		"ingressGateways.gateways[0].name": "ingress-gateway",
		"ingressGateways.gateways[0].replicas": "1",
	})

	t.Log("trying ingress gateway")
	// Check that we can route through the ingress gateway
	k8sClient := env.DefaultContext().KubernetesClient(t)
	k8sOptions := env.DefaultContext().KubectlOptions()

	// We'll call from the bounce pod.
	pods, err := k8sClient.CoreV1().Pods(k8sOptions.Namespace).List(metav1.ListOptions{LabelSelector: "app=bounce"})
	require.NoError(t, err)
	require.Len(t, pods.Items, 1)
	retry.Run(t, func(r *retry.R) {
		output, err := helpers.RunKubectlAndGetOutputE(t, k8sOptions, "exec", pods.Items[0].Name, "--", "curl", "-vvvs", "-H", "Host: static-server.ingress.consul", fmt.Sprintf("http://%s-consul-ingress-gateway:8080/", releaseName))
		require.NoError(r, err)
		require.Contains(r, output, "hello world")
	})
}

func createServer(t *testing.T, options *k8s.KubectlOptions) {
	helpers.KubectlApply(t, options, "fixtures/static-server.yaml")

	t.Cleanup(func() {
		// todo: we might need to wait for deletion here
		helpers.KubectlDelete(t, options, "fixtures/static-server.yaml")
	})

	helpers.RunKubectl(t, options, "wait", "--for=condition=available", "deploy/static-server")
}

func createBouncePod(t *testing.T, options *k8s.KubectlOptions) {
	helpers.KubectlApply(t, options, "fixtures/bounce.yaml")

	t.Cleanup(func() {
		// todo: we might need to wait for deletion here
		helpers.KubectlDelete(t, options, "fixtures/bounce.yaml")
	})

	helpers.RunKubectl(t, options, "wait", "--for=condition=available", "deploy/bounce")
}
