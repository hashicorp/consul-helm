package framework

import "testing"

type suite struct {
	m *testing.M
	env *kubernetesEnvironment
}

type Suite interface {
	Run() int
	Environment() TestEnvironment
}

func NewSuite(m *testing.M) Suite {
	// todo: get this from flags
	ctxs := map[string]*kubernetesContext{
		"default": NewDefaultContext(),
	}

	return &suite{
		m: m,
		env: &kubernetesEnvironment{contexts: ctxs},
	}
}

func (s *suite) Run() int {
	return s.m.Run()
}

func (s *suite) Environment() TestEnvironment {
	return s.env
}