import React, { Component } from 'react'
import ReactDOM from 'react-dom'

class CategoryList extends Component {
  constructor(props) {
    super(props)
    this.state = {
      data: []
    }
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

  render() {
    let year
    let matched = location.pathname.match(/\d{4}/)
    if (matched && matched.length > 0) {
      year = matched[0]
    }
    let categoryList = this.state.data.map((category) => {
      return (
        <Category key={category} category={category} active={this.props.activeCategory === category} update={this.props.update} />
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
    this.updateCategory = this.updateCategory.bind(this)
  }

  updateCategory() {
    if (this.props.active) {
      this.props.update(null)
    } else {
      this.props.update(this.props.category)
    }
  }

  render() {
    return (
      <li key={this.props.category} className={this.props.active ? "selected" : null}>
        <a href={this.onClick} data-category={this.props.category} onClick={this.updateCategory}>
          {this.props.category}
        </a>
      </li>
    )
  }
}

export default CategoryList
