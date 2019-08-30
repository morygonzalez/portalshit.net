import React, { Component } from 'react'
import { BrowserRouter as Router, Switch, Route } from 'react-router-dom'

import YearList from './YearList'
import CategoryList from './CategoryList'
import Archives from './Archives'

class App extends Component {
  constructor(props) {
    super(props)
    this.state = {
      category: null
    }
    this.updateState = this.updateState.bind(this)
  }

  updateState(category) {
    this.setState({ category: category })
  }

  render() {
    return(
      <Router>
        <div>
          <YearList />
          <CategoryList update={this.updateState} activeCategory={this.state.category} />
          <Switch>
            <Route exact path="/archives"
              render={(props) => <Archives category={this.state.category} {...props} />}
            />
            <Route path="/archives/:year(\d{4})"
              render={(props) => <Archives category={this.state.category} {...props} />}
            />
          </Switch>
        </div>
      </Router>
    )
  }
}

export default App
