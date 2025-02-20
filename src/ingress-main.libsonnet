local g = import 'g.libsonnet';

local row = g.panel.row;

local panels = import './ingress-panels.libsonnet';
local variables = import './ingress-variables.libsonnet';
local queries = import './ingress-queries.libsonnet';

g.dashboard.new('Ingress Logs')
+ g.dashboard.withUid('nais-ingress-2')
+ g.dashboard.withDescription(|||
  Application access logs from the load balancer
|||)
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.withVariables([
  variables.env,
  variables.prometheus,
  variables.loki,
  variables.namespace,
  variables.host,
  variables.search,
  variables.status,
  variables.method,
])
+ g.dashboard.withPanels(
  g.util.grid.wrapPanels([
    panels.barChart.stacked('Request Rate', queries.requestRate)
    + g.panel.barChart.gridPos.withW(12)
    + g.panel.barChart.gridPos.withH(5),
    panels.timeSeries.seconds('Request Dureation', queries.requestDurationQuantile)
    + g.panel.barChart.gridPos.withW(12)
    + g.panel.barChart.gridPos.withH(5),
    panels.logs.base('Ingress Logs', queries.ingressLogs)
    + g.panel.logs.gridPos.withW(24)
    + g.panel.logs.gridPos.withH(15),
  ], panelWidth=8)
)
