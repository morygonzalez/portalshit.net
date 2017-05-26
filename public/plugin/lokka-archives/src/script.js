import React from 'react'
import ReactDOM from 'react-dom'
import { BrowserRouter as Router, Route } from 'react-router-dom'
import YearList from './YearList'
import CategoryList from './CategoryList'
import Archives from './Archives'

const Routes = () =>
  <Router>
    <div>
      <YearList />
      <CategoryList />
      <Route exact path="/archives" component={Archives} />
      <Route path="/archives/:year(\d{4})" component={Archives} />
    </div>
  </Router>

export default Routes

ReactDOM.render(
  <Routes />,
  document.getElementById('root')
)
