local grr = import 'grizzly/grizzly.libsonnet';
local ingress = import 'src/ingress-main.libsonnet';

{
  dashboards: [
    grr.dashboard.new('nais-ingress-2', ingress)
    + grr.resource.addMetadata('folder', 'xwFwBYVmk'),
  ],
}
