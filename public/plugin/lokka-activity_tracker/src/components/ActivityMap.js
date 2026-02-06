import React, { Component } from 'react'
import { MapContainer, TileLayer, Polyline, Marker, Popup } from 'react-leaflet'

export default class ActivityMap extends Component {
  constructor(props) {
    super(props)
    this.mapRef = React.createRef()
  }

  getCoordinates() {
    const { dataPoints } = this.props
    return dataPoints
      .filter(dp => dp.latitude !== null && dp.longitude !== null)
      .map(dp => [dp.latitude, dp.longitude])
  }

  getCenter() {
    const coordinates = this.getCoordinates()
    if (coordinates.length === 0) return [35.6762, 139.6503] // Tokyo default

    const sumLat = coordinates.reduce((sum, coord) => sum + coord[0], 0)
    const sumLng = coordinates.reduce((sum, coord) => sum + coord[1], 0)

    return [sumLat / coordinates.length, sumLng / coordinates.length]
  }

  getBounds() {
    const coordinates = this.getCoordinates()
    if (coordinates.length === 0) return null

    const lats = coordinates.map(c => c[0])
    const lngs = coordinates.map(c => c[1])

    return [
      [Math.min(...lats), Math.min(...lngs)],
      [Math.max(...lats), Math.max(...lngs)]
    ]
  }

  componentDidMount() {
    // Fit bounds after map is rendered
    setTimeout(() => {
      const map = this.mapRef.current
      if (map) {
        const bounds = this.getBounds()
        if (bounds) {
          map.fitBounds(bounds, { padding: [20, 20] })
        }
      }
    }, 100)
  }

  render() {
    const { height = 400 } = this.props
    const coordinates = this.getCoordinates()

    if (coordinates.length === 0) {
      return <div className="activity-map-empty">No GPS data available</div>
    }

    const center = this.getCenter()
    const startPoint = coordinates[0]
    const endPoint = coordinates[coordinates.length - 1]

    return (
      <div className="activity-map" style={{ height: `${height}px` }}>
        <MapContainer
          center={center}
          zoom={13}
          style={{ height: '100%', width: '100%' }}
          ref={this.mapRef}
        >
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          <Polyline
            positions={coordinates}
            color="#E53935"
            weight={3}
            opacity={0.8}
          />
          <Marker position={startPoint}>
            <Popup>Start</Popup>
          </Marker>
          <Marker position={endPoint}>
            <Popup>Finish</Popup>
          </Marker>
        </MapContainer>
      </div>
    )
  }
}
