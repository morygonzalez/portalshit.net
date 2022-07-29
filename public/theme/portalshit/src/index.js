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

const initThemeMenu = () => {
  const button = document.querySelector('.theme button');
  const modal = document.querySelector('.theme-menu');
  const allCookies = document.cookie.split(';');
  const colorPreference = allCookies.find(item => item.startsWith('prefers-color-scheme'));
  let selectedMode, selectedTheme, selectedThemeIcon;

  if (colorPreference) {
    selectedMode = colorPreference.split('=')[1];
    selectedTheme = selectedMode === 'light-mode' ? 'Light' : 'Dark';
    selectedThemeIcon = selectedTheme === 'Light' ? 'sun' : 'moon';
    button.innerHTML = `<i class="far fa-${selectedThemeIcon}"></i><span>Theme</span>`;
  } else {
    selectedTheme = 'OS Default';
    selectedThemeIcon = 'adjust';
    button.innerHTML = '<i class="fas fa-adjust"></i><span>Theme</span>';
  }

  if (selectedTheme === 'Light') {
    modal.querySelector('button.theme-light').parentNode.classList.add('selected');
  } else if (selectedTheme === 'Dark') {
    modal.querySelector('button.theme-dark').parentNode.classList.add('selected');
  } else {
    modal.querySelector('button.theme-default').parentNode.classList.add('selected');
  }
}

const observeThemeMenu = () => {
  const button = document.querySelector('.theme button');
  const modal = document.querySelector('.theme-menu');

  initThemeMenu();

  if (button) {
    button.onclick = () => {
      modal.style.display = 'block';
    }

    document.body.onclick = () => {
      modal.style.display = 'none';
    }

    document.querySelector('.theme').onclick = (event) => {
      event.stopPropagation();
    }
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

const observeThemeSelect = () => {
  const buttons = document.querySelectorAll('.theme-button');
  const modal = document.querySelector('.theme-menu');

  if (buttons.length > 0) {
    buttons.forEach(button => {
      button.onclick = () => {
        let newColorMode;
        if (button.classList.contains('theme-light')) {
          newColorMode = 'light-mode';
        } else if (button.classList.contains('theme-dark')) {
          newColorMode = 'dark-mode';
        } else {
          newColorMode = null;
        }
        changeTheme(newColorMode);
        modal.style.display = 'none';
        modal.querySelectorAll('li').forEach(item => { item.classList.remove('selected') });
        initThemeMenu();
      }
    })
  }
}

const changeTheme = (newColorMode) => {
  const currentColorMode = getCurrentColorMode();
  document.documentElement.classList.remove(currentColorMode);

  if (newColorMode) {
    document.cookie = `prefers-color-scheme=${newColorMode};max-age=604800;path=/`;
    document.documentElement.classList.add(newColorMode);
  } else {
    document.cookie = `prefers-color-scheme=;max-age=0;path=/`;
    fallBackToDefaultTheme();
  }
}

const fallBackToDefaultTheme = () => {
  const newColorMode = getCurrentColorMode();
  document.documentElement.classList.add(newColorMode);
}

const observeColorMode = () => {
  window.matchMedia('(prefers-color-scheme: light)').addEventListener('change', (e)  => {
    const allCookies = document.cookie.split(';');
    const colorPreference = allCookies.find(item => item.startsWith('prefers-color-scheme'));
    if (colorPreference) {
      return;
    }
    let newColorMode;
    const colorModes = ['light-mode', 'dark-mode'];
    if (e.matches) {
      newColorMode = 'light-mode';
    } else {
      newColorMode = 'dark-mode';
    }
    const currentColorMode = colorModes.find(item => item != newColorMode);
    document.documentElement.classList.remove(currentColorMode);
    document.documentElement.classList.add(mode);
  })
}

const setColorMode = () => {
  const currentColorMode = getCurrentColorMode();
  document.documentElement.classList.add(currentColorMode);
}

const observeSearchMenu = () => {
  const searchForm = document.querySelector('#search_form');

  document.querySelector('#global-nav ul li.search span').onclick = () => {
    searchForm.style.display = 'block';
  }
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
  observeThemeMenu();
  observeThemeSelect();
  setColorMode();
  observeImages(node);
  observeLinkClick(node);
  mediumZoom('figure img', { background: 'rgba(33, 33, 33, 0.8)' });
  observeColorMode();
  checkTableWidth(node);
  observeSearchMenu();
}

document.addEventListener('DOMContentLoaded', () => init(document));
document.body.addEventListener('AutoPagerize_DOMNodeInserted', (e) => {
  const node       = e.target
  const requestURL = e.newValue
  const parentNode = e.relatedNode
  init(node);
}, false);
