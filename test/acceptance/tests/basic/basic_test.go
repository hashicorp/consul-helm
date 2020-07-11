package basic

import (
	"testing"

	"github.com/hashicorp/consul-helm/test/acceptance/framework"
	"github.com/hashicorp/consul-helm/test/acceptance/helpers"
	"github.com/hashicorp/consul/api"
	"github.com/stretchr/testify/require"
)

func TestDefaultInstallation(t *testing.T) {
	releaseName := helpers.RandomName()
	consulCluster := framework.NewHelmCluster(t, nil, suite.Environment().DefaultContext(), releaseName)

	consulCluster.Create(t)

	client := consulCluster.SetupConsulClient(t, false)

	// create a key-value
	randomKey := helpers.RandomName()
	randomValue := []byte(helpers.RandomName())
	_, err := client.KV().Put(&api.KVPair{
		Key:   randomKey,
		Value: randomValue,
	}, nil)
	require.NoError(t, err)

	kv, _, err := client.KV().Get(randomKey, nil)
	require.NoError(t, err)
	require.Equal(t, kv.Value, randomValue)
}
