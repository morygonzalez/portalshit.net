'use strict';

document.addEventListener('DOMContentLoaded', function() {
  const regexp = /(?:ISBN|ASIN)=([0-9A-Z]+)/g;
  const COMMENT_NODE = 8;
  let bodies = document.querySelectorAll('div.body');
  bodies.forEach(function(body) {
    body.childNodes.forEach(function(node) {
      if (node.nodeType !== COMMENT_NODE)
        return;
      if (!node.textContent.match(regexp))
        return;
      let itemId = RegExp.$1;
      let url = `/amazon/${itemId}.html`;
      let request = new XMLHttpRequest();
      request.responseType = 'html';
      let promise = new Promise(function(resolve, reject) {
        request.open('GET', url);
        request.onreadystatechange = function() {
          if (request.readyState != 4) {
            // リクエスト中
          } else if (request.status != 200) {
            // 失敗
            reject(request.response);
          } else {
            // 取得成功
            let result = request.response;
            resolve(result);
          }
        };
        request.send();
      });
      promise.then(function(result) {
        let previous = node.previousSibling;
        let parent = node.parentNode;
        let d = document.createElement('div');
        d.innerHTML = result;
        d.querySelectorAll('a').forEach(function(item) {
          item.onclick = function(e) {
            let productTitle = item.textContent || item.title;
            if (typeof ga !== 'undefined') {
              ga('send', 'event', 'Amazon Affiliate', 'click', productTitle);
            }
          };
        });
        parent.insertBefore(d, previous.nextSibling);
      }).catch(function(error) {
        console.log(error);
      });
      return promise;
    });
  });
});
