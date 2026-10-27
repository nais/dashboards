local datasource = { type: 'prometheus', uid: '${datasource}' };
local variable(name, label, selector, field) = {
  name: name,
  label: label,
  type: 'query',
  datasource: datasource,
  query: 'label_values(up{postgres!="", ' + selector + '}, ' + field + ')',
  refresh: 2,
  sort: 1,
  multi: true,
  includeAll: true,
  allValue: '.+',
  current: { text: 'All', value: '$__all' },
  options: [],
};
[
  {
    name: 'datasource',
    label: 'Tenant',
    type: 'datasource',
    query: 'prometheus',
    regex: '/.*-metrics$/',
    refresh: 1,
    multi: false,
    includeAll: false,
    options: [],
  },
  variable('environment', 'Environment', 'job!=""', 'k8s_cluster_name'),
  variable('team', 'Team', 'k8s_cluster_name=~"${environment:regex}"', 'team'),
  variable('postgres', 'Postgres', 'k8s_cluster_name=~"${environment:regex}", team=~"${team:regex}"', 'postgres'),
  variable('branch', 'Branch', 'k8s_cluster_name=~"${environment:regex}", team=~"${team:regex}", postgres=~"${postgres:regex}"', 'branch'),
]
