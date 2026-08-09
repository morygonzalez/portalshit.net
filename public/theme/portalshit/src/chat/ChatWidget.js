import React, { useState, useRef, useCallback, useEffect } from 'react'
import LauncherBubble from './LauncherBubble'
import MessageList from './MessageList'
import ChatInput from './ChatInput'
import SuggestedQuestions from './SuggestedQuestions'
import ResizeHandle from './ResizeHandle'
import SizeSwitcher from './SizeSwitcher'
import { SIZE_PRESETS, DEFAULT_SIZE_MODE } from './sizePresets'
import { streamChatMessage, fetchParameters, fetchHistory, fetchSuggested, stopMessage } from './api'
import {
  getUserId,
  getStoredConversationId,
  setStoredConversationId,
  getStoredPanelSize,
  setStoredPanelSize,
  getStoredSizeMode,
  setStoredSizeMode
} from './storage'

let messageSeq = 0
const nextId = () => `m-${Date.now()}-${messageSeq++}`

const ChatWidget = () => {
  const [open, setOpen] = useState(false)
  const [messages, setMessages] = useState([])
  const [sending, setSending] = useState(false)
  const [openingSuggestions, setOpeningSuggestions] = useState([])
  const [suggestedQuestions, setSuggestedQuestions] = useState([])
  const [error, setError] = useState(null)
  const [panelSize, setPanelSize] = useState(() => getStoredPanelSize())
  const [sizeMode, setSizeMode] = useState(() => (
    getStoredSizeMode() || (getStoredPanelSize() ? 'custom' : DEFAULT_SIZE_MODE)
  ))

  const panelRef = useRef(null)
  const userIdRef = useRef(null)
  const conversationIdRef = useRef(null)
  const currentTaskIdRef = useRef(null)
  const abortRef = useRef(null)
  const hydratedRef = useRef(false)
  const parametersRef = useRef(null)

  useEffect(() => {
    userIdRef.current = getUserId()
    conversationIdRef.current = getStoredConversationId()
  }, [])

  const hydrate = useCallback(async () => {
    if (hydratedRef.current) return
    hydratedRef.current = true

    try {
      const parameters = await fetchParameters()
      parametersRef.current = parameters
      setOpeningSuggestions(parameters.suggested_questions || [])

      if (conversationIdRef.current) {
        const history = await fetchHistory({
          conversationId: conversationIdRef.current,
          user: userIdRef.current
        })
        const historyMessages = (history.data || []).flatMap((item) => ([
          { id: `${item.id}-q`, role: 'user', content: item.query },
          {
            id: `${item.id}-a`,
            role: 'assistant',
            content: item.answer,
            citations: item.retriever_resources || []
          }
        ]))

        if (historyMessages.length > 0) {
          setMessages(historyMessages)
          return
        }
      }

      if (parameters.opening_statement) {
        setMessages([{ id: nextId(), role: 'assistant', content: parameters.opening_statement }])
      }
    } catch (_e) {
      setError('チャットの初期化に失敗しました')
    }
  }, [])

  useEffect(() => {
    if (open) hydrate()
  }, [open, hydrate])

  const handleToggle = () => setOpen((prev) => !prev)
  const handleClose = () => setOpen(false)

  const handleSend = useCallback(async (text) => {
    setError(null)
    setSuggestedQuestions([])

    const assistantId = nextId()
    setMessages((prev) => [
      ...prev,
      { id: nextId(), role: 'user', content: text },
      { id: assistantId, role: 'assistant', content: '', pending: true }
    ])
    setSending(true)

    const controller = new AbortController()
    abortRef.current = controller

    let answer = ''
    let lastMessageId = null

    try {
      await streamChatMessage({
        query: text,
        user: userIdRef.current,
        conversationId: conversationIdRef.current,
        signal: controller.signal,
        onEvent: (payload) => {
          if (payload.conversation_id && !conversationIdRef.current) {
            conversationIdRef.current = payload.conversation_id
            setStoredConversationId(payload.conversation_id)
          }
          if (payload.task_id) currentTaskIdRef.current = payload.task_id

          switch (payload.event) {
            case 'message':
            case 'agent_message':
              answer += payload.answer || ''
              lastMessageId = payload.message_id || lastMessageId
              setMessages((prev) => prev.map((m) => (
                m.id === assistantId ? { ...m, content: answer } : m
              )))
              break
            case 'message_replace':
              answer = payload.answer || ''
              setMessages((prev) => prev.map((m) => (
                m.id === assistantId ? { ...m, content: answer } : m
              )))
              break
            case 'message_end':
              lastMessageId = payload.message_id || lastMessageId
              setMessages((prev) => prev.map((m) => (
                m.id === assistantId
                  ? { ...m, pending: false, citations: payload.metadata?.retriever_resources || [] }
                  : m
              )))
              break
            case 'error':
              setMessages((prev) => prev.map((m) => (
                m.id === assistantId
                  ? { ...m, pending: false, error: payload.message || 'エラーが発生しました' }
                  : m
              )))
              break
            case 'workflow_finished':
              // Chatflow (workflow) 型アプリはワークフロー自体が失敗すると
              // "error" イベントではなく status: "failed" の workflow_finished を返す
              if (payload.data?.status === 'failed') {
                setMessages((prev) => prev.map((m) => (
                  m.id === assistantId
                    ? { ...m, pending: false, error: payload.data?.error || 'エラーが発生しました' }
                    : m
                )))
              }
              break
            default:
              break
          }
        }
      })
    } catch (e) {
      if (e.name !== 'AbortError') {
        setMessages((prev) => prev.map((m) => (
          m.id === assistantId
            ? { ...m, pending: false, error: 'メッセージの送信に失敗しました' }
            : m
        )))
      }
    } finally {
      setSending(false)
      currentTaskIdRef.current = null
      abortRef.current = null

      if (lastMessageId) {
        fetchSuggested({ messageId: lastMessageId, user: userIdRef.current })
          .then((res) => setSuggestedQuestions(res.data || []))
          .catch(() => {})
      }
    }
  }, [])

  const handleStop = useCallback(() => {
    abortRef.current?.abort()
    if (currentTaskIdRef.current) {
      stopMessage({ taskId: currentTaskIdRef.current, user: userIdRef.current }).catch(() => {})
    }
    setSending(false)
  }, [])

  const handleResizeEnd = useCallback((size) => {
    setPanelSize(size)
    setStoredPanelSize(size)
    setSizeMode('custom')
    setStoredSizeMode('custom')
  }, [])

  const handleSizeModeChange = useCallback((mode) => {
    setSizeMode(mode)
    setStoredSizeMode(mode)
  }, [])

  const handleNewConversation = useCallback(() => {
    conversationIdRef.current = null
    setStoredConversationId(null)
    setSuggestedQuestions([])
    setError(null)
    setMessages(
      parametersRef.current?.opening_statement
        ? [{ id: nextId(), role: 'assistant', content: parametersRef.current.opening_statement }]
        : []
    )
  }, [])

  const isFullscreen = sizeMode === 'large'
  const panelDimensions = isFullscreen
    ? undefined
    : sizeMode === 'custom' && panelSize
      ? panelSize
      : (SIZE_PRESETS[sizeMode] || SIZE_PRESETS[DEFAULT_SIZE_MODE])

  return (
    <div className={`dify-chat-widget${open ? ' is-open' : ''}`}>
      {open && (
        <div
          ref={panelRef}
          className={`dify-chat-panel${isFullscreen ? ' is-fullscreen' : ''}`}
          style={panelDimensions ? { width: `${panelDimensions.width}px`, height: `${panelDimensions.height}px` } : undefined}
        >
          {!isFullscreen && <ResizeHandle panelRef={panelRef} onResizeEnd={handleResizeEnd} />}

          <div className="dify-chat-panel__header">
            <span>チャット</span>
            <button type="button" className="dify-chat-panel__close" onClick={handleClose} aria-label="チャットを閉じる">
              <i className="fas fa-times" />
            </button>
          </div>

          <div className="dify-chat-panel__toolbar">
            <SizeSwitcher sizeMode={sizeMode} onChange={handleSizeModeChange} />
            <button type="button" className="dify-chat-panel__reset" onClick={handleNewConversation}>
              新しい会話
            </button>
          </div>

          <MessageList messages={messages} />

          {error && <div className="dify-chat-error">{error}</div>}

          <SuggestedQuestions
            questions={messages.length === 0 ? openingSuggestions : suggestedQuestions}
            onSelect={handleSend}
          />

          <div className="dify-chat-panel__footer">
            <ChatInput onSend={handleSend} disabled={sending} />
            {sending && (
              <button type="button" className="dify-chat-stop" onClick={handleStop}>
                停止
              </button>
            )}
          </div>
        </div>
      )}
      {!(open && isFullscreen) && <LauncherBubble open={open} onToggle={handleToggle} />}
    </div>
  )
}

export default ChatWidget
