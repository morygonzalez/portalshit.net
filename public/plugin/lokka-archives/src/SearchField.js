import React, { Component, useState, useEffect } from 'react'
import ReactDOM from 'react-dom'
import withRouter from './withRouter'

const SearchField = (props) => {
  const [query, setQuery] = useState(props.router.searchParams.get('query') || '')

  useEffect(() => {
    const timeOutId = setTimeout(() => {
      const params = new URLSearchParams(props.router.location.search)
      const currentQuery = params.get('query') || ''
      if (currentQuery === query) {
        return
      }

      if (query) {
        params.set('query', query)
      } else {
        params.delete('query')
      }

      const newPath = `${props.router.location.pathname}?${params.toString()}`
      props.router.navigate(newPath)
      props.update(query)
    }, 500)
    return () => clearTimeout(timeOutId)
  }, [query])

  const handleChange = (event) => {
    let query = event.target.value
    setQuery(query)
  }

  return (
    <div className="search-field">
      <input
        type="search"
        value={query}
        placeholder="Search"
        onChange={handleChange}
      />
    </div>
  )
}

export default withRouter(SearchField)
