import React from 'react'
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  ReferenceLine,
  Cell
} from 'recharts'

// Format pace seconds to mm:ss string
const formatPace = (paceSeconds) => {
  if (!paceSeconds || paceSeconds <= 0) return '-'
  const minutes = Math.floor(paceSeconds / 60)
  const seconds = Math.round(paceSeconds % 60)
  return `${minutes}'${seconds.toString().padStart(2, '0')}"`
}

const BASE_COLOR = '#64B5F6'

const hexToRgb = (hex) => {
  const cleaned = hex.replace('#', '')
  const value = cleaned.length === 3
    ? cleaned.split('').map((c) => c + c).join('')
    : cleaned
  const num = parseInt(value, 16)
  return {
    r: (num >> 16) & 255,
    g: (num >> 8) & 255,
    b: num & 255
  }
}

const clamp = (value, min, max) => Math.min(Math.max(value, min), max)

const mixWithWhite = (hex, ratio) => {
  const { r, g, b } = hexToRgb(hex)
  const t = clamp(ratio, 0, 1)
  const mix = (channel) => Math.round(channel + (255 - channel) * t)
  return `rgb(${mix(r)}, ${mix(g)}, ${mix(b)})`
}

export default function SplitsChart({ splits, height = 300 }) {
  if (!splits || splits.length === 0) {
    return <div className="splits-chart-empty">No split data available</div>
  }

  // Calculate average pace
  const avgPace = splits.reduce((sum, s) => sum + (s.pace_seconds || 0), 0) / splits.length

  // Find max/min for domain and shading
  const paces = splits.map(s => s.pace_seconds).filter(p => p > 0)
  const maxPaceRaw = Math.max(...paces)
  const minPaceRaw = Math.min(...paces)
  const paceRange = maxPaceRaw - minPaceRaw
  const fastestPace = minPaceRaw
  const slowestPace = maxPaceRaw

  const minValueRatio = 0.7
  const paceToValue = (pace) => {
    if (paceRange <= 0) return 1
    const t = clamp((maxPaceRaw - pace) / paceRange, 0, 1)
    return (1 - minValueRatio) * t + minValueRatio
  }
  const maxValue = 1.1

  // Prepare data for chart (faster => larger bar)
  const data = splits.map(split => ({
    km: `${split.km} km`,
    pace: split.pace_seconds,
    paceValue: paceToValue(split.pace_seconds),
    paceFormatted: formatPace(split.pace_seconds)
  }))

  const fastestIndex = paces.length ? splits.findIndex(s => s.pace_seconds === fastestPace) : -1
  const slowestIndex = paces.length ? splits.findIndex(s => s.pace_seconds === slowestPace) : -1

  const shadeSteps = [0.2, 0.15, 0.1, 0.05, 0.0]
  const paceToShade = (pace) => {
    if (!pace || paceRange <= 0) return shadeSteps[2]
    const t = clamp((pace - minPaceRaw) / paceRange, 0, 1)
    const idx = Math.round(t * (shadeSteps.length - 1))
    return shadeSteps[idx]
  }

  const formatPaceFromValue = (value) => {
    if (value === undefined || value === null) return '-'
    const t = clamp((value - minValueRatio) / (1 - minValueRatio), 0, 1)
    const pace = maxPaceRaw - (t * paceRange)
    if (!pace || pace <= 0) return '-'
    return formatPace(pace)
  }

  const CustomTooltip = ({ active, payload }) => {
    if (active && payload && payload.length) {
      const { km, paceFormatted } = payload[0].payload
      return (
        <div className="splits-tooltip" style={{
          backgroundColor: 'white',
          padding: '8px 12px',
          border: '1px solid #ccc',
          borderRadius: '4px'
        }}>
          <p style={{ margin: 0, fontWeight: 'bold' }}>{km}</p>
          <p style={{ margin: 0 }}>Pace: {paceFormatted}</p>
        </div>
      )
    }
    return null
  }

  return (
    <div className="splits-chart">
      <ResponsiveContainer width="100%" height={height}>
        <BarChart
          data={data}
          layout="horizontal"
          margin={{ top: 28, right: 50, left: 20, bottom: 30 }}
        >
          <CartesianGrid strokeDasharray="3 3" horizontal={true} vertical={false} />
          <XAxis
            type="category"
            dataKey="km"
            tick={{ fontSize: 12 }}
          />
          <YAxis
            type="number"
            domain={[0, maxValue]}
            tickFormatter={formatPaceFromValue}
          />
          <Tooltip content={<CustomTooltip />} />
          <ReferenceLine
            y={paceToValue(avgPace)}
            stroke="#666"
            strokeDasharray="5 5"
            label={{ value: `Avg: ${formatPace(avgPace)}`, position: 'right', offset: 10, fontSize: 11 }}
          />
          {fastestPace && (
            <ReferenceLine
              y={paceToValue(fastestPace)}
              stroke="#1E88E5"
              strokeDasharray="3 3"
              label={{ value: `Fastest: ${formatPace(fastestPace)}`, position: 'right', offset: 10, fontSize: 11 }}
            />
          )}
          {slowestPace && (
            <ReferenceLine
              y={paceToValue(slowestPace)}
              stroke="#1E88E5"
              strokeDasharray="3 3"
              label={{ value: `Slowest: ${formatPace(slowestPace)}`, position: 'right', offset: 10, fontSize: 11 }}
            />
          )}
          <Bar dataKey="paceValue" radius={[0, 4, 4, 0]}>
            {data.map((entry, index) => (
              <Cell
                key={`cell-${index}`}
                fill={mixWithWhite(BASE_COLOR, paceToShade(entry.pace))}
                stroke={index === fastestIndex || index === slowestIndex ? '#1E88E5' : undefined}
                strokeWidth={index === fastestIndex || index === slowestIndex ? 1.5 : 0}
              />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  )
}
