import React, { useState, useRef, useEffect } from 'react'

// 日本語 IME の変換確定 Enter を送信として誤解釈しないための入力欄。
// - 変換中 (isComposing / keyCode 229) の Enter は無視する
// - Safari 等では compositionend の "後" に確定用 Enter の keydown が来るため、
//   compositionend 直後 1 tick だけ Enter を抑止するガードを併用する
const ChatInput = ({ onSend, disabled }) => {
  const [value, setValue] = useState('')
  const justComposedRef = useRef(false)
  const textareaRef = useRef(null)

  useEffect(() => {
    const el = textareaRef.current
    if (!el) return
    el.style.height = 'auto'
    el.style.height = `${el.scrollHeight}px`
  }, [value])

  const submit = () => {
    const trimmed = value.trim()
    if (!trimmed || disabled) return
    onSend(trimmed)
    setValue('')
  }

  const handleCompositionEnd = () => {
    justComposedRef.current = true
    setTimeout(() => { justComposedRef.current = false }, 0)
  }

  const handleKeyDown = (event) => {
    if (event.key !== 'Enter' || event.shiftKey) return
    if (event.isComposing || event.keyCode === 229) return
    if (justComposedRef.current) {
      event.preventDefault()
      return
    }

    event.preventDefault()
    submit()
  }

  return (
    <div className="dify-chat-input">
      <textarea
        ref={textareaRef}
        value={value}
        onChange={(event) => setValue(event.target.value)}
        onCompositionEnd={handleCompositionEnd}
        onKeyDown={handleKeyDown}
        placeholder="メッセージを入力"
        rows={1}
        disabled={disabled}
      />
      <button
        type="button"
        className="dify-chat-input__send"
        onClick={submit}
        disabled={disabled || !value.trim()}
        aria-label="送信"
      >
        <i className="fas fa-paper-plane" />
      </button>
    </div>
  )
}

export default ChatInput
