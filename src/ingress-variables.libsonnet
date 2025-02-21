local g = import './g.libsonnet';
local var = g.dashboard.variable;

{
  env:
    var.custom.new('env', ['dev', 'prod'])
    + var.custom.generalOptions.withCurrent('prod'),

  prometheus:
    var.datasource.new('prometheus', 'prometheus')
    + var.datasource.withRegex('/$env-gcp/')
    + { hide: 2 },

  loki:
    var.datasource.new('loki', 'loki')
    + var.datasource.withRegex('/$env-gcp-loki/')
    + { hide: 2 },

  namespace:
    var.query.new('namespace')
    + var.query.withDatasourceFromVariable(self.prometheus)
    + var.query.queryTypes.withLabelValues(
      'namespace',
      'nginx_ingress_controller_requests',
    ),

  host:
    var.query.new('host')
    + var.query.withDatasourceFromVariable(self.prometheus)
    + var.query.queryTypes.withLabelValues(
      'host',
      'nginx_ingress_controller_requests{namespace=~"$%s"}' % self.namespace.name,
    ),

  search:
    var.textbox.new('search', ''),

  status:
    var.custom.new('status', [
      { key: 'All', value: '.*' },
      { key: '2xx', value: '2\\d{2}' },
      { key: '3xx', value: '3\\d{2}' },
      { key: '4xx', value: '4\\d{2}' },
      { key: '5xx', value: '5\\d{2}' },
    ]),

  method:
    var.custom.new('method', [
      { key: 'All', value: '.*' },
      'GET',
      'POST',
      'PUT',
      'PATCH',
      'DELETE',
      'HEAD',
      'OPTIONS',
    ]),
}
