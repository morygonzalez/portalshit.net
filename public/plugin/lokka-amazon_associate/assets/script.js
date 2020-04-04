'use strict';

document.addEventListener('DOMContentLoaded', () => {
  const regexp = /(?:ISBN|ASIN)=([0-9A-Z]+)/g;
  const COMMENT_NODE = 8;
  const bodies = document.querySelectorAll('article > .body');
  bodies.forEach(body => {
    body.childNodes.forEach(async node => {
      if (node.nodeType !== COMMENT_NODE)
        return;
      if (!node.textContent.match(regexp))
        return;
      const itemId = RegExp.$1;
      const url = `/amazon/${itemId}.html`;
      const request = await fetch(url);
      const response = await request.text();
      const previous = node.previousSibling;
      const parent = node.parentNode;
      const d = document.createElement('div');
      d.innerHTML = response;
      d.querySelectorAll('a').forEach(item => {
        item.onclick = (e) => {
          const target = e.target.tagName === 'IMG' ? e.target.parentNode : e.target;
          const productTitle = target.dataset.productTitle;
          let eventType;
          switch (target.className) {
            case 'title':
              eventType = 'title click';
              break;
            case 'price':
              eventType = 'price click';
              break;
            case 'button':
              eventType = 'button click';
              break;
            case 'image':
              eventType = 'image click';
              break;
            default:
              eventType = 'unknown click';
              break;
          }
          if (typeof ga !== 'undefined') {
            ga('send', 'event', 'Amazon Affiliate', eventType, productTitle);
          }
        };
      });
      parent.insertBefore(d, previous.nextSibling);
    });
  });
});
