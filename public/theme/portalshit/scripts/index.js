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

$(function() {
  if ($(window).width() <= 640) {
    $('#footer aside dt').on('click', function() {
      $(this).siblings('dd').slideToggle();
    });
  }
});
