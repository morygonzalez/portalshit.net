import React from 'react'
import { createRoot } from 'react-dom/client'
import ChatWidget from './ChatWidget'

const container = document.getElementById('dify-chat-root')
if (container) {
  const root = createRoot(container)
  root.render(<ChatWidget />)
}
