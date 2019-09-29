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
    $('#aside dt').on('click', function() {
      $(this).siblings('dd').slideToggle();
    });
  }
});

(() => {
  const images = [
    'black-kite',
    'container-ship',
    'daytime-aso',
    'evening-aso',
    'evening-moon',
    'fire',
    'halo',
    'heimin',
    'jizou',
    'karatsu',
    'momiji',
    'moss',
    'nagatare',
    'nanzenji',
    'night-moon',
    'wave',
  ];

  const image = images[Math.floor(Math.random() * images.length)];
  const imageUrl = `https://resources.portalshit.net/theme-images/header-bg-${image}.jpg`;
  document.querySelector('#header').style.backgroundImage = `linear-gradient(to top, rgba(33,33,33,0.80), transparent, transparent), url("${imageUrl}")`;
})();
