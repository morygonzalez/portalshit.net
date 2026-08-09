import React, { useEffect, useMemo, useRef } from 'react'
import { marked, Parser } from 'marked'
import DOMPurify from 'dompurify'
import OgpCard from './OgpCard'

// ナレッジベースの各記事チャンクには
// "Title: <記事タイトル>" / "URL: <記事URL>" が埋め込まれている
// (lib/dify/article_formatter.rb#compose_article_block 参照)。
// 引用元からこの対応関係を取り出し、本文中の裸URLを記事タイトルのリンクに差し替える。
const extractLinkInfo = (citation) => {
  const content = citation.content || ''
  const urlMatch = content.match(/^URL:\s*(\S+)/m)
  if (!urlMatch) return null

  const titleMatch = content.match(/^Title:\s*(.+)$/m)
  const title = (titleMatch && titleMatch[1].trim()) || citation.document_name
  if (!title) return null

  return { url: urlMatch[1], title }
}

const buildLinkTitleMap = (citations) => {
  const map = {}
  ;(citations || []).forEach((citation) => {
    const info = extractLinkInfo(citation)
    if (info) map[info.url] = info.title
  })
  return map
}

const escapeAttr = (value) => String(value).replace(/&/g, '&amp;').replace(/"/g, '&quot;')

const buildRenderer = (linkTitleMap) => {
  const renderer = new marked.Renderer()
  renderer.link = function link({ href, title, tokens }) {
    const isBareUrl = tokens?.length === 1 && tokens[0].type === 'text' && tokens[0].text === href
    const label = isBareUrl && linkTitleMap[href]
      ? linkTitleMap[href]
      : this.parser.parseInline(tokens)
    const titleAttr = title ? ` title="${escapeAttr(title)}"` : ''
    return `<a href="${escapeAttr(href)}"${titleAttr} target="_blank" rel="noopener noreferrer"><i class="fas fa-link"></i>${label}</a>`
  }
  return renderer
}

// 段落の inline トークン列を br (改行) 単位の「行」に分割する。
// `breaks: true` では単一改行は新しい段落ではなく同一段落内の <br> になるため、
// 「文章の次の行にリンクだけがある」ケースも段落単位の判定では拾えない。
const splitIntoLines = (inlineTokens) => {
  const lines = [[]]
  inlineTokens.forEach((token) => {
    if (token.type === 'br') {
      lines.push([])
    } else {
      lines[lines.length - 1].push(token)
    }
  })
  return lines
}

// 行がリンク1つだけで構成されているか判定する
// (ブログ本文の Lokka::OGP::Replacer と同じ「単独リンク行 → OGPカード」ルール)
// 裸URL (https://...) だけでなく [タイトル](url) 形式のリンクも対象にする
const isStandaloneLinkLine = (line) => line.length === 1 && line[0].type === 'link'

// メッセージ本文を「通常のMarkdown HTML」と「OGPカード」のセグメント列に分割する
const buildSegments = (text, linkTitleMap) => {
  const blockTokens = marked.lexer(text || '', { breaks: true, gfm: true })
  const renderer = buildRenderer(linkTitleMap)
  const segments = []
  let htmlParts = []
  let pLines = []

  const closeParagraph = () => {
    if (pLines.length === 0) return
    htmlParts.push(`<p>${pLines.join('<br>')}</p>`)
    pLines = []
  }

  const flushHtml = () => {
    closeParagraph()
    if (htmlParts.length === 0) return
    segments.push({ type: 'html', html: DOMPurify.sanitize(htmlParts.join('')) })
    htmlParts = []
  }

  blockTokens.forEach((token) => {
    if (token.type !== 'paragraph') {
      closeParagraph()
      htmlParts.push(marked.parser([token], { renderer }))
      return
    }

    splitIntoLines(token.tokens).forEach((line) => {
      if (line.length === 0) return

      if (isStandaloneLinkLine(line)) {
        const link = line[0]
        flushHtml()
        segments.push({
          type: 'ogp',
          url: link.href,
          fallbackTitle: linkTitleMap[link.href] || link.tokens?.[0]?.text
        })
      } else {
        pLines.push(Parser.parseInline(line, { renderer }))
      }
    })
    closeParagraph()
  })
  flushHtml()

  return segments
}

const Message = ({ message }) => {
  const linkTitleMap = useMemo(() => buildLinkTitleMap(message.citations), [message.citations])
  const citationLinks = useMemo(
    () => (message.citations || []).map(extractLinkInfo).filter(Boolean),
    [message.citations]
  )
  const segments = useMemo(
    () => buildSegments(message.content, linkTitleMap),
    [message.content, linkTitleMap]
  )

  if (message.role === 'user') {
    return <div className="dify-chat-message dify-chat-message--user">{message.content}</div>
  }

  return (
    <div className="dify-chat-message dify-chat-message--assistant">
      <div className="dify-chat-message__body">
        {segments.map((segment, index) => (
          segment.type === 'ogp'
            ? <OgpCard key={index} url={segment.url} fallbackTitle={segment.fallbackTitle} />
            : <div key={index} dangerouslySetInnerHTML={{ __html: segment.html }} />
        ))}
      </div>
      {message.pending && !message.content && (
        <div className="dify-chat-message__typing" aria-label="応答を生成中">
          <span />
          <span />
          <span />
        </div>
      )}
      {message.error && (
        <div className="dify-chat-message__error">{message.error}</div>
      )}
      {citationLinks.length > 0 && (
        <ul className="dify-chat-message__citations">
          {citationLinks.map((link, index) => (
            <li key={index}>
              <a href={link.url} target="_blank" rel="noopener noreferrer">
                <i className="fas fa-link" />
                {link.title}
              </a>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

const MessageList = ({ messages }) => {
  const endRef = useRef(null)

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' })
  }, [messages])

  return (
    <div className="dify-chat-messages">
      {messages.map((message) => (
        <Message key={message.id} message={message} />
      ))}
      <div ref={endRef} />
    </div>
  )
}

export default MessageList
