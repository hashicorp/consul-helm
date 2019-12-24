package helpers

import (
	"fmt"
	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/stretchr/testify/require"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"testing"
	"time"
)

// HelmDelete calls helm.Delete from the terratest library.
// It also deletes any PVCs associated with the release called 'releaseName'
// ('helm delete' doesn't delete them by basic).
func HelmDelete(t *testing.T, options *helm.Options, namespace, releaseName string) {
	require := require.New(t)
	helm.Delete(t, options, releaseName, true)

	k8sClient, err := k8s.GetKubernetesClientE(t)
	require.NoError(err)

	err = k8sClient.CoreV1().PersistentVolumeClaims(namespace).DeleteCollection(nil, metav1.ListOptions{LabelSelector: fmt.Sprintf("release=%s", releaseName)})
	require.NoError(err)

	err = k8sClient.CoreV1().Pods(namespace).DeleteCollection(nil, metav1.ListOptions{LabelSelector: fmt.Sprintf("release=%s", releaseName)})
	require.NoError(err)
}

// WaitForAllPodsToBeReady waits until all pods in a release called 'releaseName'
// are in the ready status. It checks every 5 seconds for a total of 10 tries.
// If there is at least one container in a pod that isn't ready after that,
// it fails the test.
func WaitForAllPodsToBeReady(t *testing.T, options *k8s.KubectlOptions, podLabelSelector string) {
	retry.DoWithRetry(t, "waiting for pods to be ready", 10, 5*time.Second, func() (string, error) {
		pods := k8s.ListPods(t, options, metav1.ListOptions{LabelSelector: podLabelSelector})
		var numNotReadyContainers int
		var totalNumContainers int
		for _, pod := range pods {
			if len(pod.Status.ContainerStatuses) == 0 {
				return "", fmt.Errorf("pod %s is pending", pod.Name)
			}
			for _, contStatus := range pod.Status.InitContainerStatuses {
				totalNumContainers++
				if !contStatus.Ready {
					numNotReadyContainers++
				}
			}
			for _, contStatus := range pod.Status.ContainerStatuses {
				totalNumContainers++
				if !contStatus.Ready {
					numNotReadyContainers++
				}
			}
		}
		if numNotReadyContainers != 0 {
			return "", fmt.Errorf("%d out of %d containers are ready", totalNumContainers-numNotReadyContainers, totalNumContainers)
		}
		return "", nil
	})
}
