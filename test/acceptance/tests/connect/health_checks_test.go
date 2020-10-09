package connect

import (
	"fmt"
	"github.com/hashicorp/consul-helm/test/acceptance/framework"
	"github.com/hashicorp/consul-helm/test/acceptance/helpers"
	"strconv"
	"testing"
)

// TestHealthChecksSecure that health checks work in a default installation with TLS/autoencrypt permutations
// Deploy with a passing health check
// Test that traffic passes
// update the container with readiness probe so that it fails
// Test that traffic now fails
func TestHealthChecksSecure(t *testing.T) {
	cases := []struct {
		secure      bool
		autoEncrypt bool
	}{
		{
			false,
			false,
		},
		{
			true,
			true,
		},
		{
			true,
			true,
		},
	}

	for _, c := range cases {
		name := fmt.Sprintf("secure: %t, auto-encrypt: %t", c.secure, c.autoEncrypt)
		t.Run(name, func(t *testing.T) {
			ctx := suite.Environment().DefaultContext(t)
			cfg := suite.Config()

			helmValues := map[string]string{
				"global.imageK8S":                    "kschoche/consul-k8s-dev",
				"connectInject.enabled":              "true",
				"connectInject.healthChecks.enabled": "true",
				"global.tls.enabled":                 strconv.FormatBool(c.secure),
				"global.tls.autoEncrypt":             strconv.FormatBool(c.autoEncrypt),
			}

			releaseName := helpers.RandomName()
			consulCluster := framework.NewHelmCluster(t, helmValues, ctx, cfg, releaseName)
			consulCluster.Create(t)

			t.Log("creating static-server and static-client deployments")
			helpers.DeployKustomize(t, ctx.KubectlOptions(t), cfg.NoCleanupOnFailure, cfg.DebugDirectory, "../fixtures/cases/static-server-hc")
			helpers.DeployKustomize(t, ctx.KubectlOptions(t), cfg.NoCleanupOnFailure, cfg.DebugDirectory, "../fixtures/cases/static-client-inject")
			t.Log("checking that connection is successful")
			helpers.CheckStaticServerConnection(t, ctx.KubectlOptions(t), true, staticClientName, "http://localhost:1234")

			// Now remove the file so that the health check fails
			helpers.RunKubectl(t, ctx.KubectlOptions(t), "exec", "-it", "deploy/"+staticServerName, "--", "touch", "/tmp/unhealthy")

			// The readiness probe should take a few seconds to populate consul, CheckStaticServerConnection retries until it fails
			t.Log("checking that connection is unsuccessful")
			helpers.CheckStaticServerConnection(t, ctx.KubectlOptions(t), false, staticClientName, "http://localhost:1234")
		})
	}
}
