local g = import './g.libsonnet';
local var = g.dashboard.variable;

{
  env:
    var.custom.new('env', ['dev', 'prod']),

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
    var.custom.new('status', ['.*', '2\\d{2}', '2\\d{2}', '3\\d{2}', '4\\d{2}', '5\\d{2}']),

  method:
    var.custom.new('method', ['.*', 'GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS']),

}
