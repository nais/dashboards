// Git Sync reads Grafana App Platform resources, not bare dashboard JSON.
// This directory is deliberately separate from the tenant-facing dashboards.
local fleet = import './postgres-fleet-main.libsonnet';

{
  'postgres-fleet.json': {
    apiVersion: 'dashboard.grafana.app/v1',
    kind: 'Dashboard',
    metadata: { name: fleet.uid },
    spec: fleet,
  },
}
