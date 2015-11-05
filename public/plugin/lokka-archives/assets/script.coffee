Entry = React.createClass
  render: ->
    `(
      <li className="entry">
        <a href={this.props.link}>{this.props.title}</a>
        <div className="detail-information">
          <span className="created_at">{this.props.created_at}</span>
          <span className="category"><a href={"/category/" + this.props.category.slug + "/"}>{this.props.category.title}</a></span>
        </div>
      </li>
    )`

EntryList = React.createClass
  render: ->
    entries = this.props.entries.map (entry) ->
      uniqueKey = "#{entry.title}-#{entry.created_at}"
      `(
        <Entry key={uniqueKey} title={entry.title} category={entry.category} link={entry.link} created_at={entry.created_at} />
      )`
    `(
      <li className="entryList year-month">
        <h3>{this.props.monthYear}</h3>
        <ul className="entries">{entries}</ul>
      </li>
    )`

MonthlyBox = React.createClass
  render: ->
    data = this.props.data
    entriesGroupByYearMonth = Object.keys(data).map (monthYear, index) ->
      entries = data[monthYear]
      `(
        <EntryList key={monthYear} monthYear={monthYear} entries={entries} />
      )`
    `(
      <ul className="monthlyBox">
        {entriesGroupByYearMonth}
      </ul>
    )`

Archives = React.createClass
  loadArchivesFromServer: ->
    $.ajax
      url: this.props.url
      dataType: 'json'
      cache: false
      success: (data) =>
        this.setState data: data
      error: (xhr, status, err) =>
        console.error this.props.url, status, err.toString()
  getInitialState: ->
    data: []
  componentDidMount: ->
    @loadArchivesFromServer()
    setInterval @loadCommentsFromServer, @props.pollInterval
  render: ->
    `(
      <div className="archives archive-by-month">
        <MonthlyBox data={this.state.data} />
      </div>
    )`

ReactDOM.render(
  `<Archives url="/api/archives" pollInterval={900000} />`,
  document.getElementById('categories-wrapper')
)
