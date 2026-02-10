import React, { PureComponent } from 'react'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid,
  Tooltip, Legend, ResponsiveContainer
} from 'recharts'
import { t } from '../i18n'

const MOBILE_BREAKPOINT = 768

export default class MonthlyStatsChart extends PureComponent {
  constructor(props) {
    super(props)
    this.state = {
      data: [],
      loading: true,
      error: null,
      isMobile: window.innerWidth < MOBILE_BREAKPOINT
    }
    this.handleResize = this.handleResize.bind(this)
  }

  handleResize() {
    const isMobile = window.innerWidth < MOBILE_BREAKPOINT
    if (isMobile !== this.state.isMobile) {
      this.setState({ isMobile })
    }
  }

  componentWillUnmount() {
    window.removeEventListener('resize', this.handleResize)
  }

  async componentDidMount() {
    window.addEventListener('resize', this.handleResize)
    try {
      const { year } = this.props
      const url = year
        ? `/activities/monthly_stats.json?year=${year}`
        : '/activities/monthly_stats.json'
      const response = await fetch(url)
      if (!response.ok) {
        throw new Error('Failed to load monthly stats')
      }
      const data = await response.json()
      // Sort by year and month ascending (oldest first, left to right)
      const sortedData = data.sort((a, b) => {
        if (a.year !== b.year) return a.year - b.year
        return a.month - b.month
      })
      this.setState({ data: sortedData, loading: false })
    } catch (error) {
      this.setState({ error: error.message, loading: false })
    }
  }

  formatTooltip(value, name) {
    const { i18n } = this.props
    if (name === t(i18n, 'monthly_distance', 'Distance')) {
      return [`${Math.floor(value * 10) / 10} km`, name]
    }
    if (name === t(i18n, 'monthly_elevation', 'Elevation Gain')) {
      return [`${Math.floor(value)} m`, name]
    }
    return [value, name]
  }

  formatMonthLabel(label) {
    const { i18n } = this.props
    // label is in "YYYY-MM" format
    const [year, month] = label.split('-')
    const monthFormat = t(i18n, 'monthly_label_format', '{year}-{month}')
    return monthFormat.replace('{year}', year).replace('{month}', parseInt(month, 10))
  }

  render() {
    const { data, loading, error, isMobile } = this.state
    const { i18n } = this.props

    if (loading) {
      return <div className="monthly-chart-loading">{t(i18n, 'monthly_loading', 'Loading...')}</div>
    }

    if (error) {
      return <div className="monthly-chart-error">{t(i18n, 'error_prefix', 'Error: ')}{error}</div>
    }

    if (data.length === 0) {
      return <div className="monthly-chart-empty">{t(i18n, 'monthly_empty', 'No data available')}</div>
    }

    const maxDistance = Math.ceil(Math.max(...data.map(d => d.total_distance_km || 0)))
    const maxElevation = Math.ceil(Math.max(...data.map(d => d.total_ascent_meters || 0)))

    return (
      <ResponsiveContainer width="100%" height={300}>
        <BarChart
          data={data}
          margin={isMobile
            ? { top: 20, right: 0, left: 0, bottom: 20 }
            : { top: 20, right: 30, left: 20, bottom: 20 }
          }
        >
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis dataKey="label" tick={{ fontSize: 12 }} tickFormatter={(label) => this.formatMonthLabel(label)} />
          <YAxis
            yAxisId="distance"
            orientation="left"
            domain={[0, maxDistance]}
            tick={isMobile ? false : { fontSize: 12 }}
            tickLine={!isMobile}
            width={isMobile ? 0 : undefined}
            label={isMobile ? undefined : { value: 'km', angle: -90, position: 'insideLeft', fontSize: 12 }}
          />
          <YAxis
            yAxisId="elevation"
            orientation="right"
            domain={[0, maxElevation]}
            tick={isMobile ? false : { fontSize: 12 }}
            tickLine={!isMobile}
            width={isMobile ? 0 : undefined}
            label={isMobile ? undefined : { value: 'm', angle: 90, position: 'insideRight', fontSize: 12 }}
          />
          <Tooltip
            formatter={(value, name) => this.formatTooltip(value, name)}
            labelFormatter={(label) => this.formatMonthLabel(label)}
            labelStyle={{ color: '#000', fontWeight: 'bold' }}
          />
          <Legend />
          <Bar
            yAxisId="distance"
            dataKey="total_distance_km"
            name={t(i18n, 'monthly_distance', 'Distance')}
            fill="#1E88E5"
            radius={[4, 4, 0, 0]}
          />
          <Bar
            yAxisId="elevation"
            dataKey="total_ascent_meters"
            name={t(i18n, 'monthly_elevation', 'Elevation Gain')}
            fill="#757575"
            radius={[4, 4, 0, 0]}
          />
        </BarChart>
      </ResponsiveContainer>
    )
  }
}
