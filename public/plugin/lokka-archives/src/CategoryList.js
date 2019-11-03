import React, { Component } from 'react'
import ReactDOM from 'react-dom'
import Select from 'react-select'

class CategoryList extends Component {
  constructor(props) {
    super(props)
    this.state = {
      data: [],
      selectedOption: null
    }
    this.handleChange = this.handleChange.bind(this)
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

  handleChange(selectedOption) {
    this.setState(
      { selectedOption },
      () => {
        let category = selectedOption ? selectedOption.value : null
        this.props.update(category)
      }
    )
  }

  render() {
    const options = this.state.data.map(category => {
      return { value: category, label: category }
    })
    return (
      <div className="category-list">
        <Select
          value={this.state.selectedOption}
          onChange={this.handleChange}
          options={options}
          placeholder="Category"
          isClearable
        />
      </div>
    )
  }
}

export default CategoryList
