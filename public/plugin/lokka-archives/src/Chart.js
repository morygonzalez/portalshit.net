import React, { PureComponent } from 'react'
import { Heatmap } from '@thilakbhat/heatmap-ui'
import '@thilakbhat/heatmap-ui/styles.css'

const locale = window.navigator.userLanguage || window.navigator.language

export default class Chart extends PureComponent {
  constructor(props) {
    super(props)
    this.state = { data: [], dataYear: null, loading: false }
    this.requestId = 0
  }

  async loadChartFromServer() {
    const requestId = ++this.requestId
    const year = this.props.year
    const path = year !== null
      ? `/archives/chart.json?year=${year}`
      : '/archives/chart.json'
    this.setState({ data: [], loading: true })

    try {
      const request = await fetch(path)
      const response = await request.json()
      if (requestId === this.requestId) {
        this.setState({ data: response, dataYear: year, loading: false })
      }
    } catch (error) {
      if (requestId === this.requestId) {
        this.setState({ loading: false })
      }
    }
  }

  componentDidMount() {
    this.loadChartFromServer()
  }

  componentDidUpdate(prevProps) {
    if (prevProps.year !== this.props.year) {
      this.loadChartFromServer()
    }
  }

  periods() {
    if (this.props.year !== null) {
      return Array.from({ length: 53 }, (_, index) => {
        const week = `W${String(index + 1).padStart(2, '0')}`
        return { key: week, label: week }
      })
    }

    const durations = this.state.data.map(item => item.duration).sort()
    const first = durations[0]
    const last = durations[durations.length - 1]
    const firstYear = Number(first.slice(0, 4))
    const lastYear = Number(last.slice(0, 4))
    const firstQuarter = Number(first.slice(-1))
    const lastQuarter = Number(last.slice(-1))
    const periods = []

    for (let year = firstYear; year <= lastYear; year += 1) {
      const startQuarter = year === firstYear ? firstQuarter : 1
      const endQuarter = year === lastYear ? lastQuarter : 4
      for (let quarter = startQuarter; quarter <= endQuarter; quarter += 1) {
        const key = `${year}-Q${quarter}`
        periods.push({ key, label: key })
      }
    }

    return periods
  }

  categories() {
    return this.props.categories.filter(
      category => !this.props.disabledCategories.includes(category)
    )
  }

  isoWeekNumber(date) {
    const target = new Date(date.getTime())
    const day = (target.getUTCDay() + 6) % 7
    target.setUTCDate(target.getUTCDate() - day + 3)
    const firstThursday = new Date(Date.UTC(target.getUTCFullYear(), 0, 4))
    return 1 + Math.round((target - firstThursday) / 604800000)
  }

  columnLabels(periods) {
    if (this.props.year !== null) {
      const year = Number(this.props.year)
      const formatter = new Intl.DateTimeFormat(locale, { month: 'short' })
      return Array.from({ length: 12 }, (_, month) => {
        const date = new Date(Date.UTC(year, month, 7))
        return {
          column: this.isoWeekNumber(date) - 1,
          text: formatter.format(date),
        }
      })
    }

    return periods.map(({ key }, column) => ({
      column,
      text: key.slice(0, 4),
    })).filter(({ column }) => periods[column].key.endsWith('-Q1'))
  }

  render() {
    const categories = this.categories()

    if (
      this.state.loading || this.state.dataYear !== this.props.year ||
      categories.length === 0 || this.state.data.length === 0
    ) {
      return null
    }

    const periods = this.periods()
    const countsByPeriod = this.state.data.reduce((counts, item) => {
      const key = this.props.year !== null ? item.duration.slice(-3) : item.duration
      counts[key] = item
      return counts
    }, {})
    const values = categories.map(category => periods.map(
      ({ key }) => Number(countsByPeriod[key] && countsByPeriod[key][category]) || 0
    ))
    if (periods.length === 0) {
      return null
    }

    return (
      <Heatmap
        key={`${this.props.year || 'all'}-${periods.length}`}
        className="archive-heatmap"
        rows={categories.length}
        columns={periods.length}
        values={values}
        rowLabels={categories}
        columnLabels={this.columnLabels(periods)}
        cellSize={14}
        gap={3}
        radius={2}
        levels={8}
        colors={[
          '#ffefd5', '#ffdbab', '#ffc27a', '#ffa451',
          '#ff842f', '#f5670c', '#d94a05', '#9f2a0b',
        ]}
        emptyColor="transparent"
        tooltip={({ row, column, value }) => (
          <>
            <strong>{categories[row]}</strong><br />
            {periods[column].label}: {value} 件
          </>
        )}
        cellLabel={({ row, column, value }) => (
          `${categories[row]}、${periods[column].label}、${value} 件`
        )}
        showLegend={false}
        overflow="scroll"
        scrollAnchor="end"
        ariaLabel="カテゴリーと期間ごとの公開記事数を表すヒートマップ"
        scale="quantile"
      />
    )
  }
}

