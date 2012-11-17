(function() {
  var init = function(node) {
    $(node).find(".body > pre, blockquote > pre").each(function() {
      var self = this;
      var lexer = $(this).attr('class');
      $.ajax({
        type: 'POST',
        url: '/pygmentize',
        data: { snippet: $(self).text(), lexer: lexer }
      }).done(function(data) {
        $(self).replaceWith(data);
      });
    });
  }

  document.body.addEventListener('AutoPagerize_DOMNodeInserted',function(evt){
    var node = evt.target;
    var requestURL = evt.newValue;
    var parentNode = evt.relatedNode;
    init(node);
  }, false);

  init(document);
})();
