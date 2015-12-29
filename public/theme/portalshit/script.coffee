document.body.addEventListener "AutoPagerize_DOMNodeInserted", (e) ->
  node       = e.target
  requestURL = e.newValue
  parentNode = e.relatedNode
  init node
, false

init = (node) ->

window.onload = init()

$ ->
  if $(window).width() <= 640
    $('#aside dt').on 'click', ->
      $(this).siblings('dd').slideToggle()
  $('.amazon a').on 'click', ->
    productTitle = $(@).text()
    ga('send', 'event', 'Amazon Affiliate', 'click', productTitle)
