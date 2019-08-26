import React, { Component } from 'react'
import ReactDOM from 'react-dom'

class CategoryList extends Component {
  constructor(props) {
    super(props)
    this.state = {
      data: [],
      activeCategory: null
    }
    this.filterArchive = this.filterArchive.bind(this)
  }

  loadCategoryListFromServer() {
    let xhr = new XMLHttpRequest()
    let response
    xhr.open('GET', '/archives/categories.json')
    xhr.onreadystatechange = function() {
      if (xhr.readyState != 4) {
        // still requesting
      } else if (xhr.status != 200) {
        response = JSON.parse(xhr.response)
        this.setState({ data: response })
      } else {
        response = JSON.parse(xhr.response)
        this.setState({ data: response })
      }
    }.bind(this)
    xhr.send()
  }

  entriesCountByCategory() {
    [...document.querySelectorAll('ul.category-list li a')].forEach((categoryItem) => {
      let category = categoryItem.dataset.category
      let entries = [...document.querySelectorAll('ul.entries li.entry')].filter((entry) => {
        return (entry.querySelector('div.detail-information span.category').textContent === category)
      })
      let entriesCount = categoryItem.querySelector('span.entries-count')
      entriesCount.textContent = entries.length
    })
  }

  componentDidMount() {
    this.loadCategoryListFromServer()
    let intervalId = setInterval(this.entriesCountByCategory, 100)
    setTimeout(() => { clearInterval(intervalId) }, 1000)
  }

  componentDidUpdate(prevProps, prevState) {
    [...document.querySelectorAll('ul.category-list li.selected')].forEach((categoryItem) => {
      const category = categoryItem.querySelector('a').dataset.category
      if (category === prevState.activeCategory) {
        this.filterArchive(null)
      }
    })
    let intervalId = setInterval(this.entriesCountByCategory, 100)
    setTimeout(() => { clearInterval(intervalId) }, 1000)
  }

  filterArchive(category) {
    this.setState({ activeCategory: category })
    document.querySelectorAll('ul.entries li.entry').forEach((entry) => {
      let entryCategory = entry.querySelector('div.detail-information span.category').textContent
      if (!category) {
        entry.style.display = "list-item"
      } else if (entryCategory === category) {
        entry.style.display = "list-item"
      } else {
        entry.style.display = "none"
      }
    })
    document.querySelectorAll('li.entryList').forEach((entryList) => {
      let shouldHideList = [...entryList.querySelectorAll('li.entry')].every((entry) => {
        return entry.style.display === "none"
      })
      if (shouldHideList) {
        entryList.style.display = "none"
      } else {
        entryList.style.display = "list-item"
      }
    })
  }

  render() {
    let year
    let matched = location.pathname.match(/\d{4}/)
    if (matched && matched.length > 0) {
      year = matched[0]
    }
    let categoryList = this.state.data.map((category) => {
      return (
        <Category key={category} category={category} filterArchive={this.filterArchive} active={this.state.activeCategory === category} />
      )
    })
    return (
      <ul className="category-list">
        {categoryList}
      </ul>
    )
  }
}

class Category extends React.Component {
  constructor(props) {
    super(props)
    this.filterArchive = this.filterArchive.bind(this)
  }

  filterArchive() {
    this.props.filterArchive(this.props.category)
  }

  render() {
    return (
      <li key={this.props.category} className={this.props.active ? "selected" : null}>
        <a href={this.onClick} data-category={this.props.category} onClick={this.filterArchive}>{this.props.category} (<span className="entries-count">0</span>)</a>
      </li>
    )
  }
}

export default CategoryList
