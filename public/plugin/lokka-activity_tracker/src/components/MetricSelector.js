import React from 'react'

const AVAILABLE_METRICS = [
  { key: 'heart_rate', label: 'Heart Rate', checkField: 'heart_rate' },
  { key: 'speed', label: 'Speed', checkField: 'speed' },
  { key: 'pace', label: 'Pace', checkField: 'speed' }, // Pace is derived from speed
  { key: 'altitude_meters', label: 'Altitude', checkField: 'altitude_meters' },
  { key: 'cadence', label: 'Cadence', checkField: 'cadence' },
  { key: 'power', label: 'Power', checkField: 'power' }
]

export default function MetricSelector({ selectedMetrics, onChange, dataPoints }) {
  // Check which metrics have data
  const hasData = (field) => {
    return dataPoints.some(dp => dp[field] !== null && dp[field] !== undefined)
  }

  const availableMetrics = AVAILABLE_METRICS.filter(m => hasData(m.checkField))

  const handleChange = (metricKey) => {
    let newSelection
    if (selectedMetrics.includes(metricKey)) {
      // Remove if already selected (but keep at least one)
      if (selectedMetrics.length > 1) {
        newSelection = selectedMetrics.filter(m => m !== metricKey)
      } else {
        return // Don't allow deselecting the last metric
      }
    } else {
      // Add if not selected (max 2 for dual axis)
      if (selectedMetrics.length < 2) {
        newSelection = [...selectedMetrics, metricKey]
      } else {
        // Replace the second one
        newSelection = [selectedMetrics[0], metricKey]
      }
    }
    onChange(newSelection)
  }

  if (availableMetrics.length === 0) {
    return null
  }

  return (
    <div className="metric-selector">
      <span className="metric-selector-label">Show: </span>
      {availableMetrics.map(metric => (
        <button
          key={metric.key}
          className={`metric-button ${selectedMetrics.includes(metric.key) ? 'active' : ''}`}
          onClick={() => handleChange(metric.key)}
        >
          {metric.label}
        </button>
      ))}
    </div>
  )
}
