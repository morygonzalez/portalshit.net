import React, { useEffect, useState } from 'react'

// ページ表示中のみ有効な簡易キャッシュ (同じURLの再フェッチを避ける)
const cache = new Map()

const OgpCard = ({ url, fallbackTitle }) => {
  const [data, setData] = useState(() => cache.get(url) || null)
  const [status, setStatus] = useState(cache.has(url) ? 'done' : 'loading')

  useEffect(() => {
    if (cache.has(url)) {
      setData(cache.get(url))
      setStatus('done')
      return
    }

    let cancelled = false
    setStatus('loading')

    fetch(`/api/chat/ogp?url=${encodeURIComponent(url)}`)
      .then((response) => {
        if (!response.ok) throw new Error('failed to fetch ogp')
        return response.json()
      })
      .then((json) => {
        if (cancelled) return
        cache.set(url, json)
        setData(json)
        setStatus('done')
      })
      .catch(() => {
        if (!cancelled) setStatus('error')
      })

    return () => { cancelled = true }
  }, [url])

  if (status === 'error') {
    return (
      <a className="dify-chat-ogp dify-chat-ogp--fallback" href={url} target="_blank" rel="noopener noreferrer">
        <i className="fas fa-link" />
        {fallbackTitle || url}
      </a>
    )
  }

  if (status === 'loading' || !data) {
    return (
      <div className="dify-chat-ogp dify-chat-ogp--loading" aria-label="リンク情報を取得中">
        <span className="dify-chat-ogp__image-skeleton" />
        <span className="dify-chat-ogp__body">
          <span className="dify-chat-ogp__title">{fallbackTitle || url}</span>
        </span>
      </div>
    )
  }

  return (
    <a className="dify-chat-ogp" href={url} target="_blank" rel="noopener noreferrer">
      {data.image && (
        <img className="dify-chat-ogp__image" src={data.image} alt="" loading="lazy" />
      )}
      <span className="dify-chat-ogp__body">
        <span className="dify-chat-ogp__title">{data.title || fallbackTitle || url}</span>
        {data.description && (
          <span className="dify-chat-ogp__description">{data.description}</span>
        )}
        <span className="dify-chat-ogp__host">
          <i className="fas fa-link" />
          {data.host}
        </span>
      </span>
    </a>
  )
}

export default OgpCard
