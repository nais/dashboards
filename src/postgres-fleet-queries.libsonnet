// All joins retain environment and namespace: identical database/pod names can
// exist in several environments. `up` includes failed scrapes, unlike SQL metrics.
local labels = 'k8s_cluster_name, namespace, team, postgres, branch';
local pods = labels + ', pod';
local podKey = 'k8s_cluster_name, namespace, pod';
local pvcKey = 'k8s_cluster_name, namespace, persistentvolumeclaim';
local selector = 'postgres!="", k8s_cluster_name=~"${environment:regex}", team=~"${team:regex}", postgres=~"${postgres:regex}", branch=~"${branch:regex}"';
local metric(name, extra='') = name + '{' + selector + (if extra == '' then '' else ', ' + extra) + '}';
local aggregate(op, by, expr) = '%s by (%s) (%s)' % [op, by, expr];
local podMetric(name, extra='') = aggregate('max', pods, metric(name, extra));
local targets = podMetric('up');
local inventory = aggregate('group', pods, targets);
local branches = aggregate('group', labels, targets);
local primary = '(' + podMetric('cnpg_pg_replication_in_recovery') + ' == bool 0) * on (' + pods + ') ' + podMetric('cnpg_collector_up');
local backup = aggregate('max', labels, metric('barman_cloud_cloudnative_pg_io_last_available_backup_timestamp'));
local recovery = aggregate('max', labels, metric('barman_cloud_cloudnative_pg_io_first_recoverability_point'));
local podVolumes = 'max by (' + podKey + ', persistentvolumeclaim) (kube_pod_spec_volumes_persistentvolumeclaims_info{volume="pgdata", k8s_cluster_name=~"${environment:regex}"})';
local volumeMetric(name) = 'max by (' + pvcKey + ') (' + name + '{k8s_cluster_name=~"${environment:regex}"})';
local volumeToBranch(expr, op='max') = aggregate(op,
                                                 labels,
                                                 '(' + expr + ') * on (' + pvcKey + ') group_right() ' + podVolumes
                                                 + ' * on (' + podKey + ') group_left(team, postgres, branch) ' + inventory);
local diskUsage = volumeToBranch('100 * ' + volumeMetric('kubelet_volume_stats_used_bytes') + ' / on (' + pvcKey + ') ' + volumeMetric('kubelet_volume_stats_capacity_bytes'));
local knownOrUnknown(expr) = '((' + expr + ') or (-1 * ' + branches + '))';
local primaries = '(' + aggregate('sum', labels, primary) + ' or (0 * ' + branches + '))';
local streaming = knownOrUnknown(aggregate('max', labels, podMetric('cnpg_pg_replication_streaming_replicas') + ' and on (' + pods + ') (' + primary + ' == 1)'));
local backupAge = knownOrUnknown('time() - (' + backup + ' > 0)');
local scrape = '100 * ' + aggregate('sum', labels, targets) + ' / ' + aggregate('count', labels, targets);
local telemetry = aggregate('sum', labels, inventory + ' unless on (' + pods + ') ' + podMetric('cnpg_collector_up')) + ' or (0 * ' + branches + ')';
local errors = aggregate('max', labels, metric('cnpg_collector_last_collection_error'));
local summary = [
  { name: 'Observed primaries', expr: primaries },
  { name: 'Streaming replicas', expr: streaming },
  { name: 'Scrapes OK', expr: scrape },
  { name: 'Missing SQL telemetry', expr: telemetry },
  { name: 'Backup age', expr: backupAge },
  { name: 'Disk used', expr: knownOrUnknown(diskUsage) },
];
{
  branches: branches,
  primaries: primaries,
  streaming: streaming,
  backupAge: backupAge,
  scrape: scrape,
  diskUsage: diskUsage,
  summary: std.join(' or ', [
    'label_replace(label_join((' + item.expr + '), "resource", " / ", "k8s_cluster_name", "team", "postgres", "branch"), "signal", "' + item.name + '", "", "")'
    for item in summary
  ]),
  noPrimary: primaries + ' != 1',
  noReplica: streaming + ' < 1',
  backupNeedsAttention: backupAge + ' < 0 or (' + backupAge + ') > 129600',
  scrapeProblems: scrape + ' < 100',
  sqlTelemetryMissing: telemetry + ' > 0',
  collectionErrors: errors,
  replicaLag: aggregate('max', labels, metric('cnpg_pg_replication_lag') + ' and on (' + pods + ') (' + podMetric('cnpg_pg_replication_in_recovery') + ' == 1)'),
  walPending: aggregate('max', labels, metric('cnpg_collector_pg_wal_archive_status', 'value="ready"')),
  walFailures: aggregate('sum', labels, 'increase(' + metric('cnpg_pg_stat_archiver_failed_count') + '[$__rate_interval])'),
  walArchiveAge: 'time() - (' + aggregate('max', labels, metric('cnpg_pg_stat_archiver_last_archived_time')) + ' > 0)',
  recoveryPoint: '(' + recovery + ' > 0) * 1000',
  lastBackupFailure: '(' + aggregate('max', labels, metric('barman_cloud_cloudnative_pg_io_last_failed_backup_timestamp')) + ' > 0) * 1000',
  diskFree: volumeToBranch(volumeMetric('kubelet_volume_stats_available_bytes'), op='min'),
  restarts: aggregate('sum',
                      labels,
                      'max by (' + podKey + ') (increase(kube_pod_container_status_restarts_total{container="postgres", k8s_cluster_name=~"${environment:regex}"}[$__range]))'
                      + ' * on (' + podKey + ') group_left(team, postgres, branch) ' + inventory),
  memory: aggregate('max',
                    labels,
                    '(max by (' + podKey + ') (container_memory_working_set_bytes{container="postgres", k8s_cluster_name=~"${environment:regex}"})'
                    + ' / on (' + podKey + ') max by (' + podKey + ') (kube_pod_container_resource_limits{container="postgres", resource="memory", k8s_cluster_name=~"${environment:regex}"} > 0))'
                    + ' * on (' + podKey + ') group_left(team, postgres, branch) ' + inventory + ' * 100'),
  controllerErrors: 'sum by (k8s_cluster_name, controller) (rate(controller_runtime_reconcile_errors_total{k8s_cluster_name=~"${environment:regex}", namespace="nais-system", controller=~"postgres.*[.]nais[.]io"}[$__rate_interval]))',
}
