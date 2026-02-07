import React, { Component } from 'react'
import ActivityChart from './components/ActivityChart'
import ActivityMap from './components/ActivityMap'
import MetricSelector from './components/MetricSelector'
import SplitsChart from './components/SplitsChart'

export default class ActivityPage extends Component {
  constructor(props) {
    super(props)
    this.state = {
      activity: null,
      loading: true,
      error: null,
      selectedMetrics: ['heart_rate', 'altitude_meters']
    }
    this.handleMetricChange = this.handleMetricChange.bind(this)
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

  handleMetricChange(selectedMetrics) {
    this.setState({ selectedMetrics })
  }

  render() {
    const { activity, loading, error, selectedMetrics } = this.state

    if (loading) {
      return <div className="activity-loading">Loading activity data...</div>
    }

    if (error) {
      return <div className="activity-error">Error: {error}</div>
    }

    if (!activity) {
      return <div className="activity-error">Activity not found</div>
    }

    const hasGpsData = activity.data_points.some(
      (dp) => dp.latitude !== null && dp.longitude !== null
    )

    return (
      <div className="activity-page">
        {hasGpsData && (
          <div className="activity-map-container">
            <h3>Route</h3>
            <ActivityMap dataPoints={activity.data_points} />
          </div>
        )}

        <div className="activity-chart-container">
          <h3>Performance Data</h3>
          <MetricSelector
            selectedMetrics={selectedMetrics}
            onChange={this.handleMetricChange}
            dataPoints={activity.data_points}
          />
          <ActivityChart
            dataPoints={activity.data_points}
            selectedMetrics={selectedMetrics}
          />
        </div>

        {activity.splits && activity.splits.length > 0 && (
          <div className="activity-splits-container">
            <h3>Splits (per km)</h3>
            <SplitsChart splits={activity.splits} />
          </div>
        )}
      </div>
    )
  }
}
