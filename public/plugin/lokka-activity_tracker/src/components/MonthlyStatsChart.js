import React, { PureComponent } from 'react'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid,
  Tooltip, Legend, ResponsiveContainer
} from 'recharts'
import { t } from '../i18n'

export default class MonthlyStatsChart extends PureComponent {
  constructor(props) {
    super(props)
    this.state = {
      data: [],
      loading: true,
      error: null
    }
  }

  async componentDidMount() {
    try {
      const { year } = this.props
      const url = year
        ? `/activities/monthly_stats.json?year=${year}`
        : '/activities/monthly_stats.json'
      const response = await fetch(url)
      if (!response.ok) {
        throw new Error('Failed to load monthly stats')
      }
      const data = await response.json()
      // Sort by year and month ascending (oldest first, left to right)
      const sortedData = data.sort((a, b) => {
        if (a.year !== b.year) return a.year - b.year
        return a.month - b.month
      })
      this.setState({ data: sortedData, loading: false })
    } catch (error) {
      this.setState({ error: error.message, loading: false })
    }
  }

  formatTooltip(value, name) {
    const { i18n } = this.props
    if (name === t(i18n, 'monthly_distance', 'Distance')) {
      return [`${Math.floor(value * 10) / 10} km`, name]
    }
    if (name === t(i18n, 'monthly_elevation', 'Elevation Gain')) {
      return [`${Math.floor(value)} m`, name]
    }
    return [value, name]
  }

  render() {
    const { data, loading, error } = this.state
    const { i18n } = this.props

    if (loading) {
      return <div className="monthly-chart-loading">{t(i18n, 'monthly_loading', 'Loading...')}</div>
    }

    if (error) {
      return <div className="monthly-chart-error">{t(i18n, 'error_prefix', 'Error: ')}{error}</div>
    }

    if (data.length === 0) {
      return <div className="monthly-chart-empty">{t(i18n, 'monthly_empty', 'No data available')}</div>
    }

    return (
      <ResponsiveContainer width="100%" height={300}>
        <BarChart
          data={data}
          margin={{ top: 20, right: 30, left: 20, bottom: 20 }}
        >
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis dataKey="label" tick={{ fontSize: 12 }} />
          <YAxis
            yAxisId="distance"
            orientation="left"
            tick={{ fontSize: 12 }}
            label={{ value: 'km', angle: -90, position: 'insideLeft', fontSize: 12 }}
          />
          <YAxis
            yAxisId="elevation"
            orientation="right"
            tick={{ fontSize: 12 }}
            label={{ value: 'm', angle: 90, position: 'insideRight', fontSize: 12 }}
          />
          <Tooltip formatter={(value, name) => this.formatTooltip(value, name)} />
          <Legend />
          <Bar
            yAxisId="distance"
            dataKey="total_distance_km"
            name={t(i18n, 'monthly_distance', 'Distance')}
            fill="#4B6A8A"
            radius={[4, 4, 0, 0]}
          />
          <Bar
            yAxisId="elevation"
            dataKey="total_ascent_meters"
            name={t(i18n, 'monthly_elevation', 'Elevation Gain')}
            fill="#5D6B5A"
            radius={[4, 4, 0, 0]}
          />
        </BarChart>
      </ResponsiveContainer>
    )
  }
}
