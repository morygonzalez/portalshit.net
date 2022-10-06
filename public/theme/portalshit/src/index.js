import mediumZoom from 'medium-zoom';
import React from 'react'
import { createRoot } from 'react-dom/client'

import SearchApp from './search'
import ThemeObserver from './theme-observer'

const container = document.getElementById('search_form');
const root = createRoot(container);
root.render(<SearchApp />);

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

const observeCloseModal = () => {
  document.documentElement.onclick = () => {
    document.querySelectorAll('.modal.active').forEach(modal => {
      modal.classList.toggle('active');
    })
  }

  document.querySelectorAll('.modal').forEach(modal => {
    modal.parentNode.onclick = (event) => {
      event.stopPropagation();
    }
  })
}

const observeSearchMenu = () => {
  const searchFormModal = document.querySelector('#search_form');

  document.querySelector('#global-nav ul li.search button').onclick = () => {
    document.querySelectorAll('.modal.active').forEach(modal => modal.classList.toggle('active'));
    searchFormModal.classList.toggle('active');
    searchFormModal.querySelector('input').focus();
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
  observeImages(node);
  mediumZoom('figure img', { background: 'rgba(33, 33, 33, 0.8)' });
  checkTableWidth(node);
  new ThemeObserver();
  observeSearchMenu();
  observeLinkClick(node);
  observeCloseModal();
}

document.addEventListener('DOMContentLoaded', () => init(document));
document.body.addEventListener('AutoPagerize_DOMNodeInserted', (e) => {
  const node       = e.target
  const requestURL = e.newValue
  const parentNode = e.relatedNode
  init(node);
}, false);
