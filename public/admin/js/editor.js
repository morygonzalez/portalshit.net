$(function() {
  var wysiwyg;
  var textarea = $('textarea.editor').clone();
  var plainTextareaMode;

  var switchTextareaAndWysiwyg = (function() {
    var name = $('select[name$="[markup]"] option:selected').val();
    name = name == '' ? 'kramdown' : name;
    $('select[name$="[markup]"] option[value$="' + name + '"]').attr("selected", "selected");
    var html;
    if (name == 'html') {
      // enable wysiwyg
      if (plainTextareaMode) {
        textarea = $('textarea.editor').clone();
        translateToWysiwyg($('textarea.editor'));
        plainTextareaMode = false;
      }
    } else {
      // enable textarea
      if (!plainTextareaMode) {
        html = wysiwyg[0].contentDocument.body.innerHTML;
        textarea[0].innerHTML = html;
        $('#editor').empty();
        $('#editor').prepend(textarea);
        plainTextareaMode = true;
      }
    }
  });

  var translateToWysiwyg = (function(jQueryObj) {
    jQueryObj.wysiwyg({
      controls: {
        h1:          { visible: false },
        html:        { visible: true },
        indent:      { visible: false },
        outdent:     { visible: false },
        paragraph:   { visible: true },
        redo:        { visible: false },
        subscript:   { visible: false },
        superscript: { visible: false },
        underline:   { visible: false },
        undo:        { visible: false }
      },
      autoGrow: true,
      css: '/admin/css/editor.css'
    });
    $('.toolbar ~ div[style*="clear: both;"]').css({ clear: 'none' }); // style patch
    wysiwyg = $('.wysiwyg iframe');
  });

  $('select[name$="[markup]"]').change(switchTextareaAndWysiwyg);

  plainTextareaMode = true;

  switchTextareaAndWysiwyg();

  var isAdvancedUpload = function() {
    var div = document.createElement('div');
    return (('draggable' in div) || ('ondragstart' in div && 'ondrop' in div)) && 'FormData' in window && 'FileReader' in window;
  }();

  var dragAndDropUpload = function() {
    var editor = document.querySelector('#editor');

    if (isAdvancedUpload) {
      var eventsToIgnore      = ['drag', 'dragstart', 'dragend', 'dragover', 'dragenter', 'dragleave', 'drop'];
      var eventsToAddClass    = ['drag', 'dragstart', 'dragover', 'dragenter'];
      var eventsToRemoveClass = ['dragleave', 'dragend', 'drop'];
      eventsToIgnore.forEach(function(event) {
        editor.addEventListener(event, function(e) {
          e.preventDefault();
          e.stopPropagation();
        });
      });
      eventsToAddClass.forEach(function(event) {
        editor.addEventListener(event, function(e) {
          editor.classList.add('is-dragover');
        });
      });
      eventsToRemoveClass.forEach(function(event) {
        editor.addEventListener(event, function(e) {
          editor.classList.remove('is-dragover');
        });
      });
      editor.addEventListener('drop', function(e) {
        var textarea = editor.querySelector('textarea');
        var ajaxData = new FormData();
        var droppedFiles = e.dataTransfer.files;
        if (droppedFiles) {
          for (var file of droppedFiles) {
            ajaxData.append('file', file);
            var promise = new Promise(function(resolve, reject) {
              var xhr = new XMLHttpRequest();
              var response;
              xhr.open('POST', '/admin/attachments');
              xhr.onreadystatechange = function() {
                if (xhr.readyState != 4) {
                  // リクエスト中
                  editor.classList.add('is-uploading');
                  textarea.setAttribute('disabled', true);
                } else if (xhr.status != 201) {
                  // 失敗
                  response = JSON.parse(xhr.response);
                  editor.classList.add('is-error');
                  reject(response);
                } else {
                  // 取得成功
                  response = JSON.parse(xhr.response);
                  editor.classList.add('is-success');
                  resolve(response);
                }
              }
              xhr.send(ajaxData);
            });
            promise.then(function(response) {
              console.log(response.message);
              editor.classList.remove('is-uploading');
              textarea.removeAttribute('disabled');
              var imageFormat = '![' + file.name + '](' + response.url + ')';
              if (textarea.value.length === 0) {
                textarea.value = imageFormat;
              } else if (textarea.selectionStart > 0) {
                textarea.value = textarea.value.substr(0, textarea.selectionStart).trim() +
                  "\n\n" + imageFormat + "\n\n" +
                  textarea.value.substr(textarea.selectionStart, textarea.value.length - 1).trim();
              } else (textarea.selectionStart) {
                textarea.value = imageFormat + "\n\n" + textarea.value.trim();
              }
            }).catch(function(error) {
              console.error(error);
            });
            return promise;
          }
          droppedFiles = null;
        }
      });
    }
  };

  dragAndDropUpload();
});
