local g = import './g.libsonnet';
local prometheusQuery = g.query.prometheus;
local lokiQuery = g.query.loki;

local variables = import './ingress-variables.libsonnet';

{
  requestRate:
    prometheusQuery.new(
      '$' + variables.prometheus.name,
      |||
        sum by (status) (
          increase(
            nginx_ingress_controller_requests{
              namespace=~"$namespace",
              host=~"$host",
              status=~"$status",
              method=~"$method",
            }[$__interval]
          )
        )
      |||
    )
    + prometheusQuery.withLegendFormat(|||
      {{status}}
    |||),

  requestDurationQuantile:
    [
      prometheusQuery.new(
        '$' + variables.prometheus.name,
        |||
          histogram_quantile(
            0.%s,
            sum by (le, host) (
              rate(
                nginx_ingress_controller_request_duration_seconds_bucket{
                  namespace=~"$namespace",
                  host=~"$host",
                  status=~"$status",
                  method=~"$method",
                }[$__rate_interval]
              )
            )
          )
        ||| % quantile
      )
      + prometheusQuery.withLegendFormat(|||
        $host %s%%
      ||| % quantile)
      for quantile in ['95', '99']
    ],

  ingressLogs:
    lokiQuery.new(
      '$' + variables.loki.name,
      |||
        {
          service_name="nais-ingress",
          service_namespace="$namespace"
        }
          |= `$search`
          | json
          | __error__=``
          | url_domain = `$host`
          | http_request_method =~ `$method`
          | http_response_status_code =~ `$status`
          | line_format `{{.remote_addr}} {{.message}} {{.http_response_status_code }} {{.destination_address}} {{.user_agent_original}}`
      |||
    ),

  cpuUsage:
    prometheusQuery.new(
      '$' + variables.prometheus.name,
      |||
        sum by (cluster, namespace, job) (
            rate(
                process_cpu_seconds_total{
                    cluster=~"$cluster",
                    namespace=~"$namespace",
                    job=~"$job"
                }
            [$__rate_interval])
        )
      |||
    )
    + prometheusQuery.withIntervalFactor(2)
    + prometheusQuery.withLegendFormat(|||
      {{cluster}} - {{namespace}}
    |||),

  memUsage:
    [
      prometheusQuery.new(
        '$' + variables.prometheus.name,
        |||
          sum by (cluster, namespace, job) (
            process_virtual_memory_bytes{cluster=~"$cluster", namespace=~"$namespace", job=~"$job"}
          )
        |||
      )
      + prometheusQuery.withIntervalFactor(2)
      + prometheusQuery.withLegendFormat(|||
        virtual - {{cluster}} - {{namespace}}
      |||),
      prometheusQuery.new(
        '$' + variables.prometheus.name,
        |||
          sum by (cluster, namespace, job) (
            process_resident_memory_bytes{cluster=~"$cluster", namespace=~"$namespace", job=~"$job"}
          )
        |||
      )
      + prometheusQuery.withIntervalFactor(2)
      + prometheusQuery.withLegendFormat(|||
        resident - {{cluster}} - {{namespace}}
      |||),
      prometheusQuery.new(
        '$' + variables.prometheus.name,
        |||
          sum by (cluster, namespace, job) (
            go_memstats_heap_inuse_bytes{cluster=~"$cluster", namespace=~"$namespace", job=~"$job"}
          )
        |||
      )
      + prometheusQuery.withIntervalFactor(2)
      + prometheusQuery.withLegendFormat(|||
        go heap - {{cluster}} - {{namespace}}
      |||),
      prometheusQuery.new(
        '$' + variables.prometheus.name,
        |||
          sum by (cluster, namespace, job) (
            go_memstats_stack_inuse_bytes{cluster=~"$cluster", namespace=~"$namespace", job=~"$job"}
          )
        |||
      )
      + prometheusQuery.withIntervalFactor(2)
      + prometheusQuery.withLegendFormat(|||
        go stack - {{cluster}} - {{namespace}}
      |||),
    ],

  goroutines:
    prometheusQuery.new(
      '$' + variables.prometheus.name,
      |||
        sum by (cluster, namespace, job) (
          go_goroutines{cluster=~"$cluster", namespace=~"$namespace", job=~"$job"}
        )
      |||
    )
    + prometheusQuery.withIntervalFactor(2)
    + prometheusQuery.withLegendFormat(|||
      {{cluster}} - {{namespace}}
    |||),

  threads:
    prometheusQuery.new(
      '$' + variables.prometheus.name,
      |||
        sum by (cluster, namespace, job) (
          go_threads{cluster=~"$cluster", namespace=~"$namespace", job=~"$job"}
        )
      |||
    )
    + prometheusQuery.withIntervalFactor(2)
    + prometheusQuery.withLegendFormat(|||
      {{cluster}} - {{namespace}}
    |||),

  gcDuration:
    prometheusQuery.new(
      '$' + variables.prometheus.name,
      |||
        sum by (cluster, namespace, job) (
          rate(
            go_gc_duration_seconds_sum{
                cluster=~"$cluster",
                namespace=~"$namespace",
                job=~"$job"
            }
          [$__rate_interval])
        )
      |||
    )
    + prometheusQuery.withIntervalFactor(2)
    + prometheusQuery.withLegendFormat(|||
      {{cluster}} - {{namespace}}
    |||),

  wqDurationOverTime:
    prometheusQuery.new(
      '$' + variables.prometheus.name,
      |||
        sum by(cluster, namespace, job, le, name) (
          rate(
            workqueue_queue_duration_seconds_bucket{
                cluster=~"$cluster",
                namespace=~"$namespace",
                job=~"$job"
            }
          [$__rate_interval])
        )
      |||
    )
    + prometheusQuery.withLegendFormat(|||
      {{cluster}} - {{namespace}}
    |||),

  wqDurationQuantile:
    [
      prometheusQuery.new(
        '$' + variables.prometheus.name,
        |||
          histogram_quantile(
            0.%s,
            sum by (cluster, namespace, job, le, name) (
              rate(
                workqueue_queue_duration_seconds_bucket{
                    cluster=~"$cluster",
                    namespace=~"$namespace",
                    job=~"$job"
                }
              [$__rate_interval])
            )
          )
        ||| % quantile
      )
      + prometheusQuery.withIntervalFactor(2)
      + prometheusQuery.withLegendFormat(|||
        {{cluster}} - {{namespace}} - {{name}} - %s%%
      ||| % quantile)
      for quantile in ['50', '95']
    ] + [
      prometheusQuery.new(
        '$' + variables.prometheus.name,
        |||
          sum by (cluster, namespace, job, name) (
            rate(
              workqueue_queue_duration_seconds_sum{
                  cluster=~"$cluster",
                  namespace=~"$namespace",
                  job=~"$job"
              }
            [$__rate_interval])
          )
        |||
      )
      + prometheusQuery.withIntervalFactor(2)
      + prometheusQuery.withLegendFormat(|||
        {{cluster}} - {{namespace}} - {{name}} - mean
      |||),
    ],

  wqDepth:
    prometheusQuery.new(
      '$' + variables.prometheus.name,
      |||
        sum by(cluster, namespace, job, name) (
          workqueue_depth{cluster=~"$cluster", namespace=~"$namespace", job=~"$job"}
        )
      |||
    )
    + prometheusQuery.withIntervalFactor(2)
    + prometheusQuery.withLegendFormat(|||
      {{cluster}} - {{namespace}} - {{name}}
    |||),

  failedRequests:
    prometheusQuery.new(
      '$' + variables.prometheus.name,
      |||
        ceil by (cluster, namespace, job, host, method) (
          sum(
            increase(
              rest_client_requests_total{
                  cluster=~"$cluster",
                  namespace=~"$namespace",
                  job=~"$job",
                  code=~"^(4|5).*"
              }
            [$__rate_interval])
          )
        )
      |||
    )
    + prometheusQuery.withIntervalFactor(2)
    + prometheusQuery.withLegendFormat(|||
      {{cluster}} - {{namespace}} - {{host}} - {{method}}
    |||),

  reconcilingLatencyOverTime:
    prometheusQuery.new(
      '$' + variables.prometheus.name,
      |||
        sum by (cluster, namespace, job, le, controller) (
          rate(
            controller_runtime_reconcile_time_seconds_bucket{
                cluster=~"$cluster",
                namespace=~"$namespace",
                job=~"$job"
            }
          [$__rate_interval])
        )
      |||
    )
    + prometheusQuery.withLegendFormat(|||
      {{cluster}} - {{namespace}}
    |||),

  reconcilingDurationQuantile:
    [
      prometheusQuery.new(
        '$' + variables.prometheus.name,
        |||
          histogram_quantile(
            0.%s,
            sum by (cluster, namespace, job, le, controller) (
              rate(
                controller_runtime_reconcile_time_seconds_bucket{
                    cluster=~"$cluster",
                    namespace=~"$namespace",
                    job=~"$job"
                }
              [$__rate_interval])
            )
          )
        ||| % quantile
      )
      + prometheusQuery.withIntervalFactor(2)
      + prometheusQuery.withLegendFormat(|||
        {{cluster}} - {{namespace}} - {{name}} - %s%%
      ||| % quantile)
      for quantile in ['50', '95']
    ] + [
      prometheusQuery.new(
        '$' + variables.prometheus.name,
        |||
          sum by (cluster, namespace, job, controller) (
            rate(
              controller_runtime_reconcile_time_seconds_sum{
                  cluster=~"$cluster",
                  namespace=~"$namespace",
                  job=~"$job"
              }
            [$__rate_interval])
          )
        |||
      )
      + prometheusQuery.withIntervalFactor(2)
      + prometheusQuery.withLegendFormat(|||
        {{cluster}} - {{namespace}} - {{name}} - mean
      |||),
    ],
}

// vim: foldmethod=indent shiftwidth=2 foldlevel=1
