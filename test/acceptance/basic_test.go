package acceptance

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/hashicorp/consul-helm/test/acceptance/helpers"
	"github.com/stretchr/testify/require"
)

func TestDefaultInstallation(t *testing.T) {
	env, err := TestEnvironments.GetDefaultEnvironment()
	require.NoError(t, err)
	options := &helm.Options{
		KubectlOptions: env.GetKubectlOptions(),
	}

	releaseName := fmt.Sprintf("consul-%s", strings.ToLower(random.UniqueId()))
	defer helpers.HelmDelete(t, options, "default", releaseName)

	helm.Install(t, options, helpers.HelmChartPath, releaseName)
	helpers.WaitForAllPodsToBeReady(t, env.GetKubectlOptions(), fmt.Sprintf("release=%s", releaseName))

	// Run `helm test` to make sure the consul cluster is installed successfully
	output, err := helm.RunHelmCommandAndGetOutputE(t, options, "test", releaseName)
	require.NoError(t, err)
	require.Contains(t, output, fmt.Sprintf("Pod %s-consul-test succeeded", releaseName))
	// todo: delete this pod once we're done
}
