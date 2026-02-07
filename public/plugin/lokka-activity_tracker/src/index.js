import React from 'react'
import ReactDOM from 'react-dom'

import ActivityPage from './ActivityPage'
import ActivityEmbed from './ActivityEmbed'
import MonthlyStatsChart from './components/MonthlyStatsChart'

// Render full activity page
const activityRoot = document.getElementById('activity-root')
if (activityRoot) {
  const activityId = activityRoot.dataset.activityId
  ReactDOM.render(
    <ActivityPage activityId={activityId} />,
    activityRoot
  )
}

// Render monthly stats chart on activities index page
const monthlyStatsRoot = document.getElementById('monthly-stats-chart')
if (monthlyStatsRoot) {
  ReactDOM.render(
    <MonthlyStatsChart />,
    monthlyStatsRoot
  )
}

// Render embedded activities
document.querySelectorAll('.activity-embed').forEach((element) => {
  const activityId = element.dataset.activityId
  ReactDOM.render(
    <ActivityEmbed activityId={activityId} />,
    element
  )
})
