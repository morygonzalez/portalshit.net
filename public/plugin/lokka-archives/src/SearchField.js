import React, { Component, useState, useEffect } from 'react'
import ReactDOM from 'react-dom'
import withRouter from './withRouter'

// class SearchField extends Component {
//   constructor(props) {
//     super(props)
//     this.state = {
//       query: ''
//     }
//     this.handleChange = this.handleChange.bind(this)
//   }
//
//   componentDidMount() {
//   }
//
//   componentDidUpdate() {
//   }
//
//   componentWillUnmount() {
//   }
//
//   handleChange(event) {
//     const query = event.target.value
//     let url
//     if (query) {
//       url = `/archives?query=${query}`
//     } else {
//       url = '/archives'
//     }
//     this.setState(
//       { query },
//       () => {
//         this.props.update(query)
//         this.props.router.navigate(url)
//       }
//     )
//   }
//
//   render() {
//     return (
//       <div className="search-field">
//         <input
//           type="search"
//           value={this.state.query}
//           placeholder="Search"
//           onChange={this.handleChange}
//         />
//       </div>
//     )
//   }
// }

const SearchField = (props) => {
  const [query, setQuery] = useState(props.router.searchParams.get('query') || '')

  useEffect(() => {
    const timeOutId = setTimeout(() => {
      let url
      if (query) {
        url = `/archives?query=${query}`
      } else {
        url = '/archives'
      }
      props.router.navigate(url)
      props.update(query)
    }, 500)
    return () => clearTimeout(timeOutId)
  }, [query])

  const handleChange = (event) => {
    let query = event.target.value
    setQuery(query)
  }

  return (
    <div className="search-field">
      <input
        type="search"
        value={query}
        placeholder="Search"
        onChange={handleChange}
      />
    </div>
  )
}

export default withRouter(SearchField)
