import React, { Component, useState, useEffect } from 'react'

class SearchApp extends Component {
  constructor(props) {
    super(props)
    this.state = {
      query: ''
    }
    this.updateQuery = this.updateQuery.bind(this)
  }

  updateQuery(query) {
    this.setState({ query })
  }

  render() {
    return(
      <div className="search-component">
        <SearchField update={this.updateQuery} query={this.state.query} />
        <Entries query={this.state.query} />
      </div>
    )
  }
}

const SearchField = (props) => {
  const [query, setQuery] = useState(props.query || '')

  useEffect(() => {
    const timeOutId = setTimeout(() => {
      props.update(query)
    }, 500)
    return () => clearTimeout(timeOutId)
  }, [query])

  const handleChange = (event) => {
    let query = event.target.value
    setQuery(query)
  }

  return (
    <p className="search-field">
      <input
        type="search"
        value={query}
        placeholder="Search"
        onChange={handleChange}
      />
      <i className="fas fa-search" />
    </p>
  )
}

class Entries extends Component {
  constructor(props) {
    super(props)
    this.state = {
      response: [],
      entries: []
    }
  }

  async loadEntriesFromServer() {
    let response
    if (this.props.query && this.props.query.length > 0) {
      const searchPath = `/search.json?query=${this.props.query}`
      const request = await fetch(searchPath)
      response = await request.json()
    } else {
      response = []
    }
    this.setState(
      { response },
      () => { this.setEntries() }
    )
  }

  setEntries() {
    const entries = this.state.response.map(entry => {
      const uniqueKey = `${entry.title}-${entry.created_at}`
      return (
        <Entry
          key={uniqueKey}
          title={entry.title}
          link={entry.link}
          created_at={entry.created_at} />
      )
    })
    this.setState({ entries })
  }

  componentDidUpdate(prevProps, prevState) {
    if (prevProps.query !== this.props.query) {
      this.setState({ entries: [] })
      this.loadEntriesFromServer()
    }
  }

  render() {
    if (this.state.entries.length > 0) {
      return(
        <ul className="search-result">
          {this.state.entries}
          <li className="fulltext-search"><a href={`/search/?query=${this.props.query}`}>全文検索する</a></li>
        </ul>
      )
    } else {
      return(null)
    }
  }
}

class Entry extends Component {
  constructor(props) {
    super(props)
  }

  render() {
    return(
      <a href={this.props.link}><li>{this.props.title}</li></a>
    )
  }
}

export default SearchApp
