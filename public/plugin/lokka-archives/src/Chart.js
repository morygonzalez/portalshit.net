import React, { PureComponent } from 'react'
import { ResponsiveHeatMap } from '@nivo/heatmap'

const locale = window.navigator.userLanguage || window.navigator.language

function HeatMapTooltip({ cell }) {
  return (
    <div className="archive-heatmap-tooltip">
      <strong>{cell.serieId}</strong>
      <span>{cell.data.x}</span>
      <span>{cell.value || 0} 件</span>
    </div>
  )
}

export default class Chart extends PureComponent {
  constructor(props) {
    super(props)
    this.state = { data: [] }
  }

  async loadChartFromServer() {
    const path = this.props.year !== null
      ? `/archives/chart.json?year=${this.props.year}`
      : '/archives/chart.json'
    const request = await fetch(path)
    const response = await request.json()
    this.setState({ data: response })
  }

  componentDidMount() {
    this.loadChartFromServer()
  }

  componentDidUpdate(prevProps) {
    if (prevProps.year !== this.props.year) {
      this.loadChartFromServer()
    }
  }

  periodLabel(duration) {
    if (this.props.year === null) {
      return duration
    }

    return new Intl.DateTimeFormat(locale, { month: 'short' }).format(
      new Date(2020, Number(duration) - 1, 1)
    )
  }

  heatMapData() {
    const categories = this.props.categories.filter(
      category => !this.props.disabledCategories.includes(category)
    )

    return categories.map(category => ({
      id: category,
      data: this.state.data.map(item => ({
        x: this.periodLabel(item.duration),
        y: item[category] || null,
      })),
    }))
  }

  render() {
    const data = this.heatMapData()
    const height = Math.max(260, data.length * 38 + 100)

    if (data.length === 0 || this.state.data.length === 0) {
      return null
    }

    return (
      <section
        className="archive-heatmap"
        aria-label="カテゴリー別の記事数"
        style={{ height }}
      >
        <ResponsiveHeatMap
          data={data}
          margin={{ top: 36, right: 20, bottom: 20, left: 150 }}
          forceSquare={true}
          xInnerPadding={0.18}
          yInnerPadding={0.18}
          borderRadius={2}
          borderWidth={1}
          borderColor="#ffffff"
          emptyColor="#ebedf0"
          colors={{ type: 'sequential', scheme: 'greens' }}
          enableLabels={false}
          axisTop={{ tickSize: 0, tickPadding: 8 }}
          axisRight={null}
          axisBottom={null}
          axisLeft={{ tickSize: 0, tickPadding: 8 }}
          tooltip={HeatMapTooltip}
          animate={false}
          role="img"
          ariaLabel="カテゴリーと期間ごとの公開記事数を表すヒートマップ"
          theme={{
            axis: {
              ticks: {
                text: { fill: '#666', fontSize: 12 },
              },
            },
          }}
        />
      </section>
    )
  }
}

