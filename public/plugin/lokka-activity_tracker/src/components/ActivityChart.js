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
import { t } from '../i18n'

const METRIC_CONFIG = {
  heart_rate: {
    labelKey: 'metric_heart_rate',
    label: 'Heart Rate',
    unit: 'bpm',
    color: '#E53935',
    domain: [60, 200]
  },
  pace: {
    labelKey: 'metric_pace',
    label: 'Pace',
    unit: 'min/km',
    color: '#1E88E5',
    domain: ['auto', 'auto'],
    reversed: true // Lower pace is better
  },
  altitude_meters: {
    labelKey: 'metric_altitude',
    label: 'Altitude',
    unit: 'm',
    color: '#43A047',
    domain: ['auto', 'auto']
  },
  cadence: {
    labelKey: 'metric_cadence',
    label: 'Cadence',
    unit: 'spm',
    color: '#FFB300',
    domain: [0, 200]
  },
  power: {
    labelKey: 'metric_power',
    label: 'Power',
    unit: 'W',
    color: '#8E24AA',
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

// Calculate appropriate tick interval based on total distance
const getDistanceTicks = (maxDistanceKm) => {
  if (maxDistanceKm <= 0) return [0]

  let interval
  if (maxDistanceKm <= 10) {
    interval = 1
  } else if (maxDistanceKm <= 50) {
    interval = 5
  } else {
    interval = 10
  }

  const ticks = []
  for (let i = 0; i <= maxDistanceKm; i += interval) {
    ticks.push(i)
  }
  return ticks
}

export default class ActivityChart extends PureComponent {
  constructor(props) {
    super(props)
    this.formatXAxis = this.formatXAxis.bind(this)
    this.formatTooltip = this.formatTooltip.bind(this)
    this.handleMouseMove = this.handleMouseMove.bind(this)
    this.handleMouseLeave = this.handleMouseLeave.bind(this)
  }

  formatXAxis(distanceKm) {
    if (distanceKm === undefined || distanceKm === null) return ''
    return `${distanceKm.toFixed(1)}`
  }

  formatTooltip(value, name, i18n) {
    const config = Object.values(METRIC_CONFIG).find(c => t(i18n, c.labelKey, c.label) === name)
    if (config && config.labelKey === 'metric_pace') {
      return [formatPace(value), name]
    }
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
      .filter(dp => dp.elapsed_seconds !== null && dp.distance_meters !== null)
      .map(dp => {
        const point = {
          elapsed_seconds: dp.elapsed_seconds,
          distance_km: dp.distance_meters / 1000
        }
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
    const { selectedMetrics, height = 400, compact = false, i18n } = this.props
    const data = this.prepareData()

    if (data.length === 0) {
      return <div className="activity-chart-empty">{t(i18n, 'chart_empty', 'No data available')}</div>
    }

    const maxDistance = data.length > 0 ? Math.max(...data.map(d => d.distance_km)) : 0
    const distanceTicks = getDistanceTicks(maxDistance)

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
            dataKey="distance_km"
            type="number"
            domain={[0, 'dataMax']}
            ticks={distanceTicks}
            tickFormatter={(value) => `${value}`}
            tick={{ fontSize: compact ? 10 : 12 }}
            stroke="#666"
            unit=" km"
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
            formatter={(value, name) => this.formatTooltip(value, name, i18n)}
            labelFormatter={(label) => `${t(i18n, 'chart_distance_label', 'Distance')}: ${label.toFixed(2)} km`}
            labelStyle={{ color: '#000', fontWeight: 'bold' }}
            itemStyle={{ margin: '0 2px 0 4px', padding: '0' }}
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
                name={t(i18n, config.labelKey, config.label)}
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
