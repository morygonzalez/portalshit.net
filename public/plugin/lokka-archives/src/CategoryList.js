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

  async loadCategoryListFromServer() {
    const request = await fetch('/archives/categories.json')
    const response = await request.json()
    this.setState({ data: response })
  }

  componentDidMount() {
    this.loadCategoryListFromServer()
  }

  handleChange(selectedOption) {
    this.setState(
      { selectedOption },
      () => {
        const category = selectedOption ? selectedOption.value : null
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
