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
      var eventsToAddClass    = ['dragover', 'dragenter'];
      var eventsToRemoveClass = ['dragleave', 'dragend', 'drop'];
      eventsToIgnore.forEach(function(event) {
        editor.addEventListener(event, function(e) {
          e.preventDefault();
          e.stopPropagation();
        })
      });
      eventsToAddClass.forEach(function(event) {
        $(editor).addClass('is-dragover');
      });
      eventsToRemoveClass.forEach(function(event) {
        $(editor).removeClass('is-dragover');
      });
      editor.addEventListener('drop', function(e) {
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
                  $(editor).addClass('is-uploading');
                } else if (xhr.status != 201) {
                  // 失敗
                  response = JSON.parse(xhr.response);
                  $(editor).addClass('is-error');
                  reject(response);
                } else {
                  // 取得成功
                  response = JSON.parse(xhr.response);
                  $(editor).addClass('is-success');
                  resolve(response);
                }
              }
              xhr.send(ajaxData);
            });
            promise.then(function(response) {
              console.log(response.message);
              var textarea = editor.querySelector('textarea');
              var delimiter = '';
              if (textarea.value.length > 0)
                delimiter = "\n\n";
              textarea.value = textarea.value + delimiter + '![' + file.name + '](' + response.url + ')';
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
