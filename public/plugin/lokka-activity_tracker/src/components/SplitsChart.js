import React from 'react'
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Cell,
  ReferenceLine
} from 'recharts'

// Format pace seconds to mm:ss string
const formatPace = (paceSeconds) => {
  if (!paceSeconds || paceSeconds <= 0) return '-'
  const minutes = Math.floor(paceSeconds / 60)
  const seconds = Math.round(paceSeconds % 60)
  return `${minutes}'${seconds.toString().padStart(2, '0')}"`
}

// Get color based on pace relative to average
const getPaceColor = (pace, avgPace) => {
  if (!pace || !avgPace) return '#1E88E5'
  const ratio = pace / avgPace
  if (ratio < 0.95) return '#43A047' // Faster than average - green
  if (ratio > 1.05) return '#E53935' // Slower than average - red
  return '#1E88E5' // Near average - blue
}

export default function SplitsChart({ splits, height = 300 }) {
  if (!splits || splits.length === 0) {
    return <div className="splits-chart-empty">No split data available</div>
  }

  // Prepare data for chart
  const data = splits.map(split => ({
    km: `${split.km} km`,
    pace: split.pace_seconds,
    paceFormatted: formatPace(split.pace_seconds)
  }))

  // Calculate average pace
  const avgPace = splits.reduce((sum, s) => sum + (s.pace_seconds || 0), 0) / splits.length

  // Find max for domain (start from 0)
  const paces = splits.map(s => s.pace_seconds).filter(p => p > 0)
  const maxPace = Math.max(...paces) * 1.15

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
          layout="vertical"
          margin={{ top: 28, right: 50, left: 50, bottom: 10 }}
        >
          <CartesianGrid strokeDasharray="3 3" horizontal={true} vertical={false} />
          <XAxis
            type="number"
            domain={[0, maxPace]}
            tickFormatter={(value) => formatPace(value)}
          />
          <YAxis
            type="category"
            dataKey="km"
            tick={{ fontSize: 12 }}
            width={50}
          />
          <Tooltip content={<CustomTooltip />} />
          <ReferenceLine
            x={avgPace}
            stroke="#666"
            strokeDasharray="5 5"
            label={{ value: `Avg: ${formatPace(avgPace)}`, position: 'top', offset: 10, fontSize: 11 }}
          />
          <Bar dataKey="pace" radius={[0, 4, 4, 0]}>
            {data.map((entry, index) => (
              <Cell
                key={`cell-${index}`}
                fill={getPaceColor(entry.pace, avgPace)}
              />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  )
}
