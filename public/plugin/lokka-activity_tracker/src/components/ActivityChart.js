import React, { PureComponent } from 'react'
import {
  ComposedChart,
  Line,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  ReferenceLine
} from 'recharts'
import { t } from '../i18n'

// Selectable metrics (shown as lines, user can toggle)
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

// Altitude is always shown as an area chart (not selectable)
const ALTITUDE_CONFIG = {
  labelKey: 'metric_altitude',
  label: 'Altitude',
  unit: 'm',
  color: '#9E9E9E',
  fillColor: 'rgba(158, 158, 158, 0.3)'
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

const MOBILE_BREAKPOINT = 768

export default class ActivityChart extends PureComponent {
  constructor(props) {
    super(props)
    this.state = {
      isMobile: window.innerWidth < MOBILE_BREAKPOINT
    }
    this.formatXAxis = this.formatXAxis.bind(this)
    this.formatTooltip = this.formatTooltip.bind(this)
    this.handleMouseMove = this.handleMouseMove.bind(this)
    this.handleMouseLeave = this.handleMouseLeave.bind(this)
    this.handleResize = this.handleResize.bind(this)
  }

  handleResize() {
    const isMobile = window.innerWidth < MOBILE_BREAKPOINT
    if (isMobile !== this.state.isMobile) {
      this.setState({ isMobile })
    }
  }

  componentDidMount() {
    window.addEventListener('resize', this.handleResize)
  }

  componentWillUnmount() {
    window.removeEventListener('resize', this.handleResize)
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

  hasAltitudeData() {
    const { dataPoints } = this.props
    return dataPoints.some(dp => dp.altitude_meters !== null && dp.altitude_meters !== undefined)
  }

  prepareData() {
    const { dataPoints, selectedMetrics } = this.props
    const includeAltitude = this.hasAltitudeData()

    return dataPoints
      .filter(dp => dp.elapsed_seconds !== null && dp.distance_meters !== null)
      .map(dp => {
        const point = {
          elapsed_seconds: dp.elapsed_seconds,
          distance_km: dp.distance_meters / 1000
        }
        // Always include altitude for the area chart
        if (includeAltitude) {
          point.altitude_meters = dp.altitude_meters
        }
        // Include selected metrics for line charts
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

  formatTooltipWithAltitude(value, name, i18n) {
    // Check if this is altitude
    if (name === t(i18n, ALTITUDE_CONFIG.labelKey, ALTITUDE_CONFIG.label)) {
      return [`${Math.round(value)} ${ALTITUDE_CONFIG.unit}`, name]
    }
    return this.formatTooltip(value, name, i18n)
  }

  render() {
    const { selectedMetrics, height = 400, compact = false, i18n } = this.props
    const { isMobile } = this.state
    const data = this.prepareData()
    const hasAltitude = this.hasAltitudeData()

    if (data.length === 0) {
      return <div className="activity-chart-empty">{t(i18n, 'chart_empty', 'No data available')}</div>
    }

    const maxDistance = data.length > 0 ? Math.max(...data.map(d => d.distance_km)) : 0
    const distanceTicks = getDistanceTicks(maxDistance)
    const useCompact = compact || isMobile

    return (
      <ResponsiveContainer width="100%" height={height}>
        <ComposedChart
          data={data}
          margin={{
            top: 10,
            right: useCompact ? 0 : 30,
            left: useCompact ? 0 : 20,
            bottom: useCompact ? 0 : 10
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
            tick={{ fontSize: useCompact ? 10 : 12 }}
            stroke="#666"
            unit=" km"
          />
          {/* Altitude Y-axis (always present if data exists, hidden axis) */}
          {hasAltitude && (
            <YAxis
              yAxisId="altitude"
              orientation="right"
              domain={['dataMin', 'dataMax']}
              hide={true}
            />
          )}
          {/* Selected metrics Y-axes */}
          {selectedMetrics.map((metric, index) => {
            const config = METRIC_CONFIG[metric]
            if (!config) return null

            return (
              <YAxis
                key={metric}
                yAxisId={metric}
                orientation={index === 0 ? 'left' : 'right'}
                domain={config.domain}
                tick={isMobile ? false : { fontSize: useCompact ? 10 : 12 }}
                tickLine={!isMobile}
                width={isMobile && index === 0 ? 0 : undefined}
                stroke={config.color}
                hide={useCompact && index > 0}
                reversed={config.reversed || false}
                tickFormatter={metric === 'pace' ? formatPace : undefined}
              />
            )
          })}
          <Tooltip
            formatter={(value, name) => this.formatTooltipWithAltitude(value, name, i18n)}
            labelFormatter={(label) => `${t(i18n, 'chart_distance_label', 'Distance')}: ${label.toFixed(2)} km`}
            labelStyle={{ color: '#000', fontWeight: 'bold' }}
            itemStyle={{ margin: '0 2px 0 4px', padding: '0' }}
          />
          {!useCompact && <Legend />}
          {/* Altitude area chart (always shown, rendered first so it's behind lines) */}
          {hasAltitude && (
            <Area
              yAxisId="altitude"
              type="monotone"
              dataKey="altitude_meters"
              name={t(i18n, ALTITUDE_CONFIG.labelKey, ALTITUDE_CONFIG.label)}
              stroke={ALTITUDE_CONFIG.color}
              fill={ALTITUDE_CONFIG.fillColor}
              strokeWidth={1}
              dot={false}
              connectNulls={true}
            />
          )}
          {/* Selected metrics line charts */}
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
                strokeWidth={useCompact ? 1 : 2}
                connectNulls={true}
              />
            )
          })}
        </ComposedChart>
      </ResponsiveContainer>
    )
  }
}
