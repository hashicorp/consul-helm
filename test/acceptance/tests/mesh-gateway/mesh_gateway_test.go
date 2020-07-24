package meshgateway

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/hashicorp/consul-helm/test/acceptance/framework"
	"github.com/hashicorp/consul-helm/test/acceptance/helpers"
	"github.com/hashicorp/consul/api"
	"github.com/hashicorp/consul/sdk/testutil/retry"
	"github.com/stretchr/testify/require"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

// Test that Connect and wan federation over mesh gateways work in a default installation
// i.e. without ACLs because TLS is required for WAN federation over mesh gateways
func TestMeshGatewayDefault(t *testing.T) {
	env := suite.Environment()

	primaryHelmValues := map[string]string{
		"global.datacenter":                        "dc1",
		"global.tls.enabled":                       "true",
		"global.tls.httpsOnly":                     "false",
		"global.federation.enabled":                "true",
		"global.federation.createFederationSecret": "true",

		"connectInject.enabled": "true",

		"meshGateway.enabled":  "true",
		"meshGateway.replicas": "1",
	}

	releaseName := helpers.RandomName()

	// Install the primary consul cluster in the default kubernetes context
	primaryConsulCluster := framework.NewHelmCluster(t, primaryHelmValues, env.DefaultContext(t), suite.Config(), releaseName)
	primaryConsulCluster.Create(t)

	secondaryContext := env.Context(t, framework.SecondaryContextName)

	// Get the federation secret from the primary cluster and apply it to secondary cluster
	federationSecretName := fmt.Sprintf("%s-consul-federation", releaseName)
	secretYAML, err := helpers.RunKubectlAndGetOutputE(t, env.DefaultContext(t).KubectlOptions(), "get", "secret", federationSecretName, "-o", "yaml")
	require.NoError(t, err)
	helpers.KubectlApplyFromString(t, secondaryContext.KubectlOptions(), secretYAML)

	// Create secondary cluster
	secondaryHelmValues := map[string]string{
		"global.datacenter": "dc2",

		"global.tls.enabled":           "true",
		"global.tls.httpsOnly":         "false",
		"global.tls.caCert.secretName": federationSecretName,
		"global.tls.caCert.secretKey":  "caCert",
		"global.tls.caKey.secretName":  federationSecretName,
		"global.tls.caKey.secretKey":   "caKey",

		"global.federation.enabled": "true",

		"server.extraVolumes[0].type":          "secret",
		"server.extraVolumes[0].name":          federationSecretName,
		"server.extraVolumes[0].load":          "true",
		"server.extraVolumes[0].items[0].key":  "serverConfigJSON",
		"server.extraVolumes[0].items[0].path": "config.json",

		"connectInject.enabled": "true",

		"meshGateway.enabled":  "true",
		"meshGateway.replicas": "1",
	}

	// Install the secondary consul cluster in the secondary kubernetes context
	secondaryConsulCluster := framework.NewHelmCluster(t, secondaryHelmValues, secondaryContext, suite.Config(), releaseName)
	secondaryConsulCluster.Create(t)

	// Verify federation between servers
	consulClient := primaryConsulCluster.SetupConsulClient(t, false)
	members, err := consulClient.Agent().Members(true)
	require.NoError(t, err)
	// Expect two consul servers
	require.Len(t, members, 2)

	// Check that we can connect services over the mesh gateways
	t.Log("creating static-server in dc2")
	createServer(t, secondaryContext.KubectlOptions())

	t.Log("creating static-client in dc1")
	createClient(t, env.DefaultContext(t).KubectlOptions())

	t.Log("checking that connection is successful")
	checkConnection(t, env.DefaultContext(t).KubectlOptions(), env.DefaultContext(t).KubernetesClient(t), true)
}

// Test that Connect and wan federation over mesh gateways work in a secure installation,
// with ACLs and TLS with auto-encrypt enabled
func TestConnectInjectSecure(t *testing.T) {
	env := suite.Environment()

	primaryHelmValues := map[string]string{
		"global.datacenter":            "dc1",
		"global.tls.enabled":           "true",
		"global.tls.enableAutoEncrypt": "true",

		"global.acls.manageSystemACLs":       "true",
		"global.acls.createReplicationToken": "true",

		"global.federation.enabled":                "true",
		"global.federation.createFederationSecret": "true",

		"connectInject.enabled": "true",

		"meshGateway.enabled":  "true",
		"meshGateway.replicas": "1",
	}

	releaseName := helpers.RandomName()

	// Install the primary consul cluster in the default kubernetes context
	primaryConsulCluster := framework.NewHelmCluster(t, primaryHelmValues, env.DefaultContext(t), suite.Config(), releaseName)
	primaryConsulCluster.Create(t)

	secondaryContext := env.Context(t, framework.SecondaryContextName)

	// Get the federation secret from the primary cluster and apply it to secondary cluster
	federationSecretName := fmt.Sprintf("%s-consul-federation", releaseName)
	// this command prints secrets to logs
	secretYAML, err := helpers.RunKubectlAndGetOutputE(t, env.DefaultContext(t).KubectlOptions(), "get", "secret", federationSecretName, "-o", "yaml")
	require.NoError(t, err)
	helpers.KubectlApplyFromString(t, secondaryContext.KubectlOptions(), secretYAML)

	// Create secondary cluster
	secondaryHelmValues := map[string]string{
		"global.datacenter": "dc2",

		"global.tls.enabled":           "true",
		"global.tls.httpsOnly":         "false",
		"global.tls.caCert.secretName": federationSecretName,
		"global.tls.caCert.secretKey":  "caCert",
		"global.tls.caKey.secretName":  federationSecretName,
		"global.tls.caKey.secretKey":   "caKey",

		"global.acls.manageSystemACLs":            "true",
		"global.acls.replicationToken.secretName": federationSecretName,
		"global.acls.replicationToken.secretKey":  "replicationToken",

		"global.federation.enabled": "true",

		"server.extraVolumes[0].type":          "secret",
		"server.extraVolumes[0].name":          federationSecretName,
		"server.extraVolumes[0].load":          "true",
		"server.extraVolumes[0].items[0].key":  "serverConfigJSON",
		"server.extraVolumes[0].items[0].path": "config.json",

		"connectInject.enabled": "true",

		"meshGateway.enabled":  "true",
		"meshGateway.replicas": "1",
	}

	// Install the secondary consul cluster in the secondary kubernetes context
	secondaryConsulCluster := framework.NewHelmCluster(t, secondaryHelmValues, secondaryContext, suite.Config(), releaseName)
	secondaryConsulCluster.Create(t)

	// Verify federation between servers
	// todo: add logs
	consulClient := primaryConsulCluster.SetupConsulClient(t, true)
	members, err := consulClient.Agent().Members(true)
	require.NoError(t, err)
	// Expect two consul servers
	require.Len(t, members, 2)

	// Check that we can connect services over the mesh gateways
	t.Log("creating static-server in dc2")
	createServer(t, secondaryContext.KubectlOptions())

	t.Log("creating static-client in dc1")
	createClient(t, env.DefaultContext(t).KubectlOptions())

	t.Log("creating intention")
	_, _, err = consulClient.Connect().IntentionCreate(&api.Intention{
		SourceName:      "static-client",
		DestinationName: "static-server",
		Action:          api.IntentionActionAllow,
	}, nil)
	require.NoError(t, err)

	t.Log("checking that connection is successful")
	checkConnection(t, env.DefaultContext(t).KubectlOptions(), env.DefaultContext(t).KubernetesClient(t), true)
}

// createServer sets up static-server deployment
func createServer(t *testing.T, options *k8s.KubectlOptions) {
	helpers.KubectlApply(t, options, "fixtures/static-server.yaml")

	helpers.Cleanup(t, func() {
		// Note: this delete command won't wait for pods to be fully terminated.
		// This shouldn't cause any test pollution because the underlying
		// objects are deployments, and so when other tests create these
		// they should have different pod names.
		helpers.KubectlDelete(t, options, "fixtures/static-server.yaml")
	})

	// Wait for both deployments
	helpers.RunKubectl(t, options, "wait", "--for=condition=available", "deploy/static-server")
}

func createClient(t *testing.T, options *k8s.KubectlOptions) {
	helpers.KubectlApply(t, options, "fixtures/static-client.yaml")

	helpers.Cleanup(t, func() {
		// Note: this delete command won't wait for pods to be fully terminated.
		// This shouldn't cause any test pollution because the underlying
		// objects are deployments, and so when other tests create these
		// they should have different pod names.
		helpers.KubectlDelete(t, options, "fixtures/static-client.yaml")
	})

	// Wait for both deployments
	helpers.RunKubectl(t, options, "wait", "--for=condition=available", "deploy/static-client")
}

// checkConnection checks if static-client can talk to static-server.
// If expectSuccess is true, it will expect connection to succeed,
// otherwise it will expect failure due to intentions.
func checkConnection(t *testing.T, options *k8s.KubectlOptions, client kubernetes.Interface, expectSuccess bool) {
	pods, err := client.CoreV1().Pods(options.Namespace).List(metav1.ListOptions{LabelSelector: "app=static-client"})
	require.NoError(t, err)
	require.Len(t, pods.Items, 1, fmt.Sprintf("expected to find at least one static-client pod, but found %d", len(pods.Items)))

	retrier := &retry.Timer{
		Timeout: 20 * time.Second,
		Wait:    500 * time.Millisecond,
	}
	retry.RunWith(retrier, t, func(r *retry.R) {
		output, err := helpers.RunKubectlAndGetOutputE(t, options, "exec", pods.Items[0].Name, "-c", "static-client", "--", "curl", "-vvvsf", "http://127.0.0.1:1234/")
		if expectSuccess {
			require.NoError(r, err)
			require.Contains(r, output, "hello world")
		} else {
			require.Error(t, err)
			require.Contains(t, output, "503 Service Unavailable")
		}
	})
}
