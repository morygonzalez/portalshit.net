import React, { Component } from 'react'
import { BrowserRouter as Router, Switch, Route, Redirect } from 'react-router-dom'

import YearList from './YearList'
import CategoryList from './CategoryList'
import Archives from './Archives'

class App extends Component {
  constructor(props) {
    super(props)
    this.state = {
      category: null,
      year: null
    }
    this.updateCategory = this.updateCategory.bind(this)
    this.updateYear = this.updateYear.bind(this)
  }

  updateCategory(category) {
    this.setState({ category: category })
  }

  updateYear(year) {
    this.setState({ year: year })
  }

  render() {
    return(
      <Router history={history}>
        <div className="archive-filter">
          <YearList update={this.updateYear} />
          <CategoryList update={this.updateCategory} activeCategory={this.state.category} />
        </div>
        <Switch>
          <Route exact path="/archives" render={(props) => <Archives category={this.state.category} {...props} />} />
          <Route path="/archives/:year(\d{4})" render={(props) => <Archives category={this.state.category} year={this.state.year} {...props} />} />
        </Switch>
      </Router>
    )
  }
}

export default App
