import React from 'react'
import { createRoot } from 'react-dom/client'
import SearchApp from './search'

const container = document.getElementById('not-found-search-inline')
if (container) createRoot(container).render(<SearchApp inline />)
