import React, { useRef } from 'react'

const MIN_WIDTH = 320
const MIN_HEIGHT = 420

// パネルは右下アンカーで、左上角をドラッグして広げる。
// CSS 側の max-width/max-height (ビューポート基準) が上限として効くため、
// ここでは最小サイズだけ担保すればよい。
const clampSize = (width, height) => ({
  width: Math.max(width, MIN_WIDTH),
  height: Math.max(height, MIN_HEIGHT)
})

const ResizeHandle = ({ panelRef, onResizeEnd }) => {
  const startRef = useRef(null)

  const handlePointerMove = (event) => {
    if (!startRef.current || !panelRef.current) return
    const dx = startRef.current.pointerX - event.clientX
    const dy = startRef.current.pointerY - event.clientY
    const { width, height } = clampSize(startRef.current.width + dx, startRef.current.height + dy)
    panelRef.current.style.width = `${width}px`
    panelRef.current.style.height = `${height}px`
  }

  const handlePointerUp = () => {
    startRef.current = null
    window.removeEventListener('pointermove', handlePointerMove)
    window.removeEventListener('pointerup', handlePointerUp)

    if (panelRef.current) {
      panelRef.current.style.transition = ''
      const rect = panelRef.current.getBoundingClientRect()
      onResizeEnd({ width: Math.round(rect.width), height: Math.round(rect.height) })
    }
  }

  const handlePointerDown = (event) => {
    if (!panelRef.current) return
    event.preventDefault()

    const rect = panelRef.current.getBoundingClientRect()
    startRef.current = {
      pointerX: event.clientX,
      pointerY: event.clientY,
      width: rect.width,
      height: rect.height
    }
    // プリセット切替用のトランジションがドラッグ追従を鈍らせないよう一時無効化
    panelRef.current.style.transition = 'none'
    window.addEventListener('pointermove', handlePointerMove)
    window.addEventListener('pointerup', handlePointerUp)
  }

  return (
    <div
      className="dify-chat-resize-handle"
      onPointerDown={handlePointerDown}
      role="separator"
      aria-orientation="horizontal"
      aria-label="チャットウィンドウのサイズを変更"
      title="ドラッグしてサイズ変更"
    />
  )
}

export default ResizeHandle
