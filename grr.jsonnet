local grr = import 'grizzly/grizzly.libsonnet';
local ingress = import 'src/ingress-main.libsonnet';

{
  dashboards: [
    grr.dashboard.new('ingress-logs', ingress)
    + grr.resource.addMetadata('folder', 'xwFwBYVmk'),
  ],
}
