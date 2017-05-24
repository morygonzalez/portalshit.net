import React from 'react'
import { render } from 'react-dom'

class Archives extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      data: []
    }
  }

  loadArchivesFromServer(path) {
    let xhr = new XMLHttpRequest()
    let response
    xhr.open('GET', path + ".json")
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

  componentWillMount() {
    this.loadArchivesFromServer(this.props.match.url)
  }

  componentWillReceiveProps(next) {
    this.loadArchivesFromServer(next.match.url)
  }

  render() {
    return (
      <div className="archives archive-by-month">
        <MonthlyBox data={this.state.data} />
      </div>
    )
  }
}

function Category(props) {
  if (props.category == undefined) {
    return (null)
  }
  return (
    <span className="category">
      <a href={`/category/${props.category.slug}/`}>{props.category.title}</a>
    </span>
  )
}

function Entry(props) {
  return (
    <li className="entry">
      <a href={props.link}>{props.title}</a>
      <div className="detail-information">
        <span className="created_at">{props.created_at}</span>
        <Category category={props.category} />
      </div>
    </li>
  )
}

function EntryList(props) {
  let entries = props.entries.map (function(entry) {
    let uniqueKey = `${entry.title}-${entry.created_at}`
    return (
      <Entry key={uniqueKey} title={entry.title} category={entry.category} link={entry.link} created_at={entry.created_at} />
    )
  })
  let title = props.monthYear.replace(/(\d{4})\-(\d{1,2})/, function() {
      return `${arguments[1]}年${arguments[2]}月`
    }
  )
  return (
    <li className="entryList year-month">
      <h3>{title}</h3>
      <ul className="entries">{entries}</ul>
    </li>
  )
}

function MonthlyBox(props) {
  let data = props.data
  let entriesGroupByYearMonth = Object.keys(data).map(function(monthYear, index) {
    let entries = data[monthYear]
    return (
      <EntryList key={monthYear} monthYear={monthYear} entries={entries} />
    )
  })
  return (
    <ul className="monthlyBox">
      {entriesGroupByYearMonth}
    </ul>
  )
}

export default Archives
