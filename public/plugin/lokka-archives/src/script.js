import React, { Component } from 'react'
import ReactDOM from 'react-dom'
import { BrowserRouter as Router, Switch, Route } from 'react-router-dom'

import YearList from './YearList'
import CategoryList from './CategoryList'
import Archives from './Archives'

class Routes extends Component {
  render() {
    return(
      <Router>
        <div>
          <YearList />
          <CategoryList />
          <Switch>
            <Route exact path="/archives" component={Archives} />
            <Route path="/archives/:year(\d{4})" component={Archives} />
          </Switch>
        </div>
      </Router>
    )
  }
}

export default Routes

ReactDOM.render(
  <Routes />,
  document.getElementById('root')
)
