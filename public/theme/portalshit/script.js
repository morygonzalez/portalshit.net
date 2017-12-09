document.body.addEventListener(
  "AutoPagerize_DOMNodeInserted",
  function(e) {
    let node       = e.target
    let requestURL = e.newValue
    let parentNode = e.relatedNode
    init(node);
  },
  false
);

init = function(node) { }

window.onload = init();

$(function() {
  if ($(window).width() <= 640) {
    $('#aside dt').on('click', function() {
      $(this).siblings('dd').slideToggle();
    });
  }
});