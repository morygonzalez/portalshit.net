import React, { Component } from 'react'
import { BrowserRouter as Router, Switch, Route, Redirect } from 'react-router-dom'

import YearList from './YearList'
import Archives from './Archives'
import Chart from './Chart'

class App extends Component {
  constructor(props) {
    super(props)
    this.state = {
      categories: [],
      disabled: [],
      year: null,
      length: 0
    }
    this.updateDisabled = this.updateDisabled.bind(this)
    this.updateYear = this.updateYear.bind(this)
    this.setLength = this.setLength.bind(this)
  }

  updateDisabled(disabled) {
    this.setState({ disabled })
  }

  updateYear(year) {
    this.setState({ year })
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
        <Chart categories={this.state.categories} disabled={this.state.disabled} updateDisabled={this.updateDisabled} />
        <Router>
          <div className="archive-filter">
            <YearList update={this.updateYear} />
            <div className="entry-length"><p>{this.state.length} entries</p></div>
          </div>
          <Switch>
            <Route
              exact path="/archives"
              render={(props) =>
                <Archives
                  categories={this.state.categories}
                  disabled={this.state.disabled}
                  setLength={this.setLength}
                  {...props}
                />
              }
            />
            <Route
              path="/archives/:year(\d{4})"
              render={(props) =>
                <Archives
                  categories={this.state.categories}
                  disabled={this.state.disabled}
                  setLength={this.setLength}
                  year={this.state.year}
                  {...props}
                />
              }
            />
          </Switch>
        </Router>
      </article>
    )
  }
}

export default App
