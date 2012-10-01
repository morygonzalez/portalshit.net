(function() {
  var target = $('.archives li').slice(7);
  target.each(function() {
    $(this).css("display", "none");
  })

  $('#show_more_archive_list').click(function() {
    target.each(function() {
      $(this).slideDown();
    })

    $(this).hide();
    $('#show_less_archive_list').show();
  })

  $('#show_less_archive_list').click(function() {
    target.each(function() {
      $(this).slideUp();
    })

    $(this).hide();
    $('#show_more_archive_list').show();
  })

  var init = function(node) {
    /*
    $(node).find(".body > pre").each(function() {
      var self = this;
      $.ajax({
        type: 'POST',
        url: '/pygmentize',
        data: { snippet: $(self).text(), lexar: '' }
      }).done(function(data) {
        $(self).replaceWith(data);
      });
    });

    $('.body').each(function() {

      var Pygmentize = function(lexar, snippet) {
        var result;

        $.ajax({
          type: 'POST',
          url: '/pygmentize',
          async: false,
          data: {
            lexar: lexar,
            snippet: snippet
          },
        }).done(function(data) {
          result = data;
        });

        return result;
      }

      var entryBody = $(this).text();

      entryBody = entryBody.replace(/```(.+?)\n([\s\S]*?)```/g,
        function(whole, lexar, snippet) {
          return Pygmentize(lexar, snippet);
        }
      );

      $(this).html(entryBody);
    })
    */
  }

  document.body.addEventListener('AutoPagerize_DOMNodeInserted',function(evt){
    var node = evt.target;
    var requestURL = evt.newValue;
    var parentNode = evt.relatedNode;
    init(node);
  }, false);

  init(document);
})();
