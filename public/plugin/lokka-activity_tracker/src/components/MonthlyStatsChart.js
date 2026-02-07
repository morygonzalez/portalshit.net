import React, { PureComponent } from 'react'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid,
  Tooltip, Legend, ResponsiveContainer
} from 'recharts'

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
      const response = await fetch('/activities/monthly_stats.json')
      if (!response.ok) {
        throw new Error('Failed to load monthly stats')
      }
      const data = await response.json()
      // Reverse to show oldest first (left to right)
      this.setState({ data: data.reverse(), loading: false })
    } catch (error) {
      this.setState({ error: error.message, loading: false })
    }
  }

  formatTooltip(value, name) {
    if (name === 'Distance (km)') {
      return [`${value} km`, name]
    }
    return [value, name]
  }

  render() {
    const { data, loading, error } = this.state

    if (loading) {
      return <div className="monthly-chart-loading">Loading...</div>
    }

    if (error) {
      return <div className="monthly-chart-error">Error: {error}</div>
    }

    if (data.length === 0) {
      return <div className="monthly-chart-empty">No data available</div>
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
            yAxisId="count"
            orientation="right"
            tick={{ fontSize: 12 }}
            label={{ value: 'count', angle: 90, position: 'insideRight', fontSize: 12 }}
          />
          <Tooltip formatter={this.formatTooltip} />
          <Legend />
          <Bar
            yAxisId="distance"
            dataKey="total_distance_km"
            name="Distance (km)"
            fill="#1E88E5"
            radius={[4, 4, 0, 0]}
          />
          <Bar
            yAxisId="count"
            dataKey="count"
            name="Activities"
            fill="#43A047"
            radius={[4, 4, 0, 0]}
          />
        </BarChart>
      </ResponsiveContainer>
    )
  }
}
