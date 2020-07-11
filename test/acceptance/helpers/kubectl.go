package helpers

import (
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/testing"
	"github.com/stretchr/testify/require"
)

func KubectlApply(t testing.TestingT, options *k8s.KubectlOptions, configPath string) {
	_, err := RunKubectlAndGetOutputE(t, options, "apply", "-f", configPath)
	require.NoError(t, err)
}

func KubectlDelete(t testing.TestingT, options *k8s.KubectlOptions, configPath string) {
	_, err := RunKubectlAndGetOutputE(t, options, "delete", "-f", configPath)
	require.NoError(t, err)
}

func RunKubectl(t testing.TestingT, options *k8s.KubectlOptions, args ...string) {
	_, err := RunKubectlAndGetOutputE(t, options, args...)
	require.NoError(t, err)
}

func RunKubectlAndGetOutputE(t testing.TestingT, options *k8s.KubectlOptions, args ...string) (string, error) {
	cmdArgs := []string{}
	if options.ContextName != "" {
		cmdArgs = append(cmdArgs, "--context", options.ContextName)
	}
	if options.ConfigPath != "" {
		cmdArgs = append(cmdArgs, "--kubeconfig", options.ConfigPath)
	}
	if options.Namespace != "" {
		cmdArgs = append(cmdArgs, "--namespace", options.Namespace)
	}
	cmdArgs = append(cmdArgs, args...)
	command := shell.Command{
		Command: "kubectl",
		Args:    cmdArgs,
		Env:     options.Env,
		Logger: logger.TestingT,
	}
	return shell.RunCommandAndGetOutputE(t, command)
}
