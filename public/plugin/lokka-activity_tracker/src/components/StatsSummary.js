import React from 'react'

const formatDuration = (seconds) => {
  if (!seconds) return '-'
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  const secs = seconds % 60
  if (hours > 0) {
    return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }
  return `${minutes}:${secs.toString().padStart(2, '0')}`
}

const formatDistance = (meters) => {
  if (!meters) return '-'
  const km = meters / 1000
  return `${km.toFixed(2)} km`
}

const formatPace = (avgSpeed) => {
  if (!avgSpeed || avgSpeed <= 0) return '-'
  const paceSeconds = 1000 / avgSpeed
  const minutes = Math.floor(paceSeconds / 60)
  const seconds = Math.floor(paceSeconds % 60)
  return `${minutes}'${seconds.toString().padStart(2, '0')}" /km`
}

export default function StatsSummary({ activity, compact = false }) {
  const stats = [
    {
      label: 'Distance',
      value: formatDistance(activity.total_distance_meters),
      icon: '📏'
    },
    {
      label: 'Duration',
      value: formatDuration(activity.duration_seconds),
      icon: '⏱️'
    },
    {
      label: 'Pace',
      value: formatPace(activity.avg_speed),
      icon: '🏃'
    },
    {
      label: 'Avg HR',
      value: activity.avg_heart_rate ? `${activity.avg_heart_rate} bpm` : '-',
      icon: '❤️'
    },
    {
      label: 'Max HR',
      value: activity.max_heart_rate ? `${activity.max_heart_rate} bpm` : '-',
      icon: '💓'
    },
    {
      label: 'Elevation',
      value: activity.total_ascent_meters ? `${Math.round(activity.total_ascent_meters)} m` : '-',
      icon: '⛰️'
    }
  ]

  if (activity.avg_cadence) {
    stats.push({
      label: 'Cadence',
      value: `${activity.avg_cadence} spm`,
      icon: '👟'
    })
  }

  if (activity.avg_power) {
    stats.push({
      label: 'Power',
      value: `${activity.avg_power} W`,
      icon: '⚡'
    })
  }

  const displayStats = compact ? stats.slice(0, 4) : stats

  return (
    <div className={`stats-summary ${compact ? 'stats-summary-compact' : ''}`}>
      {displayStats.map((stat, index) => (
        <div key={index} className="stat-item">
          <span className="stat-icon">{stat.icon}</span>
          <span className="stat-value">{stat.value}</span>
          <span className="stat-label">{stat.label}</span>
        </div>
      ))}
    </div>
  )
}
