import React, { Component, useState, useEffect } from 'react'
import ReactDOM from 'react-dom'

const SearchField = (props) => {
  const [query, setQuery] = useState('')

  useEffect(() => {
    const timeOutId = setTimeout(() => {
      props.update(query)
    }, 500)
    return () => clearTimeout(timeOutId)
  }, [query])

  return (
    <div className="search-field">
      <input
        type="text"
        value={query}
        placeholder="Search"
        onChange={event => setQuery(event.target.value)}
      />
    </div>
  )
}

export default SearchField
