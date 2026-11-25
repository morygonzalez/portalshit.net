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

  componentDidMount() {
    if (this.props.inline) return;
    this.onKeyword = (event) => {
      this.updateQuery(event.detail.keyword);

      window.__openingSearch = true;
      requestAnimationFrame(() => {
        const container = this.modal.current.parentNode;
        container?.classList.add('active');
        container?.querySelector('input')?.focus();
        setTimeout(() => { window.__openingSearch = false; }, 0);
      });
    }
    document.addEventListener('search:keyword', this.onKeyword);
  }

  componentWillUnmount() {
    if (this.onKeyword) document.removeEventListener('search:keyword', this.onKeyword);
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
    if (this.props.inline ? !this.modal.current.contains(e.target) : !this.modal.current.parentNode.classList.contains('active') || e.target.closest?.('#not-found-search-inline')) return;
    switch (e.keyCode) {
      case 27: // Escape
        if (!this.props.inline) this.closeModal()
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
          searchRoot={this.modal}
          updateEntryLength={this.updateEntryLength} />
        <PopularKeywords
          updateQuery={this.updateQuery}
          searchRoot={this.modal}
          query={this.state.query} />
      </div>
    )
  }
}

const SearchField = (props) => {
  useEffect(() => {
    window.addEventListener('keydown', props.keydown);
    return () => window.removeEventListener('keydown', props.keydown);
  }, [props.keydown]);

  const handleChange = (e) => {
    props.update(e.currentTarget.value);
  };

  return (
    <p className="search-field">
      <input
        type="search"
        aria-label="キーワードから記事を探す"
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
    const attrKeywords = document.querySelector('#search_form')?.dataset.popularKeywords
    if (attrKeywords !== undefined && (this.props.query === '' || this.props.query === null)) {
      const keywords = JSON.parse(attrKeywords)
      const popularKeywords = keywords.map(keyword => {
        return <Keyword key={keyword} keyword={keyword} updateQuery={this.props.updateQuery} searchRoot={this.props.searchRoot} />
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
    this.onClick = this.onClick.bind(this)
  }

  onClick(event) {
    event.preventDefault();
    this.props.updateQuery(this.props.keyword)
    const input = this.props.searchRoot.current.querySelector('.search-field input')
    input && input.focus();
  }

  render() {
    return (
      <span className="keyword">
        <a href onClick={this.onClick} role="button">
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
      error: false,
    }
  }

  async loadEntriesFromServer() {
    let response
    if (this.props.query && this.props.query.length > 0) {
      try {
        const searchPath = `/search.json?query=${encodeURIComponent(this.props.query)}`
        const request = await fetch(searchPath)
        if (!request.ok) throw new Error('Search failed')
        response = await request.json()
      } catch (_) {
        this.setState({ error: true, entries: [] })
        this.props.updateEntryLength(0)
        return
      }
    } else {
      response = []
    }
    this.setState(
      { response, error: false },
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
      this.setState({ entries: [], error: false })
      this.loadEntriesFromServer()
    }

    if (prevProps.focus !== this.props.focus) {
      let focused
      if (this.props.focus > 0) {
        focused = this.props.searchRoot.current.querySelector(`li a[tabindex="${this.props.focus}"]`)
      } else {
        focused = this.props.searchRoot.current.querySelector('input[type="search"]')
      }
      const hoveredItems = this.props.searchRoot.current.querySelectorAll('li.hovered')
      Array.from(hoveredItems).forEach(hovered => {
        hovered.classList.remove('hovered')
      })
      if (focused) {
        focused.parentNode.classList.add('hovered')
        focused.focus()
      }
    }
  }

  render() {
    if (this.props.query) {
      return(
        <ul className="search-result">
          {this.state.error && <li role="status">検索できませんでした。時間をおいて再度お試しください。</li>}
          {this.state.entries}
          <li className="fulltext-search">
            <a href={`/search/?query=${encodeURIComponent(this.props.query)}`} tabIndex={this.state.entries.length + 1}>全文検索する</a>
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
