package framework

import (
	"errors"

	"github.com/gruntwork-io/terratest/modules/k8s"
)

// todo: add docs
type KubernetesEnvironment struct {
	// todo: add docs
	PathToKubeConfig           string
	Context                    string
	Namespace                  string
	Default                    bool
	PodSecurityPoliciesEnabled bool
	IsSecondaryCluster         bool
}

type KubernetesEnvironments []KubernetesEnvironment

func NewDefaultEnvironment() KubernetesEnvironment {
	return KubernetesEnvironment{
		Namespace: "default",
		Default:   true,
	}
}

func (k KubernetesEnvironment) GetKubectlOptions() *k8s.KubectlOptions {
	return &k8s.KubectlOptions{
		ContextName: k.Context,
		ConfigPath:  k.PathToKubeConfig,
		Namespace:   k.Namespace,
		Env:         nil,
	}
}
func (k KubernetesEnvironments) GetDefaultEnvironment() (KubernetesEnvironment, error) {
	for _, e := range k {
		if e.Default {
			return e, nil
		}
	}
	return KubernetesEnvironment{}, errors.New("default environment is not found")
}

func (k KubernetesEnvironments) GetPSPEnabledEnvironment() (KubernetesEnvironment, error) {
	for _, e := range k {
		if e.PodSecurityPoliciesEnabled {
			return e, nil
		}
	}
	return KubernetesEnvironment{}, errors.New("PSP enabled environment is not found")
}

func (k KubernetesEnvironments) GetSecondaryEnvironment() (KubernetesEnvironment, error) {
	for _, e := range k {
		if e.IsSecondaryCluster {
			return e, nil
		}
	}
	return KubernetesEnvironment{}, errors.New("secondary cluster environment is not found")
}
