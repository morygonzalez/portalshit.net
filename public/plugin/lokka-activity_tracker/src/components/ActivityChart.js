import React, { PureComponent } from 'react'
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  ReferenceLine
} from 'recharts'

const METRIC_CONFIG = {
  heart_rate: {
    label: 'Heart Rate',
    unit: 'bpm',
    color: '#A24E4E',
    domain: [60, 200]
  },
  pace: {
    label: 'Pace',
    unit: 'min/km',
    color: '#3B6D8C',
    domain: ['auto', 'auto'],
    reversed: true // Lower pace is better
  },
  altitude_meters: {
    label: 'Altitude',
    unit: 'm',
    color: '#4E7A5A',
    domain: ['auto', 'auto']
  },
  cadence: {
    label: 'Cadence',
    unit: 'spm',
    color: '#B07A3D',
    domain: [0, 200]
  },
  power: {
    label: 'Power',
    unit: 'W',
    color: '#6D5A9C',
    domain: [0, 'auto']
  }
}

// Convert speed (m/s) to pace (min/km)
const speedToPace = (speed) => {
  if (!speed || speed <= 0) return null
  return (1000 / speed) / 60 // minutes per km
}

// Format pace as mm:ss
const formatPace = (paceMinutes) => {
  if (!paceMinutes || paceMinutes <= 0) return '-'
  const minutes = Math.floor(paceMinutes)
  const seconds = Math.round((paceMinutes - minutes) * 60)
  return `${minutes}'${seconds.toString().padStart(2, '0')}"`
}

export default class ActivityChart extends PureComponent {
  constructor(props) {
    super(props)
    this.formatXAxis = this.formatXAxis.bind(this)
    this.formatTooltip = this.formatTooltip.bind(this)
    this.handleMouseMove = this.handleMouseMove.bind(this)
    this.handleMouseLeave = this.handleMouseLeave.bind(this)
  }

  formatXAxis(seconds) {
    if (seconds === undefined || seconds === null) return ''
    const hours = Math.floor(seconds / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}`
    }
    return `${minutes}m`
  }

  formatTooltip(value, name) {
    if (name === 'Pace') {
      return [formatPace(value), name]
    }
    const config = Object.values(METRIC_CONFIG).find(c => c.label === name)
    if (config) {
      return [`${value} ${config.unit}`, name]
    }
    return [value, name]
  }

  handleMouseMove(state) {
    const { onHoverChange } = this.props
    if (!onHoverChange) return

    if (!state || !state.activePayload || state.activePayload.length === 0) {
      onHoverChange(null)
      return
    }

    const payload = state.activePayload[0] && state.activePayload[0].payload
    if (!payload || payload.elapsed_seconds === undefined || payload.elapsed_seconds === null) {
      onHoverChange(null)
      return
    }

    onHoverChange(payload.elapsed_seconds)
  }

  handleMouseLeave() {
    const { onHoverChange } = this.props
    if (onHoverChange) {
      onHoverChange(null)
    }
  }

  prepareData() {
    const { dataPoints, selectedMetrics } = this.props

    return dataPoints
      .filter(dp => dp.elapsed_seconds !== null)
      .map(dp => {
        const point = { elapsed_seconds: dp.elapsed_seconds }
        selectedMetrics.forEach(metric => {
          if (metric === 'pace') {
            point[metric] = speedToPace(dp.speed)
          } else {
            point[metric] = dp[metric]
          }
        })
        return point
      })
  }

  render() {
    const { selectedMetrics, height = 400, compact = false } = this.props
    const data = this.prepareData()

    if (data.length === 0) {
      return <div className="activity-chart-empty">No data available</div>
    }

    return (
      <ResponsiveContainer width="100%" height={height}>
        <LineChart
          data={data}
          margin={{
            top: 10,
            right: compact ? 10 : 30,
            left: compact ? 0 : 20,
            bottom: compact ? 0 : 10
          }}
          onMouseMove={this.handleMouseMove}
          onMouseLeave={this.handleMouseLeave}
        >
          <CartesianGrid strokeDasharray="3 3" stroke="#eee" />
          <XAxis
            dataKey="elapsed_seconds"
            tickFormatter={this.formatXAxis}
            tick={{ fontSize: compact ? 10 : 12 }}
            stroke="#666"
          />
          {selectedMetrics.map((metric, index) => {
            const config = METRIC_CONFIG[metric]
            if (!config) return null

            return (
              <YAxis
                key={metric}
                yAxisId={metric}
                orientation={index === 0 ? 'left' : 'right'}
                domain={config.domain}
                tick={{ fontSize: compact ? 10 : 12 }}
                stroke={config.color}
                hide={compact && index > 0}
                reversed={config.reversed || false}
                tickFormatter={metric === 'pace' ? formatPace : undefined}
              />
            )
          })}
          <Tooltip
            formatter={this.formatTooltip}
            labelFormatter={(label) => `Time: ${this.formatXAxis(label)}`}
            contentStyle={{ fontSize: compact ? 11 : 13 }}
          />
          {!compact && <Legend />}
          {selectedMetrics.map(metric => {
            const config = METRIC_CONFIG[metric]
            if (!config) return null

            return (
              <Line
                key={metric}
                yAxisId={metric}
                type="monotone"
                dataKey={metric}
                name={config.label}
                stroke={config.color}
                dot={false}
                strokeWidth={compact ? 1 : 2}
                connectNulls={true}
              />
            )
          })}
        </LineChart>
      </ResponsiveContainer>
    )
  }
}
