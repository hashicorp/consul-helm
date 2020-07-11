package framework

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/stretchr/testify/require"
	"k8s.io/client-go/kubernetes"
)

type TestEnvironment interface {
	DefaultContext() TestContext
	Context(name string) TestContext
}

type TestContext interface {
	KubectlOptions() *k8s.KubectlOptions
	KubernetesClient(t *testing.T) *kubernetes.Clientset
}

// todo: add docs
type kubernetesContext struct {
	// todo: add docs
	name             string
	pathToKubeConfig string
	contextName      string
	namespace        string
}

func (k kubernetesContext) KubectlOptions() *k8s.KubectlOptions {
	return &k8s.KubectlOptions{
		ContextName: k.contextName,
		ConfigPath:  k.pathToKubeConfig,
		Namespace:   k.namespace,
	}
}

func (k kubernetesContext) KubernetesClient(t *testing.T) *kubernetes.Clientset {
	configPath, err := k.KubectlOptions().GetConfigPath(t)
	require.NoError(t, err)

	config, err := k8s.LoadApiClientConfigE(configPath, k.contextName)
	require.NoError(t, err)

	client, err := kubernetes.NewForConfig(config)
	require.NoError(t, err)

	return client
}

func NewDefaultContext() *kubernetesContext {
	return &kubernetesContext{
		name:      "default",
		namespace: "default",
	}
}

func NewContext(name, namespace, pathToKubeConfig, contextName string) *kubernetesContext {
	return &kubernetesContext{
		name:             name,
		namespace:        namespace,
		pathToKubeConfig: pathToKubeConfig,
		contextName:      contextName,
	}
}

type kubernetesEnvironment struct {
	contexts map[string]*kubernetesContext
}

func (k *kubernetesEnvironment) Context(name string) TestContext {
	// todo: might need to error here
	return k.contexts[name]
}

func (k *kubernetesEnvironment) DefaultContext() TestContext {
	// todo: might need to make it a constant
	return k.contexts["default"]
}
