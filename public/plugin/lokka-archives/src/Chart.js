import React, { PureComponent } from 'react'
import {
  BarChart, Bar, Cell, XAxis, YAxis, CartesianGrid,
  Tooltip, Legend, ResponsiveContainer
} from 'recharts'

export default class Chart extends PureComponent {
  constructor(props) {
    super(props)
    this.state = {
      data: [],
      selectedOption: null
    }
    this.colors = [
      '#E53935', '#D81B60', '#8E24AA', '#5E35B1', '#3949AB', '#1E88E5', '#039BE5',
      '#00ACC1', '#00897B', '#43A047', '#7CB342', '#C0CA33', '#FDD835', '#FFB300'
    ]
    this.selectBar = this.selectBar.bind(this)
    this.formatTooltipLabel = this.formatTooltipLabel.bind(this)
  }

  async loadChartFromServer() {
    let request
    if (this.props.year !== null) {
      request = await fetch(`/archives/chart.json?year=${this.props.year}`)
    } else {
      request = await fetch('/archives/chart.json')
    }
    const response = await request.json()
    const data = response.map((item) => {
      const label = item['duration']
      if (this.props.year !== null) {
        const date = new Date(`${label}-01`)
        const month = date.toLocaleDateString('default', { month: 'short' })
        item['key'] = month
      } else {
        const date = new Date(`${label}-01-01`)
        const year = date.toLocaleDateString('default', { year: 'numeric' })
        item['key'] = year
      }
      return item
    })
    this.setState({ data: data })
  }

  componentDidMount() {
    this.loadChartFromServer()
  }

  componentDidUpdate(prevProps, prevState) {
    if (prevProps.year !== this.props.year) {
      this.loadChartFromServer()
    }
  }

  selectBar(selectedOption) {
    let dataKey = selectedOption.dataKey.trim()
    let disabledCategories = this.props.disabledCategories
    if (disabledCategories.includes(dataKey)) {
      disabledCategories = disabledCategories.filter(item => item !== dataKey)
    } else {
      disabledCategories = disabledCategories.concat([dataKey])
    }
    this.setState(
      { selectedOption },
      () => {
        this.props.update(disabledCategories)
      }
    )
  }

  formatTooltipLabel(label, payload) {
    const total = payload.reduce((sum, item) => { return sum = sum + item.value }, 0);
    return `${label} : ${total}`
  }

  render() {
    return (
      <ResponsiveContainer height={500}>
        <BarChart
          data={this.state.data}
          margin={{
            top: 20, right: 20, left: 0, bottom: 20,
          }}
          style={{ fontSize: '14px' }}
        >
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis dataKey="key" />
          <YAxis />
          <Tooltip
            labelStyle={{ color: '#000', fontWeight: 'bold' }}
            itemStyle={{ margin: '0 2px 0 4px', padding: '0' }}
            labelFormatter={this.formatTooltipLabel}
          />
          <Legend onClick={this.selectBar} />
          {this.props.categories.map((category, index) => {
            let disabledCategories = this.props.disabledCategories.includes(category)
            let color = this.colors[index % this.colors.length]
            return(<Bar key={index} dataKey={category} stackId="a" fill={color} hide={disabledCategories} />)
          })}
        </BarChart>
      </ResponsiveContainer>
    );
  }
}

