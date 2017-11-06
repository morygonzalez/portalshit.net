import React from 'react'
import ReactDOM from 'react-dom'
import { Link } from 'react-router-dom'

class CategoryList extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      data: []
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
    [...document.querySelectorAll('ul.category-list li a')].forEach((categoryList) => {
      let category = categoryList.dataset.category
      let entries = [...document.querySelectorAll('ul.entries li.entry')].filter((entry) => {
        return (entry.querySelector('div.detail-information span.category').textContent == category)
      })
      let entriesCount = categoryList.querySelector('span.entries-count')
      entriesCount.textContent = entries.length
    })
  }

  componentDidMount() {
    this.loadCategoryListFromServer()
    let intervalId = setInterval(this.entriesCountByCategory, 100)
    setTimeout(() => { clearInterval(intervalId) }, 1000)
  }

  componentWillReceiveProps() {
    let intervalId = setInterval(this.entriesCountByCategory, 100)
    setTimeout(() => { clearInterval(intervalId) }, 1000)
  }

  filterArchive(e) {
    let category = e.target.dataset.category
    let entries = [...document.querySelectorAll('ul.entries li.entry')].map((entry) => {
      let entryCategory = entry.querySelector('div.detail-information span.category').textContent
      if (entryCategory == category) {
        entry.style.display = "block"
      } else {
        entry.style.display = "none"
      }
    })
    let entryList = [...document.querySelectorAll('li.entryList')].map((entryList) => {
      let shouldHideList = [...entryList.querySelectorAll('li.entry')].every((entry) => {
        return entry.style.display == "none"
      })
      if (shouldHideList) {
        entryList.style.display = "none"
      } else {
        entryList.style.display = "block"
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
        <li key={category}>
          <a href="javascript:void(0)" data-category={category} onClick={this.filterArchive}>{category} (<span className="entries-count">0</span>)</a>
        </li>
      )
    })
    return (
      <ul className="category-list">
        {categoryList}
      </ul>
    )
  }
}

export default CategoryList
