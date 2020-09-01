package connect

import (
	"strconv"
	"testing"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/hashicorp/consul-helm/test/acceptance/framework"
	"github.com/hashicorp/consul-helm/test/acceptance/helpers"
	"github.com/hashicorp/consul/api"
	"github.com/stretchr/testify/require"
)

const staticServerNamespace = "ns1"
const staticClientNamespace = "ns2"

// Test that Connect works in a default installation
func TestConnectInjectNamespaces(t *testing.T) {
	cfg := suite.Config()
	if !cfg.EnableEnterprise {
		t.Skipf("skipping this test because -enable-enterprise is not set")
	}

	cases := []struct {
		name                 string
		destinationNamespace string
		mirrorK8S            bool
		secure               bool
	}{
		{
			"single destination namespace (non-default)",
			staticServerNamespace,
			false,
			false,
		},
		{
			"single destination namespace (non-default); secure",
			staticServerNamespace,
			false,
			true,
		},
		{
			"mirror k8s namespaces",
			staticServerNamespace,
			true,
			false,
		},
		{
			"mirror k8s namespaces; secure",
			staticServerNamespace,
			true,
			true,
		},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// todo: add an assertion that the services are created in the right namespace
			ctx := suite.Environment().DefaultContext(t)

			helmValues := map[string]string{
				"global.enableConsulNamespaces":                             "true",
				"connectInject.enabled":                                     "true",
				"connectInject.consulNamespaces.consulDestinationNamespace": c.destinationNamespace,
				"connectInject.consulNamespaces.mirroringK8S":               strconv.FormatBool(c.mirrorK8S),

				"global.acls.manageSystemACLs": strconv.FormatBool(c.secure),
				"global.tls.enabled":           strconv.FormatBool(c.secure),
			}

			releaseName := helpers.RandomName()
			consulCluster := framework.NewHelmCluster(t, helmValues, ctx, cfg, releaseName)

			consulCluster.Create(t)

			staticServerOpts := &k8s.KubectlOptions{
				ContextName: ctx.KubectlOptions().ContextName,
				ConfigPath:  ctx.KubectlOptions().ConfigPath,
				Namespace:   staticServerNamespace,
			}
			staticClientOpts := &k8s.KubectlOptions{
				ContextName: ctx.KubectlOptions().ContextName,
				ConfigPath:  ctx.KubectlOptions().ConfigPath,
				Namespace:   staticClientNamespace,
			}

			t.Logf("creating namespaces %s and %s", staticServerNamespace, staticClientNamespace)
			helpers.RunKubectl(t, ctx.KubectlOptions(), "create", "ns", staticServerNamespace)
			helpers.Cleanup(t, cfg.NoCleanupOnFailure, func() {
				helpers.RunKubectl(t, ctx.KubectlOptions(), "delete", "ns", staticServerNamespace)
			})

			helpers.RunKubectl(t, ctx.KubectlOptions(), "create", "ns", staticClientNamespace)
			helpers.Cleanup(t, cfg.NoCleanupOnFailure, func() {
				helpers.RunKubectl(t, ctx.KubectlOptions(), "delete", "ns", staticClientNamespace)
			})

			t.Log("creating static-server and static-client deployments")
			helpers.DeployKustomize(t, staticServerOpts, cfg.NoCleanupOnFailure, cfg.DebugDirectory, "../fixtures/cases/static-server-inject")
			helpers.DeployKustomize(t, staticClientOpts, cfg.NoCleanupOnFailure, cfg.DebugDirectory, "../fixtures/cases/static-client-namespaces")

			if c.secure {
				t.Log("checking that the connection is not successful because there's no intention")
				helpers.CheckStaticServerConnection(t, staticClientOpts, false, staticClientName, "http://localhost:1234")

				consulClient := consulCluster.SetupConsulClient(t, c.secure)
				intention := &api.Intention{
					SourceName:      staticClientName,
					SourceNS:        staticClientNamespace,
					DestinationName: "static-server",
					DestinationNS:   staticServerNamespace,
					Action:          api.IntentionActionAllow,
				}

				// Set the destination namespace to be the same
				// unless mirrorK8S is true.
				if !c.mirrorK8S {
					intention.SourceNS = c.destinationNamespace
					intention.DestinationNS = c.destinationNamespace
				}

				t.Log("creating intention")
				_, _, err := consulClient.Connect().IntentionCreate(intention, nil)
				require.NoError(t, err)
			}

			t.Log("checking that connection is successful")
			helpers.CheckStaticServerConnection(t, staticClientOpts, true, staticClientName, "http://localhost:1234")
		})
	}
}
