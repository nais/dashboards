.PHONY: all install compile deploy

all: install compile deploy

install:
	jb install

fmt:
	jsonnetfmt -i src/*.libsonnet

compile:
	jsonnet -J vendor src/ingress-main.libsonnet > dasbhoards/ingress.json

deploy:
	grr apply grr.jsonnet