import React, { Component }  from 'react'
import Moment from 'react-moment'
import { render } from 'react-dom'
import 'moment/locale/ja'
import { css } from '@emotion/core'
import MoonLoader from 'react-spinners/MoonLoader'

const override = `
  display: block;
  margin: 10em auto;
  border-color: red;
`

class Archives extends Component {
  constructor(props) {
    super(props)
    this.state = {
      data: [],
      loading: true
    }
  }

  async loadArchivesFromServer(year=null) {
    this.setState({ data: [], loading: true })
    const path = year === null ? '/archives.json' : `/archives/${year}.json`
    const request = await fetch(path)
    const response = await request.json()
    this.setState({ data: response, loading: false })
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
        <div className="sweet-loading">
          <MoonLoader css={override} size={150} color={'#8c0000'} loading={this.state.loading} />
        </div>
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

class EntryList extends Component {
  constructor(props) {
    super(props)
    this.state = {
      entries: [],
      date: null
    }
  }

  setDate() {
    this.setState({ date: this.props.monthYear })
  }

  setEntries() {
    const entries = this.props.entries.map((entry) => {
      const uniqueKey = `${entry.title}-${entry.created_at}`
      return (
        <Entry key={uniqueKey} title={entry.title} category={entry.category} link={entry.link} created_at={entry.created_at} />
      )
    })
    this.setState({ entries: entries })
  }

  componentDidMount() {
    this.setEntries()
    this.setDate()
  }

  componentDidUpdate(prevProps, prevState) {
    if (prevProps.entries.length != this.props.entries.length) {
      this.setState({ entries: [], date: null })
      this.setEntries()
      this.setDate()
    }
  }

  render() {
    if (this.state.entries.length === 0) {
      return(null)
    }
    return(
      <li className="entryList year-month">
        <h3><Moment format="YYYY年MMM">{this.state.date}</Moment></h3>
        <ul className="entries">{this.state.entries}</ul>
      </li>
    )
  }
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
