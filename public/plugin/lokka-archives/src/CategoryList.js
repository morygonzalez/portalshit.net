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

  handleChange(selectedOption) {
    this.setState(
      { selectedOption },
      () => {
        const selectedCategory = selectedOption ? selectedOption.value : null
        let disabledCategories
        if (selectedCategory) {
          disabledCategories = this.props.categories.filter(item => item != selectedCategory)
        } else {
          disabledCategories = []
        }
        this.props.update(disabledCategories)
      }
    )
  }

  render() {
    const options = this.props.categories.map(category => {
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
