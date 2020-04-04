import React, { Component } from 'react'
import ReactDOM from 'react-dom'
import Select from 'react-select'
import PropTypes from 'prop-types'
import { withRouter } from 'react-router-dom'

import history from './history'

class YearSelect extends Component {
  constructor(props) {
    super(props)
    this.state = {
      data: [],
      selectedOption: null
    }
    this.handleChange = this.handleChange.bind(this)
  }

  static propTypes = {
    match: PropTypes.object.isRequired,
    location: PropTypes.object.isRequired,
    history: PropTypes.object.isRequired
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
      this.props.history.push(`/archives/${year}`)
    } else {
      this.props.history.push("/archives")
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
