(function() {
  var init = function(node) {
    $(node).find("pre").attr("class", "prettyprint");
    prettyPrint();
  }

  document.body.addEventListener('AutoPagerize_DOMNodeInserted',function(evt){
    var node = evt.target;
    var requestURL = evt.newValue;
    var parentNode = evt.relatedNode;
    init(node);
  }, false);

  init(document);
})();
