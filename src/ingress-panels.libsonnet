local g = import 'g.libsonnet';

{
  barChart: {
    local barChart = g.panel.barChart,
    local fieldOverride = g.panel.barChart.fieldOverride,
    local options = barChart.options,
    local standardOptions = barChart.standardOptions,
    local custom = barChart.fieldConfig.defaults.custom,

    base(title, targets):
      barChart.new(title)
      + barChart.queryOptions.withTargets(targets)
      + barChart.queryOptions.withInterval('2m')
      + options.legend.withDisplayMode('table')
      + options.legend.withPlacement('right')
      + options.legend.withSortDesc()
      + options.withXTickLabelSpacing(100)
      + custom.withLineWidth(0),

    stacked(title, targets):
      self.base(title, targets)
      + options.withStacking('normal')
      + options.withShowValue(false)
      + options.withBarWidth(0.63)
      + standardOptions.withUnit('short')
      + standardOptions.color.withMode('thresholds')
      + standardOptions.thresholds.withSteps([
        { value: null, color: 'green' },
      ])
      + standardOptions.withOverrides([
        fieldOverride.byRegexp.new('/^4.*/')
        + fieldOverride.byRegexp.withProperty(
          'color',
          {
            fixedColor: 'orange',
            mode: 'fixed',
          }
        ),
        fieldOverride.byRegexp.new('/^5.*/')
        + fieldOverride.byRegexp.withProperty(
          'color',
          {
            fixedColor: 'red',
            mode: 'fixed',
          }
        ),
      ]),
  },

  logs: {
    local logs = g.panel.logs,
    local options = logs.options,

    base(title, targets):
      logs.new(title)
      + logs.queryOptions.withTargets(targets)
      + logs.options.withShowTime(true),
  },

  timeSeries: {
    local timeSeries = g.panel.timeSeries,
    local fieldOverride = g.panel.timeSeries.fieldOverride,
    local custom = timeSeries.fieldConfig.defaults.custom,
    local options = timeSeries.options,

    base(title, targets):
      timeSeries.new(title)
      + timeSeries.queryOptions.withTargets(targets)
      + timeSeries.queryOptions.withInterval('1m')
      + options.legend.withDisplayMode('list')
      + options.legend.withCalcs([
        'lastNotNull',
        'max',
      ])
      + custom.withFillOpacity(10)
      + custom.withShowPoints('never'),

    short(title, targets):
      self.base(title, targets)
      + timeSeries.standardOptions.withUnit('short')
      + timeSeries.standardOptions.withDecimals(0),

    seconds(title, targets):
      self.base(title, targets)
      + timeSeries.standardOptions.withUnit('s')
      + custom.scaleDistribution.withType('log')
      + custom.scaleDistribution.withLog(10),

    cpuUsage: self.seconds,

    bytes(title, targets):
      self.base(title, targets,)
      + timeSeries.standardOptions.withUnit('bytes')
      + custom.scaleDistribution.withType('log')
      + custom.scaleDistribution.withLog(2),

    memoryUsage(title, targets):
      self.bytes(title, targets)
      + timeSeries.standardOptions.withOverrides([
        fieldOverride.byRegexp.new('/(virtual|resident)/i')
        + fieldOverride.byRegexp.withProperty(
          'custom.fillOpacity',
          0
        )
        + fieldOverride.byRegexp.withProperty(
          'custom.lineWidth',
          2
        )
        + fieldOverride.byRegexp.withProperty(
          'custom.lineStyle',
          {
            dash: [10, 10],
            fill: 'dash',
          }
        ),
      ]),

    durationQuantile(title, targets):
      self.base(title, targets)
      + timeSeries.standardOptions.withUnit('s')
      + custom.withDrawStyle('bars')
      + timeSeries.standardOptions.withOverrides([
        fieldOverride.byRegexp.new('/mean/i')
        + fieldOverride.byRegexp.withProperty(
          'custom.fillOpacity',
          0
        )
        + fieldOverride.byRegexp.withProperty(
          'custom.lineStyle',
          {
            dash: [8, 10],
            fill: 'dash',
          }
        ),
      ]),
  },

  heatmap: {
    local heatmap = g.panel.heatmap,
    local options = heatmap.options,

    base(title, targets):
      heatmap.new(title)
      + heatmap.queryOptions.withTargets(targets)
      + heatmap.queryOptions.withInterval('1m')
      + options.withCalculate()
      + options.calculation.xBuckets.withMode('size')
      + options.calculation.xBuckets.withValue('1min')
      + options.withCellGap(2)
      + options.color.withMode('scheme')
      + options.color.withScheme('Spectral')
      + options.color.withSteps(128)
      + options.yAxis.withDecimals(0)
      + options.yAxis.withUnit('s'),
  },
}

// vim: foldmethod=marker foldmarker=local,;
