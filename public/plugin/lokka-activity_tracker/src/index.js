import React from 'react'
import ReactDOM from 'react-dom'

import ActivityPage from './ActivityPage'
import ActivityEmbed from './ActivityEmbed'

// Render full activity page
const activityRoot = document.getElementById('activity-root')
if (activityRoot) {
  const activityId = activityRoot.dataset.activityId
  ReactDOM.render(
    <ActivityPage activityId={activityId} />,
    activityRoot
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
