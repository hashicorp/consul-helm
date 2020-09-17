package healthchecks

import (
	"testing"
	"time"

	"github.com/hashicorp/consul-helm/test/acceptance/framework"
	"github.com/hashicorp/consul-helm/test/acceptance/helpers"
	"github.com/hashicorp/consul/api"
	"github.com/stretchr/testify/require"
)

const staticClientName = "static-client"

// Tests:
// 1. Test that health checks enabled by default works for passing+failing
// 2. Test that health checks enabled with TLS/ACL works for passing+failing
// 3. Test that health checks enabled + deployment without health checks makes no changes in behaviour
// TODO: #3 is covered as a happy-path test with #1

// Test that health checks work in a default installation
// Workflow is as follows :
// Deploy with a failing health check
// Test that traffic fails
// kubectl exec to the static-client and `touch /tmp/healthy`
// Test that traffic passes
func TestHealthChecksDefault(t *testing.T) {
	cfg := suite.Config()
	ctx := suite.Environment().DefaultContext(t)

	helmValues := map[string]string{
		"global.imageK8S":                    "kschoche/consul-k8s-dev",
		"connectInject.enabled":              "true",
		"connectInject.healthChecks.enabled": "true",
	}

	releaseName := helpers.RandomName()
	consulCluster := framework.NewHelmCluster(t, helmValues, ctx, cfg, releaseName)
	consulCluster.Create(t)

	t.Log("creating static-server and static-client deployments")
	helpers.DeployKustomize(t, ctx.KubectlOptions(), cfg.NoCleanupOnFailure, cfg.DebugDirectory, "../fixtures/cases/static-server-inject")
	helpers.DeployKustomize(t, ctx.KubectlOptions(), cfg.NoCleanupOnFailure, cfg.DebugDirectory, "../fixtures/cases/static-client-inject")
	// The readiness probe takes 2s to report success
	t.Log("checking that connection is successful")
	helpers.CheckStaticServerConnection(t, ctx.KubectlOptions(), true, staticClientName, "http://localhost:1234")

	// Now remove the file so that the health check fails
	helpers.RunKubectl(t, ctx.KubectlOptions(), "exec", "-it", staticClientName, "--", "rm /tmp/healthy")

	// The readiness probe should take a few seconds to populate consul, CheckStaticServerConnection retries until it fails
	t.Log("checking that connection is successful")
	helpers.CheckStaticServerConnection(t, ctx.KubectlOptions(), false, staticClientName, "http://localhost:1234")
}

// Test that Connect works in a secure installation,
// with ACLs and TLS enabled.
func TestHealthChecksSecure(t *testing.T) {
	cases := []struct {
		name              string
		enableAutoEncrypt string
	}{
		{
			"without auto-encrypt",
			"false",
		},
		{
			"with auto-encrypt",
			"true",
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			cfg := suite.Config()
			ctx := suite.Environment().DefaultContext(t)

			helmValues := map[string]string{
				"global.imageK8S":                    "kschoche/consul-k8s-dev",
				"connectInject.enabled":              "true",
				"global.tls.enabled":                 "true",
				"global.tls.enableAutoEncrypt":       c.enableAutoEncrypt,
				"global.acls.manageSystemACLs":       "true",
				"connectInject.healthChecks.enabled": "true",
			}

			releaseName := helpers.RandomName()
			consulCluster := framework.NewHelmCluster(t, helmValues, ctx, cfg, releaseName)

			consulCluster.Create(t)

			t.Log("creating static-server and static-client deployments")
			helpers.DeployKustomize(t, ctx.KubectlOptions(), cfg.NoCleanupOnFailure, cfg.DebugDirectory, "../fixtures/cases/static-server-inject")
			helpers.DeployKustomize(t, ctx.KubectlOptions(), cfg.NoCleanupOnFailure, cfg.DebugDirectory, "../fixtures/cases/static-client-inject")

			consulClient := consulCluster.SetupConsulClient(t, true)

			t.Log("creating intention")
			_, _, err := consulClient.Connect().IntentionCreate(&api.Intention{
				SourceName:      staticClientName,
				DestinationName: "static-server",
				Action:          api.IntentionActionAllow,
			}, nil)
			require.NoError(t, err)

			// The readiness probe should take a second or two to trigger success
			time.Sleep(time.Second * 8)
			t.Log("checking that connection is successful")
			helpers.CheckStaticServerConnection(t, ctx.KubectlOptions(), true, staticClientName, "http://localhost:1234")

			helpers.RunKubectl(t, ctx.KubectlOptions(), "exec", "-it", staticClientName, "--", "rm /tmp/healthy")

			// The readiness probe takes  2s to fail
			time.Sleep(time.Second * 8)
			t.Log("checking that the health check has caused the connect to be failed")
			helpers.CheckStaticServerConnection(t, ctx.KubectlOptions(), false, staticClientName, "http://localhost:1234")

		})
	}
}
