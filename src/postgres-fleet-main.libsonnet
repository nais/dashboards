local g = import './g.libsonnet';
local q = import './postgres-fleet-queries.libsonnet';
local variables = import './postgres-fleet-variables.libsonnet';
local datasource = { type: 'prometheus', uid: '${datasource}' };
local legend = '{{k8s_cluster_name}} / {{team}} / {{postgres}} / {{branch}}';
local thresholds(steps) = { mode: 'absolute', steps: steps };
local unknown = [{ type: 'value', options: { '-1': { text: 'Unknown', color: 'gray' } } }];
local attention = thresholds([{ value: null, color: 'green' }, { value: 1, color: 'red' }]);
local backupThresholds = thresholds([
  { value: null, color: 'gray' },
  { value: 0, color: 'green' },
  { value: 129600, color: 'yellow' },
  { value: 172800, color: 'red' },
]);
local diskThresholds = thresholds([
  { value: null, color: 'gray' },
  { value: 0, color: 'green' },
  { value: 80, color: 'yellow' },
  { value: 90, color: 'red' },
]);
local target(expr, instant=false) = {
  refId: 'A',
  datasource: datasource,
  editorMode: 'code',
  expr: expr,
  legendFormat: legend,
  instant: instant,
  range: !instant,
  format: if instant then 'table' else 'time_series',
};
local panel(id, title, type, expr, x, y, w=12, h=7, unit='short', description='') = {
  id: id,
  title: title,
  type: type,
  description: description,
  datasource: datasource,
  gridPos: { x: x, y: y, w: w, h: h },
  targets: [target(expr, type == 'table' || type == 'stat')],
  fieldConfig: {
    defaults: { unit: unit, noValue: 'Unknown', mappings: unknown, color: { mode: 'palette-classic' } },
    overrides: [],
  },
};
local series(id, title, expr, x, y, unit='short', description='') =
  panel(id, title, 'timeseries', expr, x, y, unit=unit, description=description)
  + {
    fieldConfig+: { defaults+: { custom: { drawStyle: 'line', lineWidth: 1, fillOpacity: 5, spanNulls: false, showPoints: 'never' } } },
    options: { legend: { displayMode: 'table', placement: 'bottom', calcs: ['lastNotNull', 'max'] }, tooltip: { mode: 'multi', sort: 'desc' } },
  };
local row(id, title, y) = { id: id, title: title, type: 'row', collapsed: false, panels: [], gridPos: { x: 0, y: y, w: 24, h: 1 } };
local stat(id, title, expr, x, w, risk=true) =
  panel(id, title, 'stat', expr, x, 4, w=w, h=3)
  + {
    targets: [target(expr) + { instant: true, range: false }],
    fieldConfig+: { defaults+: { color: { mode: if risk then 'thresholds' else 'fixed', fixedColor: 'blue' }, thresholds: attention, decimals: 0 } },
    options: { colorMode: 'value', graphMode: 'none', textMode: 'auto', reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false } },
  };
local countRisk(expr) = 'count(' + expr + ') or (0 * count(' + q.branches + '))';
local table(id, title, expr, x, y, unit, description) =
  panel(id, title, 'table', expr, x, y, unit=unit, description=description)
  + {
    options: { showHeader: true, cellHeight: 'sm' },
    transformations: [{ id: 'organize', options: {
      excludeByName: { Time: true, namespace: true },
      renameByName: { k8s_cluster_name: 'Environment', team: 'Team', postgres: 'Postgres', branch: 'Branch', Value: title },
    } }],
  };
local override(name, properties) = { matcher: { id: 'byName', options: name }, properties: properties };

g.dashboard.new('Nais Postgres – Fleet')
+ g.dashboard.withUid('nais-postgres-fleet')
+ g.dashboard.withDescription('Provider operations for Nais Postgres (CNPG): observed primaries, replication, Barman backups, WAL and storage. One tenant at a time; not an end-to-end availability or restore guarantee.')
+ g.dashboard.withTags(['nais', 'postgres', 'cnpg', 'operations'])
+ g.dashboard.time.withFrom('now-6h')
+ g.dashboard.withTimezone('browser')
+ g.dashboard.withEditable(false)
+ g.dashboard.withVariables(variables)
+ {
  refresh: '1m',
  graphTooltip: 1,
  links: [
    { title: 'Source', type: 'link', url: 'https://github.com/nais/dashboards/blob/main/src/postgres-fleet-main.libsonnet', targetBlank: true },
    { title: 'Postgres documentation', type: 'link', url: 'https://docs.nais.io/persistence/postgres/', targetBlank: true },
  ],
}
+ g.dashboard.withPanels([
  {
    id: 1,
    title: 'Scope and blind spots',
    type: 'text',
    gridPos: { x: 0, y: 0, w: 24, h: 4 },
    options: { mode: 'markdown', content: |||
      **Provider view · one tenant at a time.** Select a `*-metrics` datasource (Mimir, `nais` org). The fleet table includes every **currently discovered scrape target**, including failed scrapes. `Unknown` is not healthy.

      **Not a complete inventory:** databases stuck before a target exists, and branches whose targets have all disappeared, are not visible. Branch activation, desired replica count, pooler/connectivity and actual SQL read/write are not measured here. Check Console/events for provisioning. No new alerts are created by this dashboard.

      **Backups:** use Barman-plugin metrics, not CNPG's legacy backup timestamps. Backup age >36h needs investigation; it is not an RPO promise. WAL archive age alone can be high on an idle database. Recovery metadata does not prove a continuous archive or a tested restore.
    ||| },
  },
  stat(2, 'Observed branches', 'count(' + q.branches + ')', 0, 4, risk=false),
  stat(3, 'Primary count ≠ 1', countRisk(q.noPrimary), 4, 5),
  stat(4, 'Replica absent / unknown', countRisk(q.noReplica), 9, 5),
  stat(5, 'Backup old / unknown', countRisk(q.backupNeedsAttention), 14, 5),
  stat(6, 'Scrape failures', countRisk(q.scrapeProblems), 19, 5),
  panel(7,
        'Fleet — environment / team / Postgres / branch',
        'table',
        q.summary,
        0,
        7,
        w=24,
        h=12,
        description='Current observations, including inactive branches. Exactly one observed primary is expected; streaming replicas are actual connections, not desired HA count. Unknown backup/disk/SQL telemetry requires investigation. Colour thresholds are triage hints, not alert policies.')
  + {
    options: { showHeader: true, cellHeight: 'sm' },
    transformations: [
      { id: 'groupingToMatrix', options: { rowField: 'resource', columnField: 'signal', valueField: 'Value', emptyValue: 'null' } },
      { id: 'organize', options: { renameByName: { 'resource\\signal': 'Environment / Team / Postgres / Branch' }, indexByName: {
        'resource\\signal': 0,
        'Observed primaries': 1,
        'Streaming replicas': 2,
        'Scrapes OK': 3,
        'Missing SQL telemetry': 4,
        'Backup age': 5,
        'Disk used': 6,
      } } },
    ],
    fieldConfig+: {
      defaults+: { color: { mode: 'thresholds' }, custom: { cellOptions: { type: 'color-text' }, filterable: true } },
      overrides: [
        override('Observed primaries', [
          { id: 'thresholds', value: thresholds([{ value: null, color: 'red' }, { value: 1, color: 'green' }, { value: 2, color: 'red' }]) },
          { id: 'decimals', value: 0 },
        ]),
        override('Streaming replicas', [
          { id: 'thresholds', value: thresholds([{ value: null, color: 'gray' }, { value: 0, color: 'yellow' }, { value: 1, color: 'green' }]) },
          { id: 'decimals', value: 0 },
        ]),
        override('Scrapes OK', [
          { id: 'unit', value: 'percent' },
          { id: 'thresholds', value: thresholds([{ value: null, color: 'red' }, { value: 100, color: 'green' }]) },
        ]),
        override('Missing SQL telemetry', [{ id: 'thresholds', value: attention }, { id: 'decimals', value: 0 }]),
        override('Backup age', [{ id: 'unit', value: 's' }, { id: 'thresholds', value: backupThresholds }]),
        override('Disk used', [{ id: 'unit', value: 'percent' }, { id: 'thresholds', value: diskThresholds }]),
      ],
    },
  },
  row(10, 'Availability and replication — observations, not an end-to-end probe', 19),
  series(11, 'Observed primary count', q.primaries, 0, 20, description='Zero includes missing SQL telemetry. Does not test SQL read/write, pooler, network or credentials.'),
  series(12, 'Streaming replicas at primary', q.streaming, 12, 20, description='Actual streaming connections. Desired replica count is not exported here; one connection does not prove the configured HA topology is satisfied.'),
  series(13, 'Replica replay lag', q.replicaLag, 0, 27, 's', 'Maximum observed replica lag per branch. Missing replicas produce missing data, not zero lag.'),
  series(14, 'Missing SQL telemetry / discovered targets', q.sqlTelemetryMissing, 12, 27, description='Targets without cnpg_collector_up. Healthy branches have no matching series in this panel; consult the fleet table for explicit counts.'),
  row(20, 'Backups and WAL — investigate unknowns; verify recovery with restore drills', 34),
  series(21, 'Age of latest available basebackup', q.backupAge, 0, 35, 's', 'Barman-plugin timestamp; -1 means no positive timestamp reported. Daily backups: >36h is a triage hint, not an agreed SLO.')
  + { fieldConfig+: { defaults+: { thresholds: backupThresholds } } },
  table(22, 'First recoverability point (reported)', q.recoveryPoint, 12, 35, 'dateTimeAsIso', 'Barman archive metadata, not a proof of WAL continuity. Missing/zero timestamps are omitted; do not infer a 30-day restore guarantee.'),
  series(23, 'WAL files waiting for archive', q.walPending, 0, 42, description='Maximum ready-to-archive files on any observed pod in a branch. Persistent or growing backlog warrants investigation.'),
  series(24, 'WAL archive failures', q.walFailures, 12, 42, description='Increase in failed archive attempts over $__rate_interval. Retries can occur; inspect backlog and successful progress together.'),
  series(25, 'Time since last successful WAL archive', q.walArchiveAge, 0, 49, 's', 'Informational only. Idle databases may not generate new WAL; age alone is not an archive-stalled alarm. Only positive archive timestamps are shown.'),
  table(26, 'Last failed backup (reported)', q.lastBackupFailure, 12, 49, 'dateTimeAsIso', 'Historical failures can remain after a successful backup. Compare with latest available backup; an empty table is not proof of working backups.'),
  row(30, 'Capacity — worst observed pod per branch', 56),
  series(31, 'Data volume used', q.diskUsage, 0, 57, 'percent', 'Highest pgdata filesystem usage per branch, joined via the pod/PVC relationship. Uses actual filesystem capacity, not requested disk size.')
  + { fieldConfig+: { defaults+: { thresholds: diskThresholds } } },
  series(32, 'Least free data volume space', q.diskFree, 12, 57, 'bytes', 'Lowest available pgdata filesystem space per branch. Missing kubelet/PVC metrics are unknown, not zero usage.'),
  series(33, 'Postgres memory / limit', q.memory, 0, 64, 'percent', 'Highest container working set / positive memory limit per branch. No limit or missing metrics yields no observation; this does not diagnose memory pressure by itself.'),
  table(34, 'Postgres restarts in selected time range', q.restarts, 12, 64, 'short', 'Sum of container restarts for currently discovered database pods. Deleted/replaced pods are not a complete incident history.'),
  row(40, 'Control plane — environment scope only, unaffected by team/Postgres/branch filters', 71),
  series(41, 'Pgrator reconciliation errors / second', q.controllerErrors, 0, 72, 'ops', 'All Postgres controllers in the selected environments. Reconciliation errors are not an inventory of stalled database creation.')
  + { targets: [target(q.controllerErrors) + { legendFormat: '{{k8s_cluster_name}} / {{controller}}' }] },
  series(42, 'CNPG SQL metric collection errors', q.collectionErrors, 12, 72, description='Maximum last-collection-error flag per branch. Missing telemetry is separately visible in the fleet table.'),
])
