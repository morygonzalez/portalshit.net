'use strict';

document.addEventListener('DOMContentLoaded', function() {
  var bodies = document.querySelectorAll('div.body');
  bodies.forEach(function(body, index) {
    var regexp = /<!--\s(?:ISBN|ASIN)=([0-9A-Z]+?)\s-->/g;
    var matches = body.innerHTML.match(regexp)
    matches.forEach(function(tag, index) {
      var itemId = tag.replace(regexp, function() { return RegExp.$1 });
      var url = '/amazon/' + itemId + '.json';
      var request = new XMLHttpRequest();
      request.responseType = 'json';
      var promise = new Promise(function(resolve, reject) {
        request.open('GET', url);
        request.onreadystatechange = function() {
          if (request.readyState != 4) {
            // リクエスト中
          } else if (request.status != 200) {
            // 失敗
            reject(request.response);
          } else {
            // 取得成功
            var response = JSON.parse(request.response);
            var formatter = new Formatter(response);
            var result = formatter.formatItem();
            resolve(result);
          }
        };
        request.send();
      });
      promise.then(function(result) {
        var replaceRegexp = new RegExp('<!--\\s(ISBN|ASIN)=' + itemId + '\\s-->');
        body.innerHTML = body.innerHTML.replace(replaceRegexp, result);
        return true;
      });
      return promise;
    });
  });
});

var Formatter = (function() {
  function Formatter(json) {
    this.json = json;
  }

  Formatter.prototype.formatItem = function() {
    var json = this.json;
    var item, attr, title, link, image, price, author, manufacturer, str;
    var errors = json["ItemLookupResponse"]["Items"]["Request"]["Errors"];
    if (typeof errors !== "undefined" && errors !== null) {
      return errors;
    }
    item = json["ItemLookupResponse"]["Items"]["Item"];
    attr = item["ItemAttributes"];
    title = attr["Title"];
    link  = item["DetailPageURL"];
    image = item["MediumImage"]["URL"].replace('http://ecx.images-amazon', 'https://images-na.ssl-images-amazon');
    try {
      price = item["OfferSummary"]["LowestNewPrice"]["FormattedPrice"];
    }
    catch(e) {
      price = "-";
    }

    var authors = [];
    if (typeof attr["Creator"] !== "undefined" && attr["Creator"] !== null)
      authors << this.formatAuthors(attr["Creator"]);
    if (typeof attr["Author"] !== "undefined" && attr["Author"] !== null)
      authors << this.formatAuthors(attr["Author"]);
    if (typeof attr["Director"] !== "undefined" && attr["Director"] !== null)
      authors << this.formatAuthors(attr["Director"]);
    if (typeof attr["Actor"] !== "undefined" && attr["Actor"] !== null)
      authors << this.formatAuthors(attr["Actor"]);
    if (typeof attr["Artist"] !== "undefined" && attr["Artist"] !== null)
      authors << this.formatAuthors(attr["Artist"]);

    if (typeof authors !== "undefined" && authors !== null) {
      author = authors.join(", ");
    }
    manufacturer = attr["Manufacturer"];

    str = '<div class="amazon">' +
            '<div class="amazon-image">' +
              '<a href="' + link + '"><img src="' + image + '" alt="' + title + '" /></a>' +
            '</div>' +
            '<div class="amazon-content">' +
              '<ul>' +
                '<li><a href="' + link + '">' + title + '</a></li>' +
                '<li>' + author + '</li>' +
                '<li>' + manufacturer + '</li>' +
                '<li>' + price + '</li>' +
              '</ul>' +
            '</div>' +
          '</div>';
    return str;
  };

  Formatter.prototype.formatAuthors = function(authors) {
    if (typeof authors === Array && authors.length > 1) {
      var _authors = [];
      authors.forEach(function(item, index) {
        _authors.push(item)
      });
      authors = _authors.join(', ');
    }
    return authors;
  };

  return Formatter;
})();
