import type { Line as G2Line, LineOptions } from '@antv/g2plot/esm/plots/line'
import type { G2PlotDrawOptions } from '@/views/chart/components/js/panel/types/impl/g2plot'
import { LINE_AXIS_TYPE } from '@/views/chart/components/js/panel/charts/line/common'
import { Line } from './line'
import { transformYearCompareLineData } from './year-compare-utils'
import { cloneDeep } from 'lodash-es'
import { useI18n } from '@/hooks/web/useI18n'

const { t } = useI18n()

/**
 * 年份对比折线图
 * 复用基础折线图 Line 的全部样式与交互，仅将日期拆成「月-日」X 轴 + 「年份」系列。
 */
export class YearCompareLine extends Line {
  axis: AxisType[] = [...LINE_AXIS_TYPE]
  axisConfig = {
    ...this['axisConfig'],
    yAxis: {
      ...this['axisConfig'].yAxis,
      limit: 1
    }
  }

  async drawChart(drawOptions: G2PlotDrawOptions<G2Line>): Promise<G2Line> {
    const chart = cloneDeep(drawOptions.chart)
    // 年份对比只展示单个指标，多余指标直接丢弃
    if (chart.yAxis?.length > 1) {
      chart.yAxis = chart.yAxis.slice(0, 1)
    }
    if (chart.data?.data?.length) {
      chart.data.data = transformYearCompareLineData(chart.data.data)
      const categories = Array.from(
        new Set(chart.data.data.map(item => item.category).filter(Boolean))
      )
      // 让基类图例/tooltip 按年份作为系列处理，并保持年份顺序
      chart.xAxisExt = [
        {
          id: 'yearCompareYear',
          name: t('chart.chart_group'),
          customSort: categories
        }
      ]
    }
    return super.drawChart({
      ...drawOptions,
      chart
    })
  }

  protected configBasicStyle(chart: Chart, options: LineOptions): LineOptions {
    const nextOptions = super.configBasicStyle(chart, options)
    // 大量分类点 + 平滑曲线会导致 G2Plot 路径计算异常，年份对比数据点较多，固定关平滑
    return {
      ...nextOptions,
      smooth: false
    }
  }

  protected setupOptions(chart: Chart, options: LineOptions): LineOptions {
    const nextOptions = super.setupOptions(chart, options)
    const data = nextOptions.data || options.data || []
    // 固定 X 轴为分类轴并按「月-日」顺序显示，避免 G2Plot 按字符串重排
    const values = Array.from(new Set(data.map(item => item.field).filter(Boolean)))
    return {
      ...nextOptions,
      meta: {
        ...nextOptions.meta,
        field: {
          ...(nextOptions.meta?.field || {}),
          type: 'cat',
          values
        }
      }
    }
  }

  constructor(name = 'year-compare-line') {
    super(name)
  }
}