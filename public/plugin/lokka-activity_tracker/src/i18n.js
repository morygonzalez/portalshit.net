export const parseI18n = (element) => {
  if (!element || !element.dataset || !element.dataset.i18n) {
    return {}
  }

  try {
    const parsed = JSON.parse(element.dataset.i18n)
    return parsed && typeof parsed === 'object' ? parsed : {}
  } catch (error) {
    return {}
  }
}

export const t = (i18n, key, fallback) => {
  if (!i18n) return fallback
  if (Object.prototype.hasOwnProperty.call(i18n, key)) {
    return i18n[key]
  }
  return fallback
}
