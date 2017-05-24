import React from 'react'
import ReactDOM from 'react-dom'
import { BrowserRouter as Router, Route, Link } from 'react-router-dom'
import Archives from './Archives'
import YearList from './YearList'

const Routes = () =>
  <Router>
    <div>
      <YearList />
      <Route exact path="/archives" component={Archives} />
      <Route path="/archives/:year" component={Archives} addHandlerKey={true} />
    </div>
  </Router>

export default Routes

ReactDOM.render(
  <Routes />,
  document.getElementById('root')
)
