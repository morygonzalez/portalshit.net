$ ->
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
      $monthTitles = $('li.year h3')
      if $(@).hasClass('clicked')
        $(@).removeClass('clicked')
        $articles.show()
        $monthTitles.show()
      else
        $('#categories li a').removeClass('clicked')
        $(@).addClass('clicked')
        $articles.hide()
        $monthTitles.hide()
        categoryName = $(@).data('category-name')
        for element in $('.category a')
          if $(element).text() == categoryName
            $(element).closest('li').show()
        for elem in $('li.year ul')
          if $(elem).find('li:visible').length > 0
            $(elem).find('li:visible').parent().parent().find('h3').show()
    )
