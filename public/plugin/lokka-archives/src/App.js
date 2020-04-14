import React, { Component } from 'react'
import { BrowserRouter as Router, Switch, Route, Redirect } from 'react-router-dom'

import YearList from './YearList'
import CategoryList from './CategoryList'
import Archives from './Archives'
import Chart from './Chart'

class App extends Component {
  constructor(props) {
    super(props)
    this.state = {
      category: null,
      year: null,
      length: 0
    }
    this.updateCategory = this.updateCategory.bind(this)
    this.updateYear = this.updateYear.bind(this)
    this.setLength = this.setLength.bind(this)
  }

  updateCategory(category) {
    this.setState({ category })
  }

  updateYear(year) {
    this.setState({ year })
  }

  setLength(length) {
    this.setState({ length })
  }

  render() {
    return(
      <article>
        <Chart />
        <Router history={history}>
          <div className="archive-filter">
            <YearList update={this.updateYear} />
            <CategoryList update={this.updateCategory} activeCategory={this.state.category} />
            <div className="entry-length"><p>{this.state.length} entries</p></div>
          </div>
          <Switch>
            <Route
              exact path="/archives"
              render={(props) =>
                <Archives
                  category={this.state.category}
                  setLength={this.setLength}
                  {...props}
                />
              }
            />
            <Route
              path="/archives/:year(\d{4})"
              render={(props) =>
                <Archives
                  category={this.state.category}
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
