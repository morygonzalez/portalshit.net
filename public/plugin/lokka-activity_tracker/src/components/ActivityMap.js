import React, { Component, useEffect } from 'react'
import { MapContainer, TileLayer, Polyline, Marker, Popup, useMap, CircleMarker } from 'react-leaflet'
import L from 'leaflet'

// Custom emoji icons for start and finish markers
const createEmojiIcon = (emoji, size = 24) => {
  return L.divIcon({
    html: `<span style="font-size: ${size}px; line-height: 1;">${emoji}</span>`,
    className: 'emoji-marker',
    iconSize: [size, size],
    iconAnchor: [size / 2, size / 2],
    popupAnchor: [0, -size / 2]
  })
}

const startIcon = createEmojiIcon('🟢', 20)
const finishIcon = createEmojiIcon('🏁', 24)

// Component to fit map bounds to the route
function FitBounds({ bounds }) {
  const map = useMap()

  useEffect(() => {
    if (bounds) {
      map.fitBounds(bounds, { padding: [20, 20] })
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
    const { height = 400, highlightPoint } = this.props
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
          scrollWheelZoom={false}
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
            weight={8}
            opacity={0.8}
          />
          <Marker position={startPoint} icon={startIcon}>
            <Popup>Start</Popup>
          </Marker>
          <Marker position={endPoint} icon={finishIcon}>
            <Popup>Finish</Popup>
          </Marker>
          {highlightPoint && highlightPoint.latitude !== null && highlightPoint.longitude !== null && (
            <CircleMarker
              center={[highlightPoint.latitude, highlightPoint.longitude]}
              radius={6}
              pathOptions={{ color: '#1E88E5', weight: 2, fillColor: '#1E88E5', fillOpacity: 0.7 }}
              interactive={false}
            />
          )}
        </MapContainer>
      </div>
    )
  }
}
