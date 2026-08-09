import React from 'react'

const LauncherBubble = ({ open, onToggle }) => (
  <button
    type="button"
    className={`dify-chat-launcher${open ? ' is-open' : ''}`}
    onClick={onToggle}
    aria-label={open ? 'チャットを閉じる' : 'チャットを開く'}
  >
    <i className={open ? 'fas fa-times' : 'fas fa-comment-dots'} />
  </button>
)

export default LauncherBubble
