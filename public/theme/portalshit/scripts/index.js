document.addEventListener("DOMContentLoaded", () => {
  const checkImageSize = (target) => {
    if (typeof target === 'undefined') {
      return;
    }
    const width = target.naturalWidth;
    const height = target.naturalHeight;
    const isPhoto = RegExp('(lh3\.googleusercontent\.com|\.jpe?g$)').test(target.src);
    if (width > 1279 && width > height && isPhoto) {
      target.classList.add('large');
    }
  }

  const lazyImageObserver = new IntersectionObserver((entries, observer) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const lazyImage = entry.target;
        lazyImage.src = lazyImage.dataset.src;
        // lazyImage.srcset = lazyImage.dataset.srcset;
        // lazyImage.classList.remove("lazy");
        lazyImage.addEventListener('load', (event) => checkImageSize(event.target));
        lazyImageObserver.unobserve(lazyImage);
      }
    });
  });

  const selectors = "#content article .body img, #content article .similar img";
  const lazyImages = [].slice.call(document.querySelectorAll(selectors));

  if ("IntersectionObserver" in window) {
    for (let image of lazyImages) {
      const src = image.src;
      image.dataset.src = src;
      if (lazyImages.indexOf(image) === 0) {
        const promise = new Promise(resolve => resolve(image));
        promise.then(checkImageSize).catch(setTimeout(checkImageSize, 100))
        continue;
      }
      image.src = "";
    };

    lazyImages.forEach(lazyImage => {
      lazyImageObserver.observe(lazyImage);
    });
  } else {
    // Possibly fall back to a more compatible method here
  }
});

document.body.addEventListener("AutoPagerize_DOMNodeInserted", (e) => {
    const node       = e.target
    const requestURL = e.newValue
    const parentNode = e.relatedNode
    init(node);
  }, false
);

$(() => {
  if ($(window).width() <= 640) {
    $('#footer aside dt').on('click', (event) => {
      $(event.target).siblings('dd').slideToggle();
    });
  }
});
