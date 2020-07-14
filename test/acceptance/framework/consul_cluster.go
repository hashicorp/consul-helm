package framework

import (
	"fmt"
	"io/ioutil"
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/hashicorp/consul-helm/test/acceptance/helpers"
	"github.com/hashicorp/consul/api"
	"github.com/hashicorp/consul/sdk/freeport"
	"github.com/stretchr/testify/require"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

type Cluster interface {
	Create(t *testing.T)
	Destroy(t *testing.T)
	Upgrade(t *testing.T, vals map[string]string)
	SetupConsulClient(t *testing.T, secure bool) (*api.Client)
}

type HelmCluster struct {
	helmOptions *helm.Options
	releaseName string
	kubernetesClient *kubernetes.Clientset
}

func NewHelmCluster(t *testing.T, helmValues map[string]string, ctx TestContext, releaseName string) Cluster {
	opts := &helm.Options{
		SetValues:      helmValues,
		KubectlOptions: ctx.KubectlOptions(),
		Logger:         logger.TestingT,
	}
	return &HelmCluster{
		helmOptions: opts,
		releaseName: releaseName,
		kubernetesClient: ctx.KubernetesClient(t),
	}
}

func (h *HelmCluster) Create(t *testing.T) {
	// todo: don't hard-code helm-chart path like this
	helm.Install(t, h.helmOptions, "../../../..", h.releaseName)
	t.Cleanup(func() {
		if !t.Failed() {
			h.Destroy(t)
		}
	})
	// todo: replace this with helm install --wait
	helpers.WaitForAllPodsToBeReady(t, h.kubernetesClient, h.helmOptions.KubectlOptions.Namespace, fmt.Sprintf("release=%s", h.releaseName))
}

func (h *HelmCluster) Destroy(t *testing.T) {
	helm.Delete(t, h.helmOptions, h.releaseName, false)

	// delete PVCs
	h.kubernetesClient.CoreV1().PersistentVolumeClaims(h.helmOptions.KubectlOptions.Namespace).DeleteCollection(&metav1.DeleteOptions{}, metav1.ListOptions{LabelSelector: "release="+h.releaseName})

	// delete any secrets that have h.releaseName in their name
	secrets, err := h.kubernetesClient.CoreV1().Secrets(h.helmOptions.KubectlOptions.Namespace).List(metav1.ListOptions{})
	require.NoError(t, err)
	for _, secret := range secrets.Items {
		if strings.Contains(secret.Name, h.releaseName) {
			err := h.kubernetesClient.CoreV1().Secrets(h.helmOptions.KubectlOptions.Namespace).Delete(secret.Name, nil)
			require.NoError(t, err)
		}
	}
}

func (h *HelmCluster) Upgrade(t *testing.T, helmValues map[string]string) {
	// todo: don't hard-code helm-chart path like this
	h.helmOptions.SetValues = helmValues
	helm.Upgrade(t, h.helmOptions, "../../../..", h.releaseName)
	// todo: replace this with helm install --wait
	helpers.WaitForAllPodsToBeReady(t, h.kubernetesClient, h.helmOptions.KubectlOptions.Namespace, fmt.Sprintf("release=%s", h.releaseName))
}

func (h *HelmCluster) SetupConsulClient(t *testing.T, secure bool) (*api.Client) {
	namespace := h.helmOptions.KubectlOptions.Namespace
	config := api.DefaultConfig()
	localPort := freeport.MustTake(1)[0]
	remotePort := 8500 // use non-secure by default

	if secure {
		// overwrite remote port to HTTPS
		remotePort = 8501

		// get the CA
		caSecret, err := h.kubernetesClient.CoreV1().Secrets(namespace).Get(h.releaseName+"-consul-ca-cert", metav1.GetOptions{})
		require.NoError(t, err)
		caFile, err := ioutil.TempFile("", "")
		require.NoError(t, err)
		t.Cleanup(func() {
			require.NoError(t, os.Remove(caFile.Name()))
		})

		if caContents, ok := caSecret.Data["tls.crt"]; ok {
			_, err := caFile.Write(caContents)
			require.NoError(t, err)
		}

		// get the ACL token
		aclSecret, err := h.kubernetesClient.CoreV1().Secrets(namespace).Get(h.releaseName+"-consul-bootstrap-acl-token", metav1.GetOptions{})
		require.NoError(t, err)

		config.TLSConfig.CAFile = caFile.Name()
		config.Token = string(aclSecret.Data["token"])
		config.Scheme = "https"
	}

	tunnel := k8s.NewTunnel(h.helmOptions.KubectlOptions, k8s.ResourceTypePod, fmt.Sprintf("%s-consul-server-0", h.releaseName), localPort, remotePort)
	tunnel.ForwardPort(t)

	t.Cleanup(func() {
		tunnel.Close()
	})

	config.Address = fmt.Sprintf("127.0.0.1:%d", localPort)
	consulClient, err := api.NewClient(config)
	require.NoError(t, err)

	return consulClient
}
