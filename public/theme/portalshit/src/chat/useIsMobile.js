import { useState, useEffect } from 'react'

// styles/components/_dify_chat.scss のモバイル用ブレークポイントと揃えること
const MOBILE_QUERY = '(max-width: 640px)'

const matchMobile = () => (
  typeof window !== 'undefined' && typeof window.matchMedia === 'function'
    ? window.matchMedia(MOBILE_QUERY).matches
    : false
)

// スマートフォン幅かどうか。チャットパネルを常にフルスクリーン
// (デスクトップの「大」モード相当) で表示するかの判定に使う
const useIsMobile = () => {
  const [isMobile, setIsMobile] = useState(matchMobile)

  useEffect(() => {
    if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') return undefined

    const mql = window.matchMedia(MOBILE_QUERY)
    const handleChange = (event) => setIsMobile(event.matches)

    // 端末の回転などで初期値とずれている可能性があるため同期しておく
    setIsMobile(mql.matches)
    mql.addEventListener('change', handleChange)

    return () => mql.removeEventListener('change', handleChange)
  }, [])

  return isMobile
}

export default useIsMobile
