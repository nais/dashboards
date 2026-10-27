# Nais Dashboards

This repository contains Grafana dashboards for monitoring applications running on the NAIS platform.

## Dashboards

- [Ingress Logs](./src/ingress-main.libsonnet): Display logs from the ingress controller for a specific hostname.
- [Nais Postgres – Fleet](./src/postgres-fleet-main.libsonnet): Provider operations for CNPG on `monitoring.nais.io`, using a tenant's `*-metrics` datasource (`nais` Mimir org). Select environment, team, Postgres and branch. Separate from the legacy `dashboards/postgres.json` exporter dashboard.

## Development

Dashboards are defined in [Jsonnet](https://jsonnet.org/) using the [Grafonnet](https://github.com/grafana/grafonnet-lib) library.

Jsonnet is a data templating language that allows you to define complex JSON structures in a more concise and maintainable way. Grafonnet is a Jsonnet library that provides a set of functions and objects for defining Grafana dashboards.

To compile the Jsonnet files into Grafana-compatible JSON files, you can use the `jsonnet` command-line tool. The `jsonnet-bundler` (jb) tool is used to manage dependencies.

### Structure

All dashboards are defined in the `src` directory. The `src` directory contains a set of Jsonnet files that define the dashboards. A helper script `g.libsonnet` is used to import the Grafonnet library.

Most dashboards follow the following structure:

- `src/<dashboard-name>-main.libsonnet`: The main dashboard definition.
- `src/<dashboard-name>-variables.libsonnet`: The variable definitions.
- `src/<dashboard-name>-queries.libsonnet`: The query definitions.
- `src/<dashboard-name>-panels.libsonnet`: The panel definitions.

### Install Dependencies

```bash
make install
```

### Format Jsonnet Files

```bash
make fmt
```

### Compile Dashboards

```bash
make compile
```

### Deploy Dashboards

```bash
make deploy
```

### Nais Postgres fleet dashboard

`make compile` generates `dashboards/monitoring/postgres-fleet.json` in Grafana
App Platform resource format (`dashboard.grafana.app/v1`). The source of truth is
`src/postgres-fleet-{main,queries,variables}.libsonnet`, wrapped by
`src/monitoring-main.libsonnet`; do not edit the JSON by hand. Run `make check`
to check Jsonnet formatting and verify that the generated monitoring resources
match their source without rewriting them.

The overview shows observed primary count, actual streaming replicas, scrape
success, missing SQL telemetry, backup age and worst data-volume usage per branch.
Details include replay lag, WAL backlog/failures/archive age, reported recovery
metadata, memory versus limit, restarts and pgrator reconciliation errors.
Control-plane panels are environment-wide; team/Postgres/branch filters do not
apply to them. The dashboard does not create alerts.

#### Interpretation and limits

- This is **one tenant at a time**, not a cross-tenant inventory. The branch
  inventory comes from currently discovered `up{postgres!=""}` targets, including
  failed scrapes. Databases stuck before discovery and branches whose targets
  have all disappeared are not represented. `Unknown`/missing data is not healthy.
- Primary observations do not test workload SQL, credentials, networking or the
  pooler. Streaming connections are not the desired replica count: one replica
  does not prove a three-instance HA configuration is satisfied. Inactive branches
  are included; the active branch is not identified by these metrics.
- Backups use `barman_cloud_cloudnative_pg_io_*`, exported by the Barman plugin
  through CNPG's metrics endpoint. The legacy `cnpg_collector_*backup*` timestamps
  can be zero with plugin backups and are deliberately not used. Backup age is
  based on the newest positive timestamp across the branch's pods; absent/zero
  timestamps are unknown, not a backup dating from 1970.
- A backup older than 36h and disk usage at 80%/90% are **triage hints**, not
  negotiated SLOs or alert policies. Reported first recoverability point does not
  prove uninterrupted WAL, the latest recoverable point, a fixed retention window
  or a tested restore. High WAL archive age alone can be normal for an idle DB.
- Storage uses actual kubelet filesystem capacity/availability, joined through
  pod/PVC metadata for `pgdata`, not PVC-name assumptions or requested size.
  Queries retain environment and namespace in joins so identical names in dev
  and prod are not conflated. Restarts cover currently discovered pods only.

A complete provisioning view needs an independent inventory of Postgres/branch
resources and their desired/observed status, including resources without pods.
Desired replica count, pooler health and an end-to-end SQL probe are also outside
this first dashboard. These gaps must not be inferred from exporter health.

#### Publishing to monitoring.nais.io

Use [Grafana Git Sync](https://grafana.com/docs/grafana/latest/as-code/observability-as-code/git-sync/)
with the configuration in [`provisioning/monitoring/repository.json`](./provisioning/monitoring/repository.json).
It syncs **only `dashboards/monitoring/`**, not the legacy exporter or tenant-facing
ingress dashboards. `make deploy` remains the existing ingress/Grizzly deployment;
do not run it to publish the provider dashboard.

The pilot is deliberately one-way: **Jsonnet → generated resources in Git →
Grafana**. `workflows: []` prevents Grafana editing the generated resources.
There is no second API/import deployment for this dashboard. Dashboards/folders
are Git-managed; datasource and alert provisioning are unchanged.

#### One-time setup

1. Verify the running Grafana supports Git Sync and the `git` repository type.
   Grafana 13 enables provisioning by default. Configuration is not proof of the
   running version; do not upgrade/restart Grafana just to import a dashboard.
2. Publish the generated resources to an approved branch in `nais/dashboards`
   first. For a pilot, select that branch instead of `main`; the checked-in
   Repository resource describes the eventual `main` configuration. Local files
   cannot be fetched by monitoring.nais.io before they are pushed.
3. As a Grafana administrator, inspect existing Git Sync repositories and check
   that UID `nais-postgres-fleet` is unused. Do not adopt/delete an existing
   dashboard or configure full-instance sync.
4. Configure **Pure Git** with URL `https://github.com/nais/dashboards.git`, the
   approved branch and path `dashboards/monitoring/`. Use folder-scoped sync,
   title **Nais monitoring**, read-only mode, a 60-second polling interval and
   disabled webhooks. The public repository can be read anonymously; no GitHub
   App, personal token or incoming webhook is needed for this read-only pilot.
   If anonymous reads are refused by the running version, investigate rather
   than granting write access or reusing a personal token.
5. The same Repository resource can be applied with `gcx resources push --path
   provisioning/monitoring` using an approved authenticated Grafana context
   targeting **https://monitoring.nais.io**. Check the context and branch first;
   do not store API tokens or IAP credentials in this repo. These are Grafana API
   resources, not Kubernetes CRDs; do not apply them with `kubectl`.

Polling is outbound from Grafana to GitHub. IAP remains in place and no webhook
endpoint needs to be exposed. Do not enable Grafana-to-Git writes while Jsonnet
owns the generated files.

#### Verify and iterate

- Check repository health and a successful sync, including `status.sync.lastRef`
  matching the expected Git commit. Read the dashboard back and confirm that it
  is managed by this repository in its dedicated folder.
- Open the dashboard and select a tenant with CNPG data (for example `nav-metrics`).
  Check environment/team/Postgres/branch filters, the fleet table, panel errors
  and missing-data behavior against Mimir. A successful sync does not prove that
  the rendered panels or queries work.
- To test updates, change the Jsonnet source, run `make compile` and `make check`,
  then commit/push the source and generated resources together to the approved
  branch. Verify the new commit is synced and the expected change is visible.
- After the pilot is accepted and merged, point the connection at `main`.
  Investigate sync errors rather than falling back to a second publishing owner.

The dashboard UID is `nais-postgres-fleet`; its URL begins with
`https://monitoring.nais.io/d/nais-postgres-fleet/`.
To pause the pilot, disable this repository's sync; this does not remove existing
provisioned dashboards. For rollback, revert the dashboard change in Git and
let it sync. Do not delete the repository or its managed folder as a first step:
that can delete managed resources. Leave all other dashboards and folders alone.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
