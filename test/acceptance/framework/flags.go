package framework

import (
	"flag"
	"sync"
)

type TestFlags struct {
	flagFoo string
	flagBar string

	once sync.Once
}

func NewTestFlags() *TestFlags {
	t := &TestFlags{}
	t.once.Do(t.init)

	return t
}

func (t *TestFlags) init() {
	flag.StringVar(&t.flagFoo, "foo", "", "foo")
	flag.StringVar(&t.flagBar, "bar", "", "bar")
}