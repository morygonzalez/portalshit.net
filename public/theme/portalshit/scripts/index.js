document.addEventListener("DOMContentLoaded", function() {
  let selectors = "#content article .body img, #content article .similar img";
  var lazyImages = [].slice.call(document.querySelectorAll(selectors));

  if ("IntersectionObserver" in window) {
    for (let image of lazyImages) {
      let src = image.src;
      image.dataset.src = src;
      image.src = "";
    };

    let lazyImageObserver = new IntersectionObserver(function(entries, observer) {
      entries.forEach(function(entry) {
        if (entry.isIntersecting) {
          let lazyImage = entry.target;
          lazyImage.src = lazyImage.dataset.src;
          // lazyImage.srcset = lazyImage.dataset.srcset;
          // lazyImage.classList.remove("lazy");
          lazyImageObserver.unobserve(lazyImage);
        }
      });
    });

    lazyImages.forEach(function(lazyImage) {
      lazyImageObserver.observe(lazyImage);
    });
  } else {
    // Possibly fall back to a more compatible method here
  }
});

document.body.addEventListener("AutoPagerize_DOMNodeInserted", function(e) {
    let node       = e.target
    let requestURL = e.newValue
    let parentNode = e.relatedNode
    init(node);
  }, false
);

$(function() {
  if ($(window).width() <= 640) {
    $('#footer aside dt').on('click', function() {
      $(this).siblings('dd').slideToggle();
    });
  }
});
