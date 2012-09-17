(function() {
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
