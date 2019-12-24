package acceptance

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/hashicorp/consul-helm/test/acceptance/framework"
	"github.com/stretchr/testify/require"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/intstr"
	"k8s.io/client-go/kubernetes"
)

func TestSyncCatalogDefault(t *testing.T) {
	env, err := TestEnvironments.GetDefaultEnvironment()
	require.NoError(t, err)
	helmOptions := &helm.Options{
		KubectlOptions: env.GetKubectlOptions(),
		SetValues: map[string]string{
			"syncCatalog.enabled": "true",
		},
	}

	releaseName := fmt.Sprintf("consul-%s", strings.ToLower(random.UniqueId()))
	consulCluster := framework.NewHelmCluster(helmOptions, releaseName)

	consulCluster.Create(t)
	defer consulCluster.Destroy(t)

	k8sClient, err := k8s.GetKubernetesClientE(t)
	require.NoError(t, err)

	cleanup := createTestService(t, k8sClient, releaseName)
	defer cleanup()

	consulClient, localPort := consulCluster.(*framework.HelmCluster).SetupConsulClient(t, false)

	tunnel := k8s.NewTunnel(env.GetKubectlOptions(), k8s.ResourceTypePod, fmt.Sprintf("%s-consul-server-0", releaseName), localPort, 8500)
	tunnel.ForwardPort(t)
	defer tunnel.Close()

	var services map[string][]string
	retry.DoWithRetry(t, "waiting for kubernetes service to be synced to Consul", 10, 5*time.Second, func() (string, error) {
		services, _, err = consulClient.Catalog().Services(nil)
		if _, ok := services["test-service-default"]; !ok {
			return "", fmt.Errorf("service '%s' is not in Consul's list of services %s", "test-service", services)
		}
		return "", err
	})
	service, _, err := consulClient.Catalog().Service("test-service-default", "", nil)
	require.NoError(t, err)
	require.Equal(t, 1, len(service))
	require.Equal(t, []string{"k8s"}, service[0].ServiceTags)
}

func TestSyncCatalogSecure(t *testing.T) {
	env, err := TestEnvironments.GetDefaultEnvironment()
	require.NoError(t, err)

	helmOptions := &helm.Options{
		KubectlOptions: env.GetKubectlOptions(),
		SetValues: map[string]string{
			"syncCatalog.enabled":          "true",
			"global.tls.enabled":           "true",
			"global.acls.manageSystemACLs": "true",
		},
	}

	releaseName := fmt.Sprintf("consul-%s", strings.ToLower(random.UniqueId()))
	consulCluster := framework.NewHelmCluster(helmOptions, releaseName)

	consulCluster = framework.NewHelmCluster(helmOptions, releaseName)
	consulCluster.Create(t)
	defer consulCluster.Destroy(t)

	k8sClient, err := k8s.GetKubernetesClientE(t)
	require.NoError(t, err)

	cleanup := createTestService(t, k8sClient, releaseName)
	defer cleanup()

	consulClient, localPort := consulCluster.(*framework.HelmCluster).SetupConsulClient(t, true)

	tunnel := k8s.NewTunnel(env.GetKubectlOptions(), k8s.ResourceTypePod, fmt.Sprintf("%s-consul-server-0", releaseName), localPort, 8501)
	tunnel.ForwardPort(t)
	defer tunnel.Close()

	var services map[string][]string
	retry.DoWithRetry(t, "waiting for kubernetes service to be synced to Consul", 10, 5*time.Second, func() (string, error) {
		services, _, err = consulClient.Catalog().Services(nil)
		if _, ok := services["test-service-default"]; !ok {
			return "", fmt.Errorf("service '%s' is not in Consul's list of services %s", "test-service", services)
		}
		return "", err
	})
	service, _, err := consulClient.Catalog().Service("test-service-default", "", nil)
	require.NoError(t, err)
	require.Equal(t, 1, len(service))
	require.Equal(t, []string{"k8s"}, service[0].ServiceTags)
}

func createTestService(t *testing.T, k8sClient *kubernetes.Clientset, name string) func() {
	// Create a service in k8s and check that it exists in Consul
	svc, err := k8sClient.CoreV1().Services("default").Create(&corev1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name: "test-service",
		},
		Spec: corev1.ServiceSpec{
			Type:     corev1.ServiceTypeNodePort,
			Selector: map[string]string{"app": "test-pod"},
			Ports: []corev1.ServicePort{
				{Name: "http", Port: 80, TargetPort: intstr.FromInt(8080)},
			},
		},
	})
	require.NoError(t, err)

	pod, err := k8sClient.CoreV1().Pods("default").Create(&corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			// todo: create random name
			Name:   "test-pod",
			Labels: map[string]string{"app": "test-pod"},
		},
		Spec: corev1.PodSpec{
			Containers: []corev1.Container{
				{
					// todo: create random name
					Name:  "test-container",
					Image: "hashicorp/http-echo:latest",
					Args: []string{
						`-text="hello world"`,
						`-listen=:8080`,
					},
					Ports: []corev1.ContainerPort{
						{
							Name:          "http",
							ContainerPort: 8080,
						},
					},
				},
			},
		},
	})
	require.NoError(t, err)
	return func() {
		k8sClient.CoreV1().Services("default").Delete(svc.Name, nil)
		k8sClient.CoreV1().Pods("default").Delete(pod.Name, nil)
	}
}
