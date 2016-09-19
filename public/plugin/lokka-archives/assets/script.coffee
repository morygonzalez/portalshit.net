Category = React.createClass
  render: ->
    return `(null)` unless this.props.category?
    `(
      <span className="category">
        <a href={"/category/" + this.props.category.slug + "/"}>{this.props.category.title}</a>
      </span>
    )`

Entry = React.createClass
  render: ->
    `(
      <li className="entry">
        <a href={this.props.link}>{this.props.title}</a>
        <div className="detail-information">
          <span className="created_at">{this.props.created_at}</span>
          <Category category={this.props.category} />
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
    title = this.props.monthYear.replace(
      /(\d{4})\-(\d{1,2})/, -> "#{arguments[1]}年#{arguments[2]}月"
    )
    `(
      <li className="entryList year-month">
        <h3>{title}</h3>
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

year     = location.href.match(/\d{4}/)
endPoint = if year? then "/archives/#{year[0]}.json" else "/archives.json"

ReactDOM.render(
  `<Archives url={endPoint} pollInterval={900000} />`,
  document.getElementById('archive-by-month')
)
