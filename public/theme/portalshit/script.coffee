document.body.addEventListener "AutoPagerize_DOMNodeInserted", (e) ->
  node       = e.target
  requestURL = e.newValue
  parentNode = e.relatedNode
  init node
, false

init = (node) ->

window.onload = init()
