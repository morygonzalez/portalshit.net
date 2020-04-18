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
      categories: [],
      disabled: []
    }
    this.colors = [
      '#E53935', '#D81B60', '#8E24AA', '#5E35B1', '#3949AB', '#1E88E5', '#039BE5',
      '#00ACC1', '#00897B', '#43A047', '#7CB342', '#C0CA33', '#FDD835', '#FFB300'
    ]
    this.selectBar = this.selectBar.bind(this)
  }

  async loadChartFromServer() {
    const request = await fetch('/archives/chart.json')
    const response = await request.json()
    this.setState({ data: response })
  }

  async loadCategoriesFromServer() {
    const request = await fetch('/archives/categories.json')
    const response = await request.json()
    this.setState({ categories: response })
  }

  componentDidMount() {
    this.loadChartFromServer()
    this.loadCategoriesFromServer()
  }

  selectBar(event) {
    let dataKey = event.dataKey.trim()
    if (this.state.disabled.includes(dataKey)) {
      this.setState({ disabled: this.state.disabled.filter(item => item !== dataKey) })
    } else {
      this.setState({ disabled: this.state.disabled.concat([dataKey]) })
    }
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
          <XAxis dataKey="year" />
          <YAxis />
          <Tooltip labelStyle={{ color: '#000', fontWeight: 'bold' }} itemStyle={{ margin: '0 2px 0 4px', padding: '0' }} />
          <Legend onClick={this.selectBar} />
          {this.state.categories.map((category, index) => {
            let dataKey = this.state.disabled.includes(category) ? category + " " : category
            let color = this.colors[index % this.colors.length]
            return(<Bar key={index} dataKey={dataKey} stackId="a" fill={color} />)
          })}
        </BarChart>
      </ResponsiveContainer>
    );
  }
}

