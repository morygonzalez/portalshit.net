import React, { Component } from 'react'
import { BrowserRouter as Router, Routes, Route, Redirect } from 'react-router-dom'

import YearList from './YearList'
import CategoryList from './CategoryList'
import SearchField from './SearchField'
import Archives from './Archives'
import Chart from './Chart'

class App extends Component {
  constructor(props) {
    super(props)
    this.state = {
      categories: [],
      disabledCategories: [],
      year: null,
      query: '',
      length: 0
    }
    this.updateDisabledCategories = this.updateDisabledCategories.bind(this)
    this.updateYear = this.updateYear.bind(this)
    this.updateQuery = this.updateQuery.bind(this)
    this.setLength = this.setLength.bind(this)
  }

  updateDisabledCategories(disabledCategories) {
    this.setState({ disabledCategories })
  }

  updateYear(year) {
    this.setState({ year })
  }

  updateQuery(query) {
    this.setState({ query })
  }

  setLength(length) {
    this.setState({ length })
  }

  async loadCategoriesFromServer() {
    const request = await fetch('/archives/categories.json')
    const response = await request.json()
    this.setState({ categories: response })
  }

  componentDidMount() {
    this.loadCategoriesFromServer()
  }

  render() {
    return(
      <article>
        <Chart categories={this.state.categories} disabledCategories={this.state.disabledCategories} update={this.updateDisabledCategories} />
        <Router>
          <div className="archive-filter">
            <YearList update={this.updateYear} />
            <CategoryList update={this.updateDisabledCategories} categories={this.state.categories} />
            <SearchField update={this.updateQuery} />
            <div className="entry-length"><p>{this.state.length} entries</p></div>
          </div>
          <Routes>
            <Route
              path="/archives"
              element={<Archives categories={this.state.categories} disabledCategories={this.state.disabledCategories} query={this.state.query} setLength={this.setLength} />} >
              <Route
                path=":year"
                element={<Archives categories={this.state.categories} disabledCategories={this.state.disabledCategories} query={this.state.query} setLength={this.setLength} />}
              />
            </Route>
          </Routes>
        </Router>
      </article>
    )
  }
}

export default App
