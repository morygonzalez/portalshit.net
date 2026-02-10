import React from 'react'
import ReactDOM from 'react-dom'

import ActivityPage from './ActivityPage'
import ActivityEmbed from './ActivityEmbed'
import MonthlyStatsChart from './components/MonthlyStatsChart'
import { parseI18n } from './i18n'

function initActivityTracker() {
  // Render full activity page
  const activityRoot = document.getElementById('activity-root')
  if (activityRoot) {
    const activityHash = activityRoot.dataset.activityHash
    const i18n = parseI18n(activityRoot)
    ReactDOM.render(
      <ActivityPage activityHash={activityHash} i18n={i18n} />,
      activityRoot
    )
  }

  // Render monthly stats chart on activities index page
  const monthlyStatsRoot = document.getElementById('monthly-stats-chart')
  if (monthlyStatsRoot) {
    const i18n = parseI18n(monthlyStatsRoot)
    const year = monthlyStatsRoot.dataset.year ? parseInt(monthlyStatsRoot.dataset.year, 10) : null
    const type = monthlyStatsRoot.dataset.type || null
    ReactDOM.render(
      <MonthlyStatsChart i18n={i18n} year={year} type={type} />,
      monthlyStatsRoot
    )
  }

  // Render embedded activities
  document.querySelectorAll('.activity-embed').forEach((element) => {
    // Skip if already rendered
    if (element.dataset.rendered) return

    const activityHash = element.dataset.activityHash
    const i18n = parseI18n(element)
    ReactDOM.render(
      <ActivityEmbed activityHash={activityHash} i18n={i18n} />,
      element
    )
    element.dataset.rendered = 'true'
  })
}

// Run initialization when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initActivityTracker)
} else {
  initActivityTracker()
}
