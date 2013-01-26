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
  $('.body img').each(function() {
    var maxWidth    = 900;
    var deviceWidth = document.body.offsetWidth - 60;
    var imageRatio  = this.naturalHeight / this.naturalWidth;
    maxWidth        = deviceWidth > maxWidth ? maxWidth : deviceWidth;

    if (this.naturalWidth > maxWidth) {
      this.width  = maxWidth;
      this.height = maxWidth * imageRatio;
    }
  });
};
