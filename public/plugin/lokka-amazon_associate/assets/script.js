'use strict';

document.addEventListener('DOMContentLoaded', function() {
  const regexp = /(?:ISBN|ASIN)=([0-9A-Z]+)/g;
  const COMMENT_NODE = 8;
  let bodies = document.querySelectorAll('div.body');
  bodies.forEach(function(body, index) {
    body.childNodes.forEach(function(node, index) {
      if (node.nodeType !== COMMENT_NODE)
        return;
      if (!node.textContent.match(regexp))
        return;
      let itemId = RegExp.$1;
      let url = '/amazon/' + itemId + '.json';
      let request = new XMLHttpRequest();
      request.responseType = 'json';
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
            let formatter = new Formatter(request.response);
            let result = formatter.formatItem();
            resolve(result);
          }
        };
        request.send();
      });
      promise.then(function(result) {
        let previous = node.previousSibling;
        let parent = node.parentNode;
        let d = document.createElement('div');
        d.className = 'amazon';
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

var Formatter = (function() {
  function Formatter(json) {
    this.json = json;
    this.itemId = json['ItemLookupResponse']['OperationRequest']['Arguments']['Argument'].find(function(argument) {
      return(argument['Name'] === 'ItemId');
    })['Value'];
    this.errors = json['ItemLookupResponse']['Items']['Request']['Errors'];
    if (typeof this.errors === 'undefined' || this.errors === null) {
      this.attributes = json['ItemLookupResponse']['Items']['Item']['ItemAttributes']
      this.title = this.attributes['Title'];
    } else {
      console.error(this.errors);
      return;
    }
  }

  Formatter.prototype.formatItem = function() {
    if (this.errors) {
      return '<pre>Item ' + this.itemId + ' Not Found</pre>';
    }
    let json = this.json;
    let item, attr, title, link, image, imageSet, price, author, manufacturer, str;
    item = json['ItemLookupResponse']['Items']['Item'];
    attr = item['ItemAttributes'];
    title = attr['Title'];
    link = item['DetailPageURL'];
    imageSet = item['ImageSets'] ? item['ImageSets']['ImageSet'] : false;
    if (item['LargeImage']) {
      image = item['LargeImage'];
    } else if (imageSet && imageSet.length > 1) {
      image = item['ImageSets']['ImageSet'];
    } else if (imageSet && imageSet.length == 1) {
      image = imageSet['LargeImage'];
    } else {
      image = { 'URL': '/plugin/lokka-amazon_associate/assets/no-image.png' };
    }
    try {
      price = item['OfferSummary']['LowestNewPrice']['FormattedPrice'];
    }
    catch(e) {
      price = '-';
    }

    let authors = [];
    if (typeof attr['Creator'] !== 'undefined' && attr['Creator'] !== null)
      authors .push(this.formatAuthors(attr['Creator']));
    if (typeof attr['Author'] !== 'undefined' && attr['Author'] !== null)
      authors .push(this.formatAuthors(attr['Author']));
    if (typeof attr['Director'] !== 'undefined' && attr['Director'] !== null)
      authors .push(this.formatAuthors(attr['Director']));
    if (typeof attr['Actor'] !== 'undefined' && attr['Actor'] !== null)
      authors .push(this.formatAuthors(attr['Actor']));
    if (typeof attr['Artist'] !== 'undefined' && attr['Artist'] !== null)
      authors .push(this.formatAuthors(attr['Artist']));

    if (typeof authors !== 'undefined' && authors !== null) {
      author = authors.join(', ');
    }
    manufacturer = attr['Manufacturer'] || attr['Format'];

    str = '<div class="amazon-image">' +
      '<a href="' + link + '" title="' + title  + '">' +
      this.imageTag(image) +
      '</a>' +
      '</div>' +
      '<div class="amazon-content">' +
      '<ul>' +
      '<li><a href="' + link + '" title="' + title + '">' + title + '</a></li>';
    if (author !== '') {
      str += '<li>' + author + '</li>';
    }
    str += '<li>' + manufacturer + '</li>' +
      '<li>' + price + '</li>' +
      '</ul>' +
      '</div>';
    return str;
  };

  Formatter.prototype.formatAuthors = function(authors) {
    if (authors instanceof Array && authors.length > 1) {
      let _authors = [];
      authors.forEach(function(item, index) {
        _authors.push(item)
      });
      authors = _authors.join(', ');
    }
    return authors;
  };

  Formatter.prototype.imageTag = function(image) {
    let title = this.title;
    if (image instanceof Array && image.length > 1) {
      image = image[0]['LargeImage'];
    }
    return '<img src="' + image['URL'] + '" alt="' + title + '" />';
  }

  return Formatter;
})();
