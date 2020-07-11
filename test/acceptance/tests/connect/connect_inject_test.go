package connect

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/hashicorp/consul-helm/test/acceptance/framework"
	"github.com/hashicorp/consul-helm/test/acceptance/helpers"
	"github.com/hashicorp/consul/api"
	"github.com/hashicorp/consul/sdk/testutil/retry"
	"github.com/stretchr/testify/require"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

// todo: add docs
func TestConnectInjectDefault(t *testing.T) {
	env := suite.Environment()

	helmValues := map[string]string{
		"connectInject.enabled": "true",
	}

	releaseName := helpers.RandomName()
	consulCluster := framework.NewHelmCluster(t, helmValues, env.DefaultContext(), releaseName)

	consulCluster.Create(t)

	createServerAndClient(t, env.DefaultContext().KubectlOptions())

	checkConnection(t, env.DefaultContext().KubectlOptions(), env.DefaultContext().KubernetesClient(t), true)
}

func TestConnectInjectSecure(t *testing.T) {
	env := suite.Environment()

	// maybe this could a config struct
	helmValues := map[string]string{
		"connectInject.enabled":        "true",
		"global.tls.enabled":           "true",
		"global.acls.manageSystemACLs": "true",
	}

	releaseName := helpers.RandomName()
	// maybe the helm cluster could know more about its own config
	consulCluster := framework.NewHelmCluster(t, helmValues, env.DefaultContext(), releaseName)

	consulCluster.Create(t)

	createServerAndClient(t, env.DefaultContext().KubectlOptions())

	// expect failure because we haven't created intention
	checkConnection(t, env.DefaultContext().KubectlOptions(), env.DefaultContext().KubernetesClient(t), false)

	// setup Consul client
	consulClient := consulCluster.SetupConsulClient(t, true)

	// create intention
	_, _, err := consulClient.Connect().IntentionCreate(&api.Intention{
		SourceName:      "static-client",
		DestinationName: "static-server",
		Action:          api.IntentionActionAllow,
	}, nil)
	require.NoError(t, err)

	// connect again and expect success
	checkConnection(t, env.DefaultContext().KubectlOptions(), env.DefaultContext().KubernetesClient(t), true)
}

func createServerAndClient(t *testing.T, options *k8s.KubectlOptions) {
	helpers.KubectlApply(t, options, "fixtures/static-server.yaml")
	helpers.KubectlApply(t, options, "fixtures/static-client.yaml")

	t.Cleanup(func() {
		// todo: we might need to wait for deletion here
		helpers.KubectlDelete(t, options, "fixtures/static-server.yaml")
		helpers.KubectlDelete(t, options, "fixtures/static-client.yaml")
	})

	// Wait for both deployments
	helpers.RunKubectl(t, options, "wait", "--for=condition=available", "deploy/static-server")
	helpers.RunKubectl(t, options, "wait", "--for=condition=available", "deploy/static-client")
}

func checkConnection(t *testing.T, options *k8s.KubectlOptions, client *kubernetes.Clientset, expectSuccess bool) {
	pods, err := client.CoreV1().Pods(options.Namespace).List(metav1.ListOptions{LabelSelector: "app=static-client"})
	require.NoError(t, err)
	require.Len(t, pods.Items, 1)

	retry.Run(t, func(r *retry.R) {
		// todo: this is jank because we have to exec into the pod
		output, err := helpers.RunKubectlAndGetOutputE(t, options, "exec", pods.Items[0].Name, "-c", "static-client", "--", "curl", "-vvvs", "http://127.0.0.1:1234/")
		if expectSuccess {
			require.NoError(r, err)
			require.Contains(r, output, "hello world")
		} else {
			require.Error(t, err)
		}
	})
}
