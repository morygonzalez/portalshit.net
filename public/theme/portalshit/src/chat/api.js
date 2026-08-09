export const streamChatMessage = async ({ query, user, conversationId, signal, onEvent }) => {
  const response = await fetch('/api/chat/messages', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      query,
      user,
      conversation_id: conversationId || undefined
    }),
    signal
  })

  if (!response.ok || !response.body) {
    const text = await response.text().catch(() => '')
    throw new Error(text || `request failed (${response.status})`)
  }

  const reader = response.body.getReader()
  const decoder = new TextDecoder('utf-8')
  let buffer = ''

  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    buffer += decoder.decode(value, { stream: true })

    let boundary
    while ((boundary = buffer.indexOf('\n\n')) !== -1) {
      const rawEvent = buffer.slice(0, boundary)
      buffer = buffer.slice(boundary + 2)

      const dataLine = rawEvent.split('\n').find((line) => line.startsWith('data:'))
      if (!dataLine) continue

      const jsonText = dataLine.slice(5).trim()
      if (!jsonText) continue

      try {
        onEvent(JSON.parse(jsonText))
      } catch (_e) {
        // 不正なチャンクは無視
      }
    }
  }
}

export const fetchParameters = async () => {
  const response = await fetch('/api/chat/parameters')
  if (!response.ok) throw new Error('failed to load parameters')
  return response.json()
}

export const fetchHistory = async ({ conversationId, user }) => {
  const query = new URLSearchParams({ conversation_id: conversationId, user })
  const response = await fetch(`/api/chat/history?${query}`)
  if (!response.ok) throw new Error('failed to load history')
  return response.json()
}

export const fetchSuggested = async ({ messageId, user }) => {
  const query = new URLSearchParams({ message_id: messageId, user })
  const response = await fetch(`/api/chat/suggested?${query}`)
  if (!response.ok) throw new Error('failed to load suggested questions')
  return response.json()
}

export const stopMessage = async ({ taskId, user }) => {
  const response = await fetch('/api/chat/stop', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ task_id: taskId, user })
  })
  if (!response.ok) throw new Error('failed to stop message')
}
