import React, { Component, useState, useEffect } from 'react'
import ReactGA from 'react-ga4'
ReactGA.initialize('G-0XJ0QC4XVN')

class SearchApp extends Component {
  constructor(props) {
    super(props)
    this.state = {
      query: '',
      focus: null,
      length: 0
    }
    this.updateQuery = this.updateQuery.bind(this)
    this.closeModal = this.closeModal.bind(this)
    this.moveUp = this.moveUp.bind(this)
    this.moveDown = this.moveDown.bind(this)
    this.keydown = this.keydown.bind(this)
    this.modal = React.createRef()
    this.updateEntryLength = this.updateEntryLength.bind(this)
  }

  updateQuery(query) {
    this.setState({ query })
  }

  updateEntryLength(length) {
    this.setState({ length })
  }

  closeModal() {
    this.modal.current.parentNode.classList.remove('active')
  }

  moveUp() {
    let newFocus
    if (this.state.focus === null) {
      newFocus = 1
    } else if (this.state.focus === 0) {
      // focus text input
      newFocus = this.state.focus
    } else {
      newFocus = this.state.focus - 1
    }
    this.setState({ focus: newFocus })
  }

  moveDown() {
    let newFocus
    if (this.state.focus === null) {
      newFocus = 1
    } else if (this.state.focus === this.state.length + 1) {
      // focus fulltext search
      newFocus = this.state.focus
    } else {
      newFocus = this.state.focus + 1
    }
    this.setState({ focus: newFocus })
  }

  keydown(e) {
    switch (e.keyCode) {
      case 27: // Escape
        this.closeModal()
        break
      case 38: // Arrow Up
        if (this.state.query) {
          e.preventDefault()
          this.moveUp()
        }
        break
      case 40: // Arrow Down
        if (this.state.query) {
          e.preventDefault()
          this.moveDown()
        }
        break
      default:
        break
    }
  }

  render() {
    return(
      <div className="search-component" ref={this.modal}>
        <SearchField
          update={this.updateQuery}
          keydown={this.keydown}
          query={this.state.query} />
        <Entries
          query={this.state.query}
          focus={this.state.focus}
          updateEntryLength={this.updateEntryLength} />
        <PopularKeywords
          updateQuery={this.updateQuery}
          query={this.state.query} />
      </div>
    )
  }
}

const SearchField = (props) => {
  const [query, setQuery] = useState('')

  useEffect(() => {
    const timeOutId = setTimeout(() => {
      props.update(query)
    }, 500)
    window.addEventListener('keydown', props.keydown)

    return () => {
      clearTimeout(timeOutId)
      window.removeEventListener('keydown', props.keydown)
    }
  }, [query])

  const handleChange = (event) => {
    const query = event.currentTarget.value
    props.update(query)
  }

  return (
    <p className="search-field">
      <input
        type="search"
        value={props.query}
        placeholder="Search"
        onChange={handleChange}
      />
      <i className="fas fa-search" />
    </p>
  )
}

class PopularKeywords extends Component {
  constructor(props) {
    super(props)
  }

  render() {
    const attrKeywords = document.querySelector('#search_form').dataset.popularKeywords
    if (attrKeywords !== undefined && (this.props.query === '' || this.props.query === null)) {
      const keywords = JSON.parse(attrKeywords)
      const popularKeywords = keywords.map(keyword => {
        return <Keyword keyword={keyword} updateQuery={this.props.updateQuery} />
      })
      return (
        <p className="popular-keywords">よく検索されているキーワード: {popularKeywords}</p>
      )
    } else {
      return null
    }
  }
}

class Keyword extends Component {
  constructor(props) {
    super(props)
    this.clickLink = this.clickLink.bind(this)
  }

  clickLink(event) {
    const keyword = event.target.innerText
    this.props.updateQuery(keyword)
  }

  render() {
    return (
      <span className="keyword">
        <a href onClick={this.clickLink}>
          {this.props.keyword}
        </a>
      </span>
    )
  }
}

class Entries extends Component {
  constructor(props) {
    super(props)
    this.state = {
      response: [],
      entries: [],
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
      () => {
        this.setEntries()
        this.props.updateEntryLength(response.length)
      }
    )
  }

  setEntries() {
    const entries = this.state.response.map((entry, index) => {
      const uniqueKey = `${entry.title}-${entry.created_at}`
      return (
        <Entry
          key={uniqueKey}
          title={entry.title}
          link={entry.link}
          index={index}
          query={this.props.query}
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

    if (prevProps.focus !== this.props.focus) {
      let focused
      if (this.props.focus > 0) {
        focused = document.querySelector(`li a[tabindex="${this.props.focus}"]`)
      } else {
        focused = document.querySelector('input[type="search"]')
      }
      const hoveredItems = document.querySelectorAll('li.hovered')
      Array.from(hoveredItems).forEach(hovered => {
        hovered.classList.remove('hovered')
      })
      focused.parentNode.classList.add('hovered')
      focused.focus()
    }
  }

  render() {
    if (this.props.query) {
      return(
        <ul className="search-result">
          {this.state.entries}
          <li className="fulltext-search">
            <a href={`/search/?query=${this.props.query}`} tabIndex={this.state.entries.length + 1}>全文検索する</a>
          </li>
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
    this.sendSearchEventToGoogleAnalytics = this.sendSearchEventToGoogleAnalytics.bind(this)
  }

  sendSearchEventToGoogleAnalytics() {
    if (document.querySelector('html').dataset.loggedIn === "false") {
      ReactGA.event('search', { search_term: this.props.query })
    }
  }

  render() {
    return(
      <li>
        <a href={this.props.link} tabIndex={this.props.index + 1} onClick={this.sendSearchEventToGoogleAnalytics}>
          {this.props.title}
        </a>
      </li>
    )
  }
}

export default SearchApp
