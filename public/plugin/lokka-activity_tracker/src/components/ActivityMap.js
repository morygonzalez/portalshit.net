import React, { Component, useEffect } from 'react'
import { MapContainer, TileLayer, Polyline, Marker, Popup, useMap } from 'react-leaflet'

// Component to fit map bounds to the route
function FitBounds({ bounds }) {
  const map = useMap()

  useEffect(() => {
    if (bounds) {
      map.fitBounds(bounds, { padding: [50, 50] })
    }
  }, [map, bounds])

  return null
}

export default class ActivityMap extends Component {
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

  render() {
    const { height = 400 } = this.props
    const coordinates = this.getCoordinates()

    if (coordinates.length === 0) {
      return <div className="activity-map-empty">No GPS data available</div>
    }

    const center = this.getCenter()
    const bounds = this.getBounds()
    const startPoint = coordinates[0]
    const endPoint = coordinates[coordinates.length - 1]

    return (
      <div className="activity-map" style={{ height: `${height}px` }}>
        <MapContainer
          center={center}
          zoom={13}
          style={{ height: '100%', width: '100%' }}
        >
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>'
            url="https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png"
            subdomains="abcd"
          />
          <FitBounds bounds={bounds} />
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
