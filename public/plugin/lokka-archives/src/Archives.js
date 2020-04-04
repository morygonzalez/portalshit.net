import React, { Component }  from 'react'
import Moment from 'react-moment'
import { render } from 'react-dom'
import 'moment/locale/ja'

class Archives extends Component {
  constructor(props) {
    super(props)
    this.state = {
      data: []
    }
  }

  async loadArchivesFromServer(year=null) {
    const path = year === null ? '/archives.json' : `/archives/${year}.json`
    const request = await fetch(path)
    const response = await request.json()
    this.setState({ data: response })
  }

  componentDidMount() {
    if (typeof this.props.match !== undefined) {
      this.loadArchivesFromServer(this.props.match.params.year)
    } else {
      this.loadArchivesFromServer()
    }
  }

  componentDidUpdate(prevProps, prevState) {
    if (prevProps.match.params.year !== this.props.match.params.year) {
      this.loadArchivesFromServer(this.props.match.params.year)
    }
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
        <span className="created_at"><Moment format="LL" date={props.created_at} /></span>
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
  let date = props.monthYear.replace(/(\d{4})\-(\d{1,2})/, function() {
    return `${arguments[1]}-${(0 + arguments[2]).slice(-2)}-01T00:00:00`
  })
  return (
    <li className="entryList year-month">
      <h3><Moment format="YYYY年MMM">{date}</Moment></h3>
      <ul className="entries">{entries}</ul>
    </li>
  )
}

function MonthlyBox(props) {
  let data = props.data
  let category = props.category
  let entriesGroupByYearMonth = Object.keys(data).map((monthYear, index) => {
    let entries = data[monthYear]
    if (category && typeof category !== 'undefined' && category.length > 0) {
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
