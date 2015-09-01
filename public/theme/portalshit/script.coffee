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

  if $('.archive-by-month').length > 0
    categories = $('.category a').map -> $(@).text()
    categories = categories.toArray()
    categories = categories.filter (element, index, self) ->
      self.indexOf(element) == index
    ul = $('<ul>', id: 'categories')
    $('ul.year-list').after(ul)
    for category in categories
      html = """
      <li><a href="javascript:void(0)" data-category-name="#{category}">#{category}</a></li>
      """
      $(html).appendTo(ul)

    $('#categories li a').on('click', ->
      $articles = $('li.year ul li')
      if $(@).hasClass('clicked')
        $(@).removeClass('clicked')
        $articles.show()
      else
        $('#categories li a').removeClass('clicked')
        $(@).addClass('clicked')
        $articles.hide()
        categoryName = $(@).data('category-name')
        for element in $('.category a')
          if $(element).text() == categoryName
            $(element).closest('li').show()
    )
