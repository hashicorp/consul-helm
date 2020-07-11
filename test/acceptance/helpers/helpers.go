package helpers

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/hashicorp/consul/sdk/testutil/retry"
	"github.com/stretchr/testify/require"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

func RandomName() string {
	return fmt.Sprintf("test-%s", strings.ToLower(random.UniqueId()))
}

// todo: update docs
// WaitForAllPodsToBeReady waits until all pods in a release called 'releaseName'
// are in the ready status. It checks every 5 seconds for a total of 10 tries.
// If there is at least one container in a pod that isn't ready after that,
// it fails the test.
func WaitForAllPodsToBeReady(t *testing.T, client *kubernetes.Clientset, namespace, podLabelSelector string) {
	counter := &retry.Counter{Count: 20, Wait: 5*time.Second}
	retry.RunWith(counter, t, func(r *retry.R) {
		pods, err := client.CoreV1().Pods(namespace).List(metav1.ListOptions{LabelSelector: podLabelSelector})
		require.NoError(r, err)
		var numNotReadyContainers int
		var totalNumContainers int
		for _, pod := range pods.Items {
			if len(pod.Status.ContainerStatuses) == 0 {
				r.Errorf("pod %s is pending", pod.Name)
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
			r.Errorf("%d out of %d containers are ready", totalNumContainers-numNotReadyContainers, totalNumContainers)
		}
	})
}
