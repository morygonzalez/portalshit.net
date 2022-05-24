import React, { Component } from 'react'
import ReactDOM from 'react-dom'
import Select from 'react-select'

import withRouter from './withRouter'

class YearSelect extends Component {
  constructor(props) {
    super(props)
    this.state = {
      data: [],
      year: null
    }
    this.handleChange = this.handleChange.bind(this)
  }

  async loadYearSelectFromServer() {
    const request = await fetch('/archives/years.json')
    const response = await request.json()
    this.setState({ data: response })
  }

  componentDidMount() {
    const year = this.props.router.searchParams.get('year')
    if (year && this.state.year === null) {
      this.setState({ year })
    }
    this.loadYearSelectFromServer()
  }

  handleChange(selectedOption) {
    const year = selectedOption ? selectedOption.value : null
    let url
    if (year) {
      url = `/archives?year=${year}`
    } else {
      url = '/archives'
    }
    this.setState(
      { year },
      () => {
        this.props.router.navigate(url)
        this.props.update(year)
      }
    )
  }

  render() {
    const options = this.state.data.map(year => {
      return { value: year, label: year }
    })
    const year = this.state.year
    const value = year ? { value: year, label: year } : null
    return (
      <div className="year-list">
        <Select
          value={value}
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
