import React, { Component } from 'react'
import ActivityChart from './components/ActivityChart'
import StatsSummary from './components/StatsSummary'

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
      const response = await fetch(`/activities/${this.props.activityId}.json`)
      if (!response.ok) {
        throw new Error('Failed to load activity data')
      }
      const activity = await response.json()
      this.setState({ activity, loading: false })
    } catch (error) {
      this.setState({ error: error.message, loading: false })
    }
  }

  render() {
    const { activity, loading, error } = this.state

    if (loading) {
      return <div className="activity-embed-loading">Loading...</div>
    }

    if (error) {
      return <div className="activity-embed-error">Error: {error}</div>
    }

    if (!activity) {
      return null
    }

    return (
      <div className="activity-embed-content">
        <div className="activity-embed-header">
          <a href={`/activities/${activity.id}`} className="activity-embed-title">
            {activity.title}
          </a>
          <span className="activity-embed-type">
            {activity.activity_type}
          </span>
        </div>

        <StatsSummary activity={activity} compact={true} />

        <div className="activity-embed-chart">
          <ActivityChart
            dataPoints={activity.data_points}
            selectedMetrics={['heart_rate']}
            height={150}
            compact={true}
          />
        </div>

        <a href={`/activities/${activity.id}`} className="activity-embed-link">
          View full activity →
        </a>
      </div>
    )
  }
}
