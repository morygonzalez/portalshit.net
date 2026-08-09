const USER_KEY = 'dify_chat_user_id'
const CONVERSATION_KEY = 'dify_chat_conversation_id'
const PANEL_SIZE_KEY = 'dify_chat_panel_size'
const SIZE_MODE_KEY = 'dify_chat_size_mode'
const VALID_SIZE_MODES = ['small', 'medium', 'large', 'custom']

const generateId = () => {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID()
  }
  return `u-${Date.now()}-${Math.random().toString(36).slice(2)}`
}

export const getUserId = () => {
  let id = localStorage.getItem(USER_KEY)
  if (!id) {
    id = generateId()
    localStorage.setItem(USER_KEY, id)
  }
  return id
}

export const getStoredConversationId = () => localStorage.getItem(CONVERSATION_KEY)

export const setStoredConversationId = (id) => {
  if (id) {
    localStorage.setItem(CONVERSATION_KEY, id)
  } else {
    localStorage.removeItem(CONVERSATION_KEY)
  }
}

export const getStoredPanelSize = () => {
  try {
    const raw = localStorage.getItem(PANEL_SIZE_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw)
    if (typeof parsed?.width === 'number' && typeof parsed?.height === 'number') {
      return parsed
    }
  } catch (_e) {
    // 壊れた値は無視してデフォルトサイズにフォールバック
  }
  return null
}

export const setStoredPanelSize = (size) => {
  localStorage.setItem(PANEL_SIZE_KEY, JSON.stringify(size))
}

export const getStoredSizeMode = () => {
  const mode = localStorage.getItem(SIZE_MODE_KEY)
  return VALID_SIZE_MODES.includes(mode) ? mode : null
}

export const setStoredSizeMode = (mode) => {
  localStorage.setItem(SIZE_MODE_KEY, mode)
}
