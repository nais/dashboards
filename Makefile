.PHONY: all install fmt compile check deploy

all: install compile deploy

install:
	jb install

fmt:
	jsonnetfmt -i src/*.libsonnet

compile:
	jsonnet -J vendor src/ingress-main.libsonnet > dashboards/ingress.json
	mkdir -p dashboards/monitoring
	jsonnet -J vendor -m dashboards/monitoring src/monitoring-main.libsonnet

deploy:
	grr apply grr.jsonnet

# Read-only checks; do not rewrite the checked-in generated files.
check:
	jsonnetfmt --test src/*.libsonnet
	@set -e; tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; \
		jsonnet -J vendor -m "$$tmp" src/monitoring-main.libsonnet; \
		diff -ru dashboards/monitoring "$$tmp"
