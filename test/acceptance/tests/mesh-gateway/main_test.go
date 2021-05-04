package meshgateway

import (
	"fmt"
	"os"
	"testing"

	testsuite "github.com/hashicorp/consul-helm/test/acceptance/framework/suite"
)

var suite testsuite.Suite

func TestMain(m *testing.M) {
	suite = testsuite.NewSuite(m)

	// We don't want to run these tests when transparent proxy is enabled since multi-cluster is not yet supported.
	if suite.Config().EnableMultiCluster && !suite.Config().EnableTransparentProxy {
		os.Exit(suite.Run())
	} else {
		fmt.Println("Skipping mesh gateway tests because -enable-multi-cluster is not set")
		os.Exit(0)
	}
}
