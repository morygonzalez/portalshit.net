document.body.addEventListener "AutoPagerize_DOMNodeInserted", (e) ->
  node       = e.target
  requestURL = e.newValue
  parentNode = e.relatedNode
  init node
, false

fitImageWidthToScreenWidth = ->
  $('.body img').each ->
    maxWidth    = 900
    deviceWidth = document.body.offsetWidth
    if window.orientation == 0
      deviceWidth -= 160
    else
      deviceWidth -= 60
    imageRatio  = @naturalHeight / @naturalWidth
    maxWidth    = if deviceWidth > maxWidth then maxWidth else deviceWidth

    if @naturalWidth > maxWidth
      @width  = maxWidth
      @height = maxWidth * imageRatio

init = (node) ->
  fitImageWidthToScreenWidth()

window.onload = fitImageWidthToScreenWidth
