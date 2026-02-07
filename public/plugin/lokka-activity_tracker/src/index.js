import React from 'react'
import ReactDOM from 'react-dom'

import ActivityPage from './ActivityPage'
import ActivityEmbed from './ActivityEmbed'
import MonthlyStatsChart from './components/MonthlyStatsChart'
import { parseI18n } from './i18n'

// Render full activity page
const activityRoot = document.getElementById('activity-root')
if (activityRoot) {
  const activityId = activityRoot.dataset.activityId
  const i18n = parseI18n(activityRoot)
  ReactDOM.render(
    <ActivityPage activityId={activityId} i18n={i18n} />,
    activityRoot
  )
}

// Render monthly stats chart on activities index page
const monthlyStatsRoot = document.getElementById('monthly-stats-chart')
if (monthlyStatsRoot) {
  const i18n = parseI18n(monthlyStatsRoot)
  ReactDOM.render(
    <MonthlyStatsChart i18n={i18n} />,
    monthlyStatsRoot
  )
}

// Render embedded activities
document.querySelectorAll('.activity-embed').forEach((element) => {
  const activityId = element.dataset.activityId
  const i18n = parseI18n(element)
  ReactDOM.render(
    <ActivityEmbed activityId={activityId} i18n={i18n} />,
    element
  )
})
