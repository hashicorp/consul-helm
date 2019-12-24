package acceptance

import (
	"flag"
	"os"
	"testing"

	"github.com/hashicorp/consul-helm/test/acceptance/framework"
)

type testConfig struct {
	pathToKubeConfig string
	kubeContext      string
}

var Config testConfig

var TestEnvironments framework.KubernetesEnvironments

func TestMain(m *testing.M) {
	// These flags can be passed in via 'go test -args foo=bar'
	// todo: add flags
	flag.Parse()
	TestEnvironments = append(TestEnvironments, framework.NewDefaultEnvironment())
	os.Exit(m.Run())
}
