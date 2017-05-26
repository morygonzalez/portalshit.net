import React from 'react'
import ReactDOM from 'react-dom'
import { BrowserRouter as Router, Route, Link } from 'react-router-dom'

class YearList extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      data: []
    }
  }

  loadYearListFromServer() {
    let xhr = new XMLHttpRequest()
    let response
    xhr.open('GET', '/archives/years.json')
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
    this.loadYearListFromServer()
  }

  render() {
    let yearList = this.state.data.map((year) => {
      return (
        <li key={year}>
          <Link to={`/archives/${year}`}>{year}</Link>
        </li>
      )
    })
    return (
      <ul className="year-list">
        {yearList}
      </ul>
    )
  }
}

export default YearList
