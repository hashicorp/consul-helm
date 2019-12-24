package framework

import (
	"fmt"
	"io/ioutil"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/hashicorp/consul-helm/test/acceptance/helpers"
	"github.com/hashicorp/consul/api"
	"github.com/hashicorp/consul/sdk/freeport"
	"github.com/stretchr/testify/require"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type Cluster interface {
	Create(t *testing.T)
	Destroy(t *testing.T)
}

type HelmCluster struct {
	helmOptions *helm.Options
	releaseName string
}

func NewHelmCluster(helmOptions *helm.Options, releaseName string) Cluster {
	return &HelmCluster{
		helmOptions: helmOptions,
		releaseName: releaseName,
	}
}

func (h *HelmCluster) Create(t *testing.T) {
	helm.Install(t, h.helmOptions, helpers.HelmChartPath, h.releaseName)
	// todo: replace this with helm install --wait
	helpers.WaitForAllPodsToBeReady(t, h.helmOptions.KubectlOptions, fmt.Sprintf("release=%s", h.releaseName))
}

func (h *HelmCluster) Destroy(t *testing.T) {
	helpers.HelmDelete(t, h.helmOptions, h.helmOptions.KubectlOptions.Namespace, h.releaseName)

	// delete PVCs
	k8sClient, err := k8s.GetKubernetesClientFromOptionsE(t, h.helmOptions.KubectlOptions)
	require.NoError(t, err)

	k8sClient.CoreV1().PersistentVolumeClaims(h.helmOptions.KubectlOptions.Namespace).DeleteCollection(&metav1.DeleteOptions{}, metav1.ListOptions{LabelSelector: "release="+h.releaseName})

	// delete any secrets that have h.releaseName in their name
	secrets, err := k8sClient.CoreV1().Secrets(h.helmOptions.KubectlOptions.Namespace).List(metav1.ListOptions{})
	require.NoError(t, err)
	for _, secret := range secrets.Items {
		if strings.Contains(secret.Name, h.releaseName) {
			err := k8sClient.CoreV1().Secrets(h.helmOptions.KubectlOptions.Namespace).Delete(secret.Name, nil)
			require.NoError(t, err)
		}
	}
}

func (h *HelmCluster) Upgrade() {
	panic("implement me")
}

func (h *HelmCluster) SetupConsulClient(t *testing.T, secure bool) (*api.Client, int) {
	namespace := h.helmOptions.KubectlOptions.Namespace
	config := api.DefaultConfig()
	port := freeport.MustTake(1)[0]

	if secure {
		// get the CA
		k8sClient, err := k8s.GetKubernetesClientFromOptionsE(t, h.helmOptions.KubectlOptions)
		require.NoError(t, err)

		caSecret, err := k8sClient.CoreV1().Secrets(namespace).Get(h.releaseName+"-consul-ca-cert", metav1.GetOptions{})
		require.NoError(t, err)
		caFile, err := ioutil.TempFile("", "")
		require.NoError(t, err)
		if caContents, ok := caSecret.Data["tls.crt"]; ok {
			_, err := caFile.Write(caContents)
			require.NoError(t, err)
		}

		// get the ACL token
		aclSecret, err := k8sClient.CoreV1().Secrets(namespace).Get(h.releaseName+"-consul-bootstrap-acl-token", metav1.GetOptions{})
		require.NoError(t, err)

		config.TLSConfig.CAFile = caFile.Name()
		config.Token = string(aclSecret.Data["token"])
		config.Scheme = "https"
	}
	config.Address = fmt.Sprintf("127.0.0.1:%d", port)
	consulClient, err := api.NewClient(config)
	require.NoError(t, err)

	return consulClient, port
}
