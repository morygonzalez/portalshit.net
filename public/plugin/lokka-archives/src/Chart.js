import React, { PureComponent } from 'react'
import { Heatmap } from '@thilakbhat/heatmap-ui'
import '@thilakbhat/heatmap-ui/styles.css'

const locale = window.navigator.userLanguage || window.navigator.language

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

  categories() {
    return this.props.categories.filter(
      category => !this.props.disabledCategories.includes(category)
    )
  }

  render() {
    const categories = this.categories()
    const periods = this.state.data.map(item => this.periodLabel(item.duration))
    const values = categories.map(category => (
      this.state.data.map(item => item[category] || 0)
    ))
    const labelInterval = Math.ceil(periods.length / 12)

    if (categories.length === 0 || periods.length === 0) {
      return null
    }

    return (
      <Heatmap
        className="archive-heatmap"
        rows={categories.length}
        columns={periods.length}
        values={values}
        rowLabels={categories}
        columnLabels={periods.map((period, column) => ({ column, text: period })).filter(
          ({ column }) => column % labelInterval === 0
        )}
        cellSize={11}
        gap={3}
        radius={2}
        colors={['#9be9a8', '#40c463', '#30a14e', '#216e39']}
        emptyColor="#ebedf0"
        tooltip={({ row, column, value }) => (
          <>
            <strong>{categories[row]}</strong><br />
            {periods[column]}: {value} 件
          </>
        )}
        cellLabel={({ row, column, value }) => (
          `${categories[row]}、${periods[column]}、${value} 件`
        )}
        showLegend={true}
        legendLabels={{ less: '少ない', more: '多い' }}
        overflow="scroll"
        ariaLabel="カテゴリーと期間ごとの公開記事数を表すヒートマップ"
      />
    )
  }
}

