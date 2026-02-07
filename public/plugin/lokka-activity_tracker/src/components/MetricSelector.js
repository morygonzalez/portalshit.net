import React from 'react'
import { t } from '../i18n'

const AVAILABLE_METRICS = [
  { key: 'heart_rate', labelKey: 'metric_heart_rate', label: 'Heart Rate', checkField: 'heart_rate' },
  { key: 'pace', labelKey: 'metric_pace', label: 'Pace', checkField: 'speed' }, // Pace is derived from speed
  { key: 'altitude_meters', labelKey: 'metric_altitude', label: 'Altitude', checkField: 'altitude_meters' },
  { key: 'cadence', labelKey: 'metric_cadence', label: 'Cadence', checkField: 'cadence' },
  { key: 'power', labelKey: 'metric_power', label: 'Power', checkField: 'power' }
]

export default function MetricSelector({ selectedMetrics, onChange, dataPoints, i18n }) {
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
      <span className="metric-selector-label">{t(i18n, 'metric_show_label', 'Show: ')} </span>
      {availableMetrics.map(metric => (
        <button
          key={metric.key}
          className={`metric-button ${selectedMetrics.includes(metric.key) ? 'active' : ''}`}
          onClick={() => handleChange(metric.key)}
        >
          {t(i18n, metric.labelKey, metric.label)}
        </button>
      ))}
    </div>
  )
}
