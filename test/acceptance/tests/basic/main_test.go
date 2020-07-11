package basic

import (
	"os"
	"testing"

	"github.com/hashicorp/consul-helm/test/acceptance/framework"
)

var suite framework.Suite

func TestMain(m *testing.M) {
	// parse flags
	//flags := framework.NewTestFlags()
	//
	//flag.Parse()
	//
	//fmt.Println("flags:", flags)

	suite = framework.NewSuite(m)

	os.Exit(suite.Run())
}
