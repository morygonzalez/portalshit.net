import React from 'react'
import { t } from '../i18n'

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

const formatPaceFromSpeed = (avgSpeed) => {
  if (!avgSpeed || avgSpeed <= 0) return null
  const paceSeconds = 1000 / avgSpeed
  const minutes = Math.floor(paceSeconds / 60)
  const seconds = Math.floor(paceSeconds % 60)
  return `${minutes}'${seconds.toString().padStart(2, '0')}" /km`
}

const formatPaceFromDistanceTime = (distanceMeters, durationSeconds) => {
  if (!distanceMeters || !durationSeconds || distanceMeters <= 0 || durationSeconds <= 0) return null
  const distanceKm = distanceMeters / 1000
  const paceSeconds = durationSeconds / distanceKm
  const minutes = Math.floor(paceSeconds / 60)
  const seconds = Math.floor(paceSeconds % 60)
  return `${minutes}'${seconds.toString().padStart(2, '0')}" /km`
}

const formatPace = (activity) => {
  // Try avg_speed first, then calculate from distance and duration
  return formatPaceFromSpeed(activity.avg_speed) ||
         formatPaceFromDistanceTime(activity.total_distance_meters, activity.duration_seconds) ||
         '-'
}

const localizeActivityType = (activityType, i18n) => {
  if (!activityType) return null
  const key = `activity_type_${activityType}`
  const defaultValue = activityType.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
  return t(i18n, key, defaultValue)
}

export default function StatsSummary({ activity, compact = false, i18n }) {
  // Stats for compact mode (embed): Type, Distance, Duration, Pace, Avg HR
  const compactStats = [
    {
      label: t(i18n, 'metric_type', 'Type'),
      value: localizeActivityType(activity.activity_type, i18n)
    },
    {
      label: t(i18n, 'metric_distance', 'Distance'),
      value: formatDistance(activity.total_distance_meters)
    },
    {
      label: t(i18n, 'metric_duration', 'Duration'),
      value: formatDuration(activity.duration_seconds)
    },
    {
      label: t(i18n, 'metric_pace', 'Pace'),
      value: formatPace(activity)
    },
    {
      label: t(i18n, 'metric_avg_hr', 'Avg HR'),
      value: activity.avg_heart_rate ? `${activity.avg_heart_rate} bpm` : null
    }
  ]

  // Full stats for activity page
  const fullStats = [
    ...compactStats,
    {
      label: t(i18n, 'metric_max_hr', 'Max HR'),
      value: activity.max_heart_rate ? `${activity.max_heart_rate} bpm` : null
    },
    {
      label: t(i18n, 'metric_elevation', 'Elevation'),
      value: activity.total_ascent_meters ? `${Math.round(activity.total_ascent_meters)} m` : null
    }
  ]

  if (activity.avg_cadence) {
    fullStats.push({
      label: t(i18n, 'metric_cadence', 'Cadence'),
      value: `${activity.avg_cadence} spm`
    })
  }

  if (activity.avg_power) {
    fullStats.push({
      label: t(i18n, 'metric_power', 'Power'),
      value: `${activity.avg_power} W`
    })
  }

  const stats = compact ? compactStats : fullStats
  // Filter out stats with no value
  const displayStats = stats.filter(stat => stat.value !== null && stat.value !== '-')

  return (
    <div className={`activity-stats-grid ${compact ? 'activity-stats-grid-compact' : ''}`}>
      {displayStats.map((stat, index) => (
        <div key={index} className="activity-stat">
          <div className="activity-stat-label">{stat.label}</div>
          <div className="activity-stat-value">{stat.value}</div>
        </div>
      ))}
    </div>
  )
}
