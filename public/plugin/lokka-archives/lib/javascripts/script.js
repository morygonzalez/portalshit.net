import React from 'react'
import ReactDOM from 'react-dom'
import { Router, Route, Link } from 'react-router'

class Category extends React.Component {
  render() {
    if (this.props.category == undefined) {
      return (null)
    }
    return (
      <span className="category">
        <a href={`/category/${this.props.category.slug}/`}>{this.props.category.title}</a>
      </span>
    );
  }
}

class Entry extends React.Component {
  render() {
    return (
      <li className="entry">
        <a href={this.props.link}>{this.props.title}</a>
        <div className="detail-information">
          <span className="created_at">{this.props.created_at}</span>
          <Category category={this.props.category} />
        </div>
      </li>
    )
  }
}

class EntryList extends React.Component {
  render() {
    let entries = this.props.entries.map (function(entry) {
      let uniqueKey = `${entry.title}-${entry.created_at}`
      return (
        <Entry key={uniqueKey} title={entry.title} category={entry.category} link={entry.link} created_at={entry.created_at} />
      )
    })
    let title = this.props.monthYear.replace(/(\d{4})\-(\d{1,2})/, function() {
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
}

class MonthlyBox extends React.Component {
  render() {
    let data = this.props.data
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
}

class Archives extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      data: []
    };
  }

  loadArchivesFromServer() {
    $.ajax({
      url: this.props.url,
      dataType: 'json',
      cache: false,
      success: function(data) {
        this.setState({ data: data })
      }.bind(this),
      error: function(xhr, status, err) {
        console.error(this.props.url, status, err.toString())
      }.bind(this)
    })
  }

  componentDidMount() {
    this.loadArchivesFromServer()
    setInterval(this.loadArchivesFromServer, this.props.pollInterval)
  }

  render() {
    return (
      <div className="archives archive-by-month">
        <MonthlyBox data={this.state.data} />
      </div>
    )
  }
}

let year = location.href.match(/\d{4}/)
let endPoint = year ? "/api/archives/#{year[0]}" : "/api/archives"

ReactDOM.render(
  <Archives url={endPoint} pollInterval={900000} />,
  document.getElementById('archive-by-month')
)
