data = [
  {
    year:  2015,
    month: 10,
    entries: [
      { title: 'Foo',  category: '雑談', created_at: '2015/10/02 23:43' },
      { title: 'Bar',  category: '雑談', created_at: '2015/10/02 23:43' },
      { title: 'Buzz', category: '雑談', created_at: '2015/10/02 23:43' }
    ]
  },
  {
    year:  2015,
    month: 11,
    entries: [
      { title: 'Foo',  category: '雑談', created_at: '2015/11/02 23:43' },
      { title: 'Bar',  category: '雑談', created_at: '2015/11/02 23:43' },
      { title: 'Buzz', category: '雑談', created_at: '2015/11/02 23:43' }
    ]
  }
]

Entry = React.createClass(
  render: ->
    `(
      <li className="entry">
        <a href="#">{this.props.title}</a>
        <div className="detail-information">
          <span className="created_at">{this.props.created_at}</span>
          <span className="category">{this.props.category}</span>
        </div>
      </li>
    )`
)

EntryList = React.createClass(
  render: ->
    entries = this.props.entries.map (entry) ->
      uniqueKey = "#{entry.title}-#{entry.created_at}"
      `(
        <Entry key={uniqueKey} title={entry.title} category={entry.category} created_at={entry.created_at} />
      )`
    `(
      <li>
        <h3>{this.props.year}年{this.props.month}月</h3>
        <ul>{entries}</ul>
      </li>
    )`
)

MonthlyBox = React.createClass(
  render: ->
    entriesGroupByYearMonth = this.props.data.map (entries) ->
      uniqueKey = "#{entries.year}-#{entries.month}"
      `(
        <EntryList key={uniqueKey} year={entries.year} month={entries.month} entries={entries.entries} />
      )`
    `(
      <ul className="entryList">
        {entriesGroupByYearMonth}
      </ul>
    )`
)

Archives = React.createClass(
  render: ->
    `(
      <div className="archives">
        <MonthlyBox data={this.props.data} />
      </div>
    )`
)

ReactDOM.render(`<Archives data={data} />`, document.getElementById('categories-wrapper'))
