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
    // fit image for iPhone
    /* if (navigator.userAgent.match(/iPad/)) { */
    /* } */
  }

  document.body.addEventListener('AutoPagerize_DOMNodeInserted',function(evt){
    var node = evt.target;
    var requestURL = evt.newValue;
    var parentNode = evt.relatedNode;
    init(node);
  }, false);

  init(document);
})();

window.onload = function() {
  $('.article img').each(function() {
    var newWidth    = document.body.offsetWidth - 60;
    var imageRatio  = this.naturalHeight / this.naturalWidth;

    if (this.naturalWidth > newWidth) {
      this.width  = newWidth;
      this.height = newWidth * imageRatio;
    }
  });
};
