package helpers

import (
	"fmt"
	"testing"
	"time"
)

// Log logs using `t.Log` prefixed with a timestamp.
func Log(t *testing.T, msg string) {
	Logf(t, "%s", msg)
}

// Logf logs using `t.Logf` prefixed with a timestamp.
func Logf(t *testing.T, pattern string, args ...interface{}) {
	t.Logf("%s: %s", time.Now().Format("15:04:05"), fmt.Sprintf(pattern, args...))
}
