import React from 'react'
import { render } from 'react-dom'

class Archives extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      data: []
    }
  }

  loadArchivesFromServer(year=null) {
    let xhr = new XMLHttpRequest()
    let response, data
    let path = year === null ? '/archives.json' : `/archives/${year}.json`
    xhr.open('GET', path)
    xhr.onreadystatechange = function() {
      if (xhr.readyState != 4) {
        // still requesting
      } else if (xhr.status != 200) {
        data = JSON.parse(xhr.response)
        this.setState({ data: data })
      } else {
        data = JSON.parse(xhr.response)
        this.setState({ data: data })
      }
    }.bind(this)
    xhr.send()
  }

  componentWillMount() {
    if (typeof this.props.match !== undefined) {
      this.loadArchivesFromServer(this.props.match.params.year)
    } else {
      this.loadArchivesFromServer()
    }
  }

  componentWillReceiveProps(next) {
    this.loadArchivesFromServer(next.match.params.year)
  }

  render() {
    return (
      <div className="archives archive-by-month" id="archives">
        <MonthlyBox data={this.state.data} category={this.props.category} />
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
  if (props.entries.length === 0)
    return null
  let entries = props.entries.map((entry) => {
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
  let category = props.category
  let entriesGroupByYearMonth = Object.keys(data).map((monthYear, index) => {
    let entries = data[monthYear]
    if (typeof category !== 'undefined' && category.length > 0) {
      entries = entries.filter(function(entry) {
        return entry.category.title === category
      })
    }
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
window.Archives = Archives
