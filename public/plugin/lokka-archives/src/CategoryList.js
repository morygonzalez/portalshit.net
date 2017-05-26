import React from 'react'
import ReactDOM from 'react-dom'
import { Link } from 'react-router-dom'

class CategoryList extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      data: [],
      category: ''
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

  componentDidMount() {
    this.loadCategoryListFromServer()
  }

  filterArchive(e) {
    let category = e.target.textContent
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
          <a href="javascript:void(0)" onClick={this.filterArchive}>{category}</a>
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
