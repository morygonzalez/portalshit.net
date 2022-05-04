import React, { Component } from 'react'
import ReactDOM from 'react-dom'
import Select from 'react-select'

import withRouter from './withRouter'

class YearSelect extends Component {
  constructor(props) {
    super(props)
    this.state = {
      data: [],
      selectedOption: null
    }
    this.handleChange = this.handleChange.bind(this)
  }

  async loadYearSelectFromServer() {
    const request = await fetch('/archives/years.json')
    const response = await request.json()
    this.setState({ data: response })
  }

  componentDidMount() {
    this.loadYearSelectFromServer()
  }

  handleChange(selectedOption) {
    const year = selectedOption ? selectedOption.value : null
    if (year) {
      this.props.router.navigate(`/archives/${year}`)
    } else {
      this.props.router.navigate("/archives")
    }
    this.setState(
      { selectedOption },
      () => { this.props.update(year) }
    )
  }

  render() {
    const options = this.state.data.map(year => {
      return { value: year, label: year }
    })
    return (
      <div className="year-list">
        <Select
          value={this.state.selectedOption}
          onChange={this.handleChange}
          options={options}
          placeholder="Year"
          isClearable
        />
      </div>
    )
  }
}

const YearList = withRouter(YearSelect)

export default YearList
