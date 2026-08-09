import React from 'react'

const SuggestedQuestions = ({ questions, onSelect }) => {
  if (!questions || questions.length === 0) return null

  return (
    <div className="dify-chat-suggested">
      {questions.map((question, index) => (
        <button
          key={index}
          type="button"
          className="dify-chat-suggested__item"
          onClick={() => onSelect(question)}
        >
          {question}
        </button>
      ))}
    </div>
  )
}

export default SuggestedQuestions
