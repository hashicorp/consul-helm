package acceptance

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/hashicorp/consul-helm/test/acceptance/framework"
	"github.com/hashicorp/consul/api"
	"github.com/hashicorp/consul/sdk/testutil/retry"
	"github.com/stretchr/testify/require"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func TestConnectInjectDefault(t *testing.T) {
	env, err := TestEnvironments.GetDefaultEnvironment()
	require.NoError(t, err)

	helmOptions := &helm.Options{
		KubectlOptions: env.GetKubectlOptions(),
		SetValues: map[string]string{
			"connectInject.enabled": "true",
		},
	}

	releaseName := fmt.Sprintf("consul-%s", strings.ToLower(random.UniqueId()))
	consulCluster := framework.NewHelmCluster(helmOptions, releaseName)

	consulCluster.Create(t)
	defer consulCluster.Destroy(t)

	// todo: refactor this
	k8s.KubectlApply(t, env.GetKubectlOptions(), "fixtures/static-server.yaml")
	output, err := k8s.RunKubectlAndGetOutputE(t, env.GetKubectlOptions(), "rollout", "status", "deploy/static-server")
	require.NoError(t, err)
	require.Contains(t, output, "successfully rolled out")
	defer k8s.KubectlDelete(t, env.GetKubectlOptions(), "fixtures/static-server.yaml")

	k8s.KubectlApply(t, env.GetKubectlOptions(), "fixtures/static-client.yaml")
	output, err = k8s.RunKubectlAndGetOutputE(t, env.GetKubectlOptions(), "rollout", "status", "deploy/static-client")
	require.NoError(t, err)
	require.Contains(t, output, "successfully rolled out")
	defer k8s.KubectlDelete(t, env.GetKubectlOptions(), "fixtures/static-client.yaml")

	pods := k8s.ListPods(t, env.GetKubectlOptions(), metav1.ListOptions{LabelSelector: "app=static-client"})
	require.Len(t, pods, 1)

	retry.Run(t, func(r *retry.R) {
		output, err = k8s.RunKubectlAndGetOutputE(t, env.GetKubectlOptions(), "exec", pods[0].Name, "-c", "static-client", "--", "curl", "-vvvs", "http://127.0.0.1:1234/")
		require.NoError(r, err)
		require.Contains(r, output, "hello world")
	})
}

func TestConnectInjectSecure(t *testing.T) {
	env, err := TestEnvironments.GetDefaultEnvironment()
	require.NoError(t, err)
	helmOptions := &helm.Options{
		KubectlOptions: env.GetKubectlOptions(),
		Logger:         logger.New(logger.TestingT),
		SetValues: map[string]string{
			"connectInject.enabled":        "true",
			"global.tls.enabled":           "true",
			"global.acls.manageSystemACLs": "true",
		},
	}

	releaseName := fmt.Sprintf("consul-%s", strings.ToLower(random.UniqueId()))
	consulCluster := framework.NewHelmCluster(helmOptions, releaseName)

	consulCluster = framework.NewHelmCluster(helmOptions, releaseName)
	consulCluster.Create(t)
	defer consulCluster.Destroy(t)

	k8s.KubectlApply(t, env.GetKubectlOptions(), "fixtures/static-server.yaml")
	output, err := k8s.RunKubectlAndGetOutputE(t, env.GetKubectlOptions(), "rollout", "status", "deploy/static-server")
	require.NoError(t, err)
	require.Contains(t, output, "successfully rolled out")
	defer k8s.KubectlDelete(t, env.GetKubectlOptions(), "fixtures/static-server.yaml")

	k8s.KubectlApply(t, env.GetKubectlOptions(), "fixtures/static-client.yaml")
	output, err = k8s.RunKubectlAndGetOutputE(t, env.GetKubectlOptions(), "rollout", "status", "deploy/static-client")
	require.NoError(t, err)
	require.Contains(t, output, "successfully rolled out")
	defer k8s.KubectlDelete(t, env.GetKubectlOptions(), "fixtures/static-client.yaml")

	pods := k8s.ListPods(t, env.GetKubectlOptions(), metav1.ListOptions{LabelSelector: "app=static-client"})
	fmt.Println(pods)
	require.Len(t, pods, 1)

	// expect failure because we haven't created intentions
	output, err = k8s.RunKubectlAndGetOutputE(t, env.GetKubectlOptions(), "exec", pods[0].Name, "-c", "static-client", "--", "curl", "-vvvs", "http://127.0.0.1:1234/")
	require.Error(t, err)

	consulClient, localPort := consulCluster.(*framework.HelmCluster).SetupConsulClient(t, true)

	tunnel := k8s.NewTunnel(env.GetKubectlOptions(), k8s.ResourceTypePod, fmt.Sprintf("%s-consul-server-0", releaseName), localPort, 8501)
	tunnel.ForwardPort(t)
	defer tunnel.Close()

	_, _, err = consulClient.Connect().IntentionCreate(&api.Intention{
		SourceName:      "static-client",
		DestinationName: "static-server",
		Action:          api.IntentionActionAllow,
	}, nil)
	require.NoError(t, err)

	// connect again and expect success
	retry.Run(t, func(r *retry.R) {
		output, err = k8s.RunKubectlAndGetOutputE(t, env.GetKubectlOptions(), "exec", pods[0].Name, "-c", "static-client", "--", "curl", "-vvvs", "http://127.0.0.1:1234/")
		require.NoError(r, err)
		require.Contains(r, output, "hello world")
	})
}
