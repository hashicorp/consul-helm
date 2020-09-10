package controller

import (
	"strconv"
	"testing"
	"time"

	"github.com/hashicorp/consul-helm/test/acceptance/framework"
	"github.com/hashicorp/consul-helm/test/acceptance/helpers"
	"github.com/hashicorp/consul/api"
	"github.com/hashicorp/consul/sdk/testutil/retry"
	"github.com/stretchr/testify/require"
)

const (
	KubeNS       = "ns1"
	ConsulDestNS = "from-k8s"
)

// Test that the controller works with Consul Enterprise namespaces.
// These tests currently only test non-secure and secure without auto-encrypt installations
// because in the case of namespaces there isn't a significant distinction in code between auto-encrypt
// and non-auto-encrypt secure installations, so testing just one is enough.
func TestControllerNamespaces(t *testing.T) {
	cfg := suite.Config()
	if !cfg.EnableEnterprise {
		t.Skipf("skipping this test because -enable-enterprise is not set")
	}

	// todo: remove when cert pr merged.
	helpers.RunKubectl(t, suite.Environment().DefaultContext(t).KubectlOptions(), "apply", "--validate=false", "-f", "https://github.com/jetstack/cert-manager/releases/download/v0.15.2/cert-manager-legacy.yaml")

	cases := []struct {
		name                 string
		destinationNamespace string
		mirrorK8S            bool
		secure               bool
	}{
		{
			"single destination namespace (non-default)",
			ConsulDestNS,
			false,
			false,
		},
		{
			"single destination namespace (non-default); secure",
			ConsulDestNS,
			false,
			true,
		},
		{
			"mirror k8s namespaces",
			KubeNS,
			true,
			false,
		},
		{
			"mirror k8s namespaces; secure",
			KubeNS,
			true,
			true,
		},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			ctx := suite.Environment().DefaultContext(t)

			helmValues := map[string]string{
				"global.enableConsulNamespaces": "true",
				// todo: remove
				"global.imageK8S": "lkysow/consul-k8s-dev:sep09-crd-ent6",
				// todo: end
				"controller.enabled":    "true",
				"connectInject.enabled": "true",
				// When mirroringK8S is set, this setting is ignored.
				"connectInject.consulNamespaces.consulDestinationNamespace": c.destinationNamespace,
				"connectInject.consulNamespaces.mirroringK8S":               strconv.FormatBool(c.mirrorK8S),

				"global.acls.manageSystemACLs": strconv.FormatBool(c.secure),
				"global.tls.enabled":           strconv.FormatBool(c.secure),
			}

			releaseName := helpers.RandomName()
			consulCluster := framework.NewHelmCluster(t, helmValues, ctx, cfg, releaseName)

			consulCluster.Create(t)

			t.Logf("creating namespace %q", KubeNS)
			helpers.RunKubectl(t, ctx.KubectlOptions(), "create", "ns", KubeNS)
			helpers.Cleanup(t, cfg.NoCleanupOnFailure, func() {
				helpers.RunKubectl(t, ctx.KubectlOptions(), "delete", "ns", KubeNS)
			})

			t.Log("creating service-default CRD")
			helpers.RunKubectl(t, ctx.KubectlOptions(), "apply", "-n", KubeNS, "-f", "../fixtures/crds")
			helpers.Cleanup(t, cfg.NoCleanupOnFailure, func() {
				helpers.RunKubectl(t, ctx.KubectlOptions(), "delete", "-n", KubeNS, "-f", "../fixtures/crds")
			})

			consulClient := consulCluster.SetupConsulClient(t, c.secure)

			// Make sure that config entries are created in the correct namespace.
			// If mirroring is enabled, we expect config entries to be created in the
			// Consul namespace with the same name as their source
			// Kubernetes namespace.
			// If a single destination namespace is set, we expect all config entries
			// to be created in that destination Consul namespace.
			queryOpts := &api.QueryOptions{Namespace: KubeNS}
			if !c.mirrorK8S {
				queryOpts = &api.QueryOptions{Namespace: c.destinationNamespace}
			}

			// The config entry should be created almost instantly, but wait up to 2s.
			counter := &retry.Counter{Count: 10, Wait: 200 * time.Millisecond}
			retry.RunWith(counter, t, func(r *retry.R) {
				entry, _, err := consulClient.ConfigEntries().Get(api.ServiceDefaults, "foo", queryOpts)
				require.NoError(r, err, "ns: %s", queryOpts.Namespace)

				svcDefaultEntry, ok := entry.(*api.ServiceConfigEntry)
				require.True(r, ok, "could not cast to ServiceConfigEntry")
				require.Equal(r, "http", svcDefaultEntry.Protocol)
			})
		})
	}
}
