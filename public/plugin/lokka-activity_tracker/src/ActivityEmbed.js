import React, { Component } from 'react'
import ActivityMap from './components/ActivityMap'
import StatsSummary from './components/StatsSummary'
import { t } from './i18n'

export default class ActivityEmbed extends Component {
  constructor(props) {
    super(props)
    this.state = {
      activity: null,
      loading: true,
      error: null
    }
  }

  async componentDidMount() {
    try {
      const response = await fetch(`/activities/${this.props.activityHash}.json`)
      if (!response.ok) {
        throw new Error(t(this.props.i18n, 'embed_load_failed', 'Failed to load activity data'))
      }
      const activity = await response.json()
      this.setState({ activity, loading: false })
    } catch (error) {
      this.setState({ error: error.message, loading: false })
    }
  }

  render() {
    const { activity, loading, error } = this.state
    const { i18n } = this.props

    if (loading) {
      return <div className="activity-embed-loading">{t(i18n, 'loading', 'Loading...')}</div>
    }

    if (error) {
      return <div className="activity-embed-error">{t(i18n, 'error_prefix', 'Error: ')}{error}</div>
    }

    if (!activity) {
      return null
    }

    // Use map_points for display (with home location filtered out), fall back to data_points
    const mapPoints = activity.map_points || activity.data_points
    const hasGpsData = mapPoints.some(
      (dp) => dp.latitude !== null && dp.longitude !== null
    )

    return (
      <div className="activity-embed-content">
        <div className="activity-embed-header">
          <a href={`/activities/${activity.file_hash}`} className="activity-embed-title">
            {activity.title}
          </a>
        </div>

        <StatsSummary activity={activity} compact={true} i18n={i18n} />

        {hasGpsData && (
          <div className="activity-embed-map">
            <ActivityMap dataPoints={mapPoints} height={200} />
          </div>
        )}

        <a href={`/activities/${activity.file_hash}`} className="activity-embed-link">
          {t(i18n, 'embed_view_full', 'View full activity →')}
        </a>
      </div>
    )
  }
}
