import React from 'react'

const OPTIONS = [
  { mode: 'small', label: '小', aria: '小さいサイズにする' },
  { mode: 'medium', label: '中', aria: '中くらいのサイズにする' },
  { mode: 'large', label: '大', aria: 'フルスクリーンにする' }
]

const SizeSwitcher = ({ sizeMode, onChange }) => (
  <div className="dify-chat-size-switcher" role="group" aria-label="ウィンドウサイズ">
    {OPTIONS.map(({ mode, label, aria }) => (
      <button
        key={mode}
        type="button"
        className={sizeMode === mode ? 'is-active' : ''}
        onClick={() => onChange(mode)}
        aria-label={aria}
        aria-pressed={sizeMode === mode}
      >
        {label}
      </button>
    ))}
  </div>
)

export default SizeSwitcher
