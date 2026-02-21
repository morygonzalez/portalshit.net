/**
 * Range slider filters for distance and elevation on the activities list page.
 * Pure vanilla JS — no React dependency.
 */

function createSliderGroup(container, { label, unit, suffix, max, step, onChange }) {
  const wrapper = document.createElement('div')
  wrapper.className = 'range-filter'

  const labelEl = document.createElement('label')
  labelEl.className = 'range-filter-label'
  labelEl.textContent = label

  const slider = document.createElement('input')
  slider.type = 'range'
  slider.className = 'range-filter-slider'
  slider.min = '0'
  slider.max = String(max)
  slider.step = String(step)
  slider.value = '0'

  const valueEl = document.createElement('span')
  valueEl.className = 'range-filter-value'
  valueEl.textContent = ''

  const resetBtn = document.createElement('button')
  resetBtn.type = 'button'
  resetBtn.className = 'range-filter-reset'
  resetBtn.textContent = '\u00d7'
  resetBtn.title = 'Reset'
  resetBtn.style.display = 'none'

  slider.addEventListener('input', () => {
    const val = Number(slider.value)
    if (val > 0) {
      valueEl.textContent = `${val} ${unit}${suffix}`
      resetBtn.style.display = ''
    } else {
      valueEl.textContent = ''
      resetBtn.style.display = 'none'
    }
    onChange(val)
  })

  resetBtn.addEventListener('click', () => {
    slider.value = '0'
    valueEl.textContent = ''
    resetBtn.style.display = 'none'
    onChange(0)
  })

  wrapper.appendChild(labelEl)
  wrapper.appendChild(slider)
  wrapper.appendChild(valueEl)
  wrapper.appendChild(resetBtn)
  container.appendChild(wrapper)

  return { slider, valueEl, resetBtn }
}

export function initRangeFilters(root) {
  const rows = document.querySelectorAll('.activities-list .activities tbody tr')
  if (rows.length === 0) return

  let maxDistance = 0
  let maxElevation = 0

  rows.forEach((row) => {
    const d = row.dataset.distance
    const e = row.dataset.elevation
    if (d !== '' && d !== undefined) {
      const val = parseFloat(d)
      if (val > maxDistance) maxDistance = val
    }
    if (e !== '' && e !== undefined) {
      const val = parseFloat(e)
      if (val > maxElevation) maxElevation = val
    }
  })

  // Round up max values to nice increments
  const distanceStep = 1
  const elevationStep = 50
  maxDistance = Math.ceil(maxDistance / distanceStep) * distanceStep
  maxElevation = Math.ceil(maxElevation / elevationStep) * elevationStep

  if (maxDistance === 0 && maxElevation === 0) return

  const filtersDiv = document.createElement('div')
  filtersDiv.className = 'range-filters'

  let currentDistanceMin = 0
  let currentElevationMin = 0

  function applyFilters() {
    const tables = document.querySelectorAll('.activities-list .activities')
    tables.forEach((table) => {
      const tbody = table.querySelector('tbody')
      if (!tbody) return

      const tableRows = tbody.querySelectorAll('tr')
      let visibleCount = 0

      tableRows.forEach((row) => {
        const d = row.dataset.distance
        const e = row.dataset.elevation

        // Rows without data are always shown
        if (d === '' && e === '') {
          row.style.display = ''
          visibleCount++
          return
        }

        let show = true
        if (currentDistanceMin > 0) {
          if (d === '' || parseFloat(d) < currentDistanceMin) show = false
        }
        if (currentElevationMin > 0) {
          if (e === '' || parseFloat(e) < currentElevationMin) show = false
        }

        row.style.display = show ? '' : 'none'
        if (show) visibleCount++
      })

      // Hide entire table if all rows are hidden
      table.style.display = visibleCount === 0 ? 'none' : ''
    })
  }

  const distanceLabel = root.dataset.distanceLabel || 'Distance'
  const elevationLabel = root.dataset.elevationLabel || 'Elevation Gain'

  if (maxDistance > 0) {
    createSliderGroup(filtersDiv, {
      label: distanceLabel,
      unit: 'km',
      suffix: '\u4ee5\u4e0a',
      max: maxDistance,
      step: distanceStep,
      onChange(val) {
        currentDistanceMin = val
        applyFilters()
      }
    })
  }

  if (maxElevation > 0) {
    createSliderGroup(filtersDiv, {
      label: elevationLabel,
      unit: 'm',
      suffix: '\u4ee5\u4e0a',
      max: maxElevation,
      step: elevationStep,
      onChange(val) {
        currentElevationMin = val
        applyFilters()
      }
    })
  }

  root.appendChild(filtersDiv)
}
