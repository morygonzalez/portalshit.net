import React, { Component }  from 'react'
import Moment from 'react-moment'
import { render } from 'react-dom'
import 'moment/locale/ja'
import { css } from '@emotion/react'
import MoonLoader from 'react-spinners/MoonLoader'

import withRouter from './withRouter'

const override = `
  display: block;
  margin: 20% auto;
  border-color: red;
`

const locale = window.navigator.userLanguage || window.navigator.language

class Archives extends Component {
  constructor(props) {
    super(props)
    this.state = {
      data: [],
      loading: true,
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
    this.loadArchivesFromServer(this.props.router.params.year)
  }

  componentDidUpdate(prevProps, prevState) {
    if (prevProps.router.params.year !== this.props.router.params.year) {
      this.loadArchivesFromServer(this.props.router.params.year)
    }
  }

  render() {
    return (
      <div className="archives archive-by-month" id="archives">
        <div className="sweet-loading">
          <MoonLoader css={override} size={150} color={'#8c0000'} loading={this.state.loading} />
        </div>
        <MonthlyBox data={this.state.data} categories={this.props.categores} disabledCategories={this.props.disabledCategories} setLength={this.props.setLength} />
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

function Tags(props) {
  if (props.tags == undefined) {
    return (null)
  }
  return (
    props.tags.map(tag => {
      return (
        <span className="tag" key={`${props.id}-${tag.name}`}>
          <a href={`/tags/${tag.name}/`}>&nbsp;#{tag.name}</a>
        </span>
      )
    })
  )
}

function Entry(props) {
  return (
    <li className="entry">
      <a href={props.link}>{props.title}</a>
      <div className="detail-information">
        <span className="created_at"><Moment format="LL" date={props.created_at} locale={locale} /></span>
        <Category category={props.category} />
        <Tags tags={props.tags} entry={props.id} />
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
    this.setYmFormat()
  }

  setDate() {
    this.setState({ date: this.props.monthYear })
  }

  setEntries() {
    const entries = this.props.entries.map((entry) => {
      const uniqueKey = `${entry.title}-${entry.created_at}`
      return (
        <Entry key={uniqueKey} title={entry.title} category={entry.category} link={entry.link} created_at={entry.created_at} tags={entry.tags} />
      )
    })
    this.setState({ entries })
  }

  setYmFormat() {
    if (/ja/.test(locale)) {
      this.ymFormat = 'YYYY年MMM'
    } else {
      this.ymFormat = 'MMMM YYYY'
    }
  }

  componentDidMount() {
    this.setEntries()
    this.setDate()
  }

  componentDidUpdate(prevProps, prevState) {
    if (prevProps.entries != this.props.entries) {
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
        <h3>
          <span className="month"><Moment format={this.ymFormat} locale={locale}>{this.state.date}</Moment></span>
          <span className="entry-count">{this.props.entries.length} {this.props.entries.length > 1 ? "entries" : "entry"}</span>
        </h3>
        <ul className="entries">{this.state.entries}</ul>
      </li>
    )
  }
}

class MonthlyBox extends Component {
  constructor(props) {
    super(props)
    this.state = {
      entriesGroupByYearMonth: [],
      length: 0
    }
  }

  componentDidUpdate(prevProps, prevState) {
    if (prevProps != this.props) {
      this.setGroupByMonth()
    }
    if (prevState.length != this.state.length) {
      this.props.setLength(this.state.length)
    }
  }

  setGroupByMonth() {
    const data = this.props.data
    const disabledCategories = this.props.disabledCategories
    let length = 0
    const entriesGroupByYearMonth = Object.keys(data).map((monthYear, index) => {
      let entries = data[monthYear]
      if (disabledCategories && typeof disabledCategories !== 'undefined' && disabledCategories.length > 0) {
        entries = entries.filter(entry => !disabledCategories.includes(entry.category.title))
      }
      length += entries.length
      if (entries.length === 0) {
        return(null)
      }
      return(
        <EntryList key={monthYear} monthYear={monthYear} entries={entries} />
      )
    })
    this.setState({ entriesGroupByYearMonth, length })
  }

  render() {
    return (
      <ul className="monthlyBox">
        {this.state.entriesGroupByYearMonth}
      </ul>
    )
  }
}

export default withRouter(Archives)
window.Archives = Archives
