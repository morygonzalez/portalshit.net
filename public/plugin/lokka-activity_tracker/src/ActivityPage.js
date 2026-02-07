import React, { Component } from 'react'
import ActivityChart from './components/ActivityChart'
import ActivityMap from './components/ActivityMap'
import MetricSelector from './components/MetricSelector'
import SplitsChart from './components/SplitsChart'
import { t } from './i18n'

export default class ActivityPage extends Component {
  constructor(props) {
    super(props)
    this.state = {
      activity: null,
      loading: true,
      error: null,
      selectedMetrics: ['pace', 'heart_rate'],
      hoveredPoint: null
    }
    this.handleMetricChange = this.handleMetricChange.bind(this)
    this.handleHoverChange = this.handleHoverChange.bind(this)
  }

  async componentDidMount() {
    try {
      const response = await fetch(`/activities/${this.props.activityId}.json`)
      if (!response.ok) {
        throw new Error(t(this.props.i18n, 'embed_load_failed', 'Failed to load activity data'))
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

  handleHoverChange(elapsedSeconds) {
    const { activity } = this.state
    if (!activity || !activity.data_points) {
      this.setState({ hoveredPoint: null })
      return
    }

    if (elapsedSeconds === null || elapsedSeconds === undefined) {
      this.setState({ hoveredPoint: null })
      return
    }

    // Use map_points (with home location filtered out) for highlight
    // to prevent revealing home location when hovering over chart
    const mapPoints = activity.map_points || activity.data_points
    const points = mapPoints.filter(
      (dp) => dp.elapsed_seconds !== null && dp.latitude !== null && dp.longitude !== null
    )
    if (points.length === 0) {
      this.setState({ hoveredPoint: null })
      return
    }

    let closest = points[0]
    let closestDiff = Math.abs(points[0].elapsed_seconds - elapsedSeconds)
    for (let i = 1; i < points.length; i += 1) {
      const diff = Math.abs(points[i].elapsed_seconds - elapsedSeconds)
      if (diff < closestDiff) {
        closest = points[i]
        closestDiff = diff
      }
    }

    this.setState({ hoveredPoint: closest })
  }

  render() {
    const { activity, loading, error, selectedMetrics, hoveredPoint } = this.state
    const { i18n } = this.props

    if (loading) {
      return <div className="activity-loading">{t(i18n, 'loading_activity', 'Loading activity data...')}</div>
    }

    if (error) {
      return <div className="activity-error">{t(i18n, 'error_prefix', 'Error: ')}{error}</div>
    }

    if (!activity) {
      return <div className="activity-error">{t(i18n, 'activity_not_found', 'Activity not found')}</div>
    }

    // Use map_points for display (with home location filtered out), fall back to data_points
    const mapPoints = activity.map_points || activity.data_points
    const hasGpsData = mapPoints.some(
      (dp) => dp.latitude !== null && dp.longitude !== null
    )

    return (
      <div className="activity-page">
        {hasGpsData && (
          <div className="activity-map-container">
            <h3>{t(i18n, 'route_title', 'Route')}</h3>
            <ActivityMap dataPoints={mapPoints} highlightPoint={hoveredPoint} />
          </div>
        )}

        <div className="activity-chart-container">
          <h3>{t(i18n, 'performance_data_title', 'Performance Data')}</h3>
          <MetricSelector
            selectedMetrics={selectedMetrics}
            onChange={this.handleMetricChange}
            dataPoints={activity.data_points}
            i18n={i18n}
          />
          <ActivityChart
            dataPoints={activity.data_points}
            selectedMetrics={selectedMetrics}
            onHoverChange={this.handleHoverChange}
            i18n={i18n}
          />
        </div>

        {activity.splits && activity.splits.length > 0 && (
          <div className="activity-splits-container">
            <h3>{t(i18n, 'splits_title', 'Splits (per km)')}</h3>
            <SplitsChart splits={activity.splits} i18n={i18n} />
          </div>
        )}
      </div>
    )
  }
}
