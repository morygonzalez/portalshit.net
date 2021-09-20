import mediumZoom from 'medium-zoom';

const checkTableWidth = node => {
  node.querySelectorAll('table').forEach(target => {
    if (needToExpand(target)) {
      target.classList.add('wide');
    }
  })
}

const needToExpand = table => {
  return Array.from(table.rows).some(rows => {
    return rows.children.length > 6 || Array.from(rows.children).some(td => {
      return td.innerText.length > 20;
    });
  })
}

const checkImageSize = target => {
  if (typeof target === 'undefined') {
    return false;
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

const observeImages = node => {
  const selectors = '#content article .body img, #content aside .similar img';
  const lazyImages = [].slice.call(node.querySelectorAll(selectors));

  if ('IntersectionObserver' in window) {
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
}

const getCurrentColorMode = () => {
  const allCookies = document.cookie.split(';');
  const colorPreference = allCookies.find(item => item.startsWith('prefers-color-scheme'));
  let mode;

  if (colorPreference) {
    mode = colorPreference.split('=')[1];
  } else if (window.matchMedia('(prefers-color-scheme: light)').matches) {
    mode = 'light-mode';
  } else {
    mode = 'dark-mode';
  }

  return mode;
}

const observeThemeToggle = () => {
  const button = document.querySelector('#toggle-theme');
  if (button) {
    button.onclick = toggleColorPreference;
  }
}

const toggleColorPreference = () => {
  const currentColorMode = getCurrentColorMode();
  let newColorMode;
  if (currentColorMode == 'dark-mode') {
    newColorMode = 'light-mode';
  } else {
    newColorMode = 'dark-mode';
  }
  document.cookie = `prefers-color-scheme=${newColorMode};max-age=604800;path=/`;
  document.documentElement.classList.remove(currentColorMode);
  document.documentElement.classList.add(newColorMode);
}

const observeColorMode = () => {
  window.matchMedia('(prefers-color-scheme: light)').addEventListener('change', ()  => {
    const allCookies = document.cookie.split(';');
    const colorPreference = allCookies.find(item => item.startsWith('prefers-color-scheme'));
    if (colorPreference) {
      return;
    }
    let mode;
    if (e.matches) {
      mode = 'light-mode';
    } else {
      mode = 'dark-mode';
    }
    document.documentElement.classList.add(mode);
  })
}

const setColorMode = async () => {
  const currentColorMode = await getCurrentColorMode();
  document.documentElement.classList.add(currentColorMode);
}

const observeLinkClick = (node) => {
  const selectors = 'section.referrers ul li a, section.similar ul li a, section.frequently-read-articles ul li a, section.hotentry ul li a';
  node.querySelectorAll(selectors).forEach(element => {
    element.onclick = (e) => {
      const target = e.target;
      const item = target.closest('li.item');
      const type = item.getAttribute('type');
      const category = type.match(/hotentry|frequency/) ? 'Popular Entry' : 'Related Entry';
      const action = `${type} click`;
      const label = item.getAttribute('title');
      if (typeof ga !== 'undefined') {
        ga('send', 'event', category, action, label);
      }
    }
  })
}

const init = node => {
  // setColorMode();
  observeImages(node);
  observeLinkClick(node);
  mediumZoom('figure img', { background: 'rgba(33, 33, 33, 0.8)' });
  observeThemeToggle();
  observeColorMode();
  checkTableWidth(node);
}

document.addEventListener('DOMContentLoaded', () => init(document));
document.body.addEventListener('AutoPagerize_DOMNodeInserted', (e) => {
  const node       = e.target
  const requestURL = e.newValue
  const parentNode = e.relatedNode
  init(node);
}, false);

$(() => {
  if ($(window).width() <= 640) {
    $('#footer aside dt').on('click', (event) => {
      $(event.target).siblings('dd').slideToggle();
    });
  }
});
