class FormObserver {
  constructor(textarea) {
    this.textarea = textarea;
    this.selected = document.querySelector('select#post_markup option:checked').value;
    this.setupEditor();
    this.observeSubmit();
  }

  setupEditor() {
    if (this.selected === 'html' || this.selected === '') {
      this.setupQuill();
    } else {
      this.setupTextarea();
    }
  }

  handleMarkupChange(event) {
    if (event.target.querySelector('option:checked').value === 'html') {
      this.setupQuill();
    } else {
      this.setupTextarea();
    }
  }

  setupQuill() {
    const content = document.querySelector('#editor textarea').value;
    this.quill = new Quill('#editor', {
      modules: {
        toolbar:[
          [{ header: [3, 4, false] }],
          ['bold', 'link'],
          [{ list: 'ordered' }, { list: 'bullet' }],
          ['image', 'code-block']
        ]
      },
      theme: 'snow'
    });
    this.quill.clipboard.dangerouslyPasteHTML(content);
    this.quill.getModule('toolbar').addHandler('image', () => {
      this.selectLocalImage();
    });
  }

  setupTextarea() {
    const textarea = this.textarea;
    this.quill = Quill.find(document.querySelector('#editor'));
    if (this.quill) {
      const label = document.querySelector('label[for="post_body"]');
      const qlToolbar = document.querySelector('.ql-toolbar');
      const qlContainer = document.querySelector('.ql-container');
      const content = this.quill.root.innerHTML;
      textarea.value = content;
      qlContainer.remove();
      qlToolbar.remove();
      const editor = document.createElement('div');
      editor.setAttribute('id', 'editor');
      editor.appendChild(textarea);
      label.parentNode.insertBefore(editor, label.nextSibling);
    }
  }

  selectLocalImage() {
    const editor = document.querySelector('#editor');
    const input = document.createElement('input');
    input.setAttribute('type', 'file');
    input.click();

    // Listen upload local image and save to server
    input.onchange = () => {
      const file = input.files[0];
      // file type is only image.
      if (/^image\//.test(file.type)) {
        const uploader = new FileUploader(editor);
        uploader.upload(file).then((response) => {
          const range = this.quill.getSelection();
          this.quill.insertEmbed(range.index, 'image', response.url);
        });
      } else {
        console.warn('You could only upload images.');
      }
    };
  }

  observeSubmit() {
    const form = document.querySelector('#main form');
    form.onsubmit = () => {
      this.setupTextarea();
    }
  }
}

class FileUploader {
  constructor(editor) {
    this.editor = editor;
    this.markupSelector = document.querySelector('#post_markup');
    this.observeDragAndDrop();
  };

  isAvailable() {
    const div = document.createElement('div');
    return (('draggable' in div) || ('ondragstart' in div && 'ondrop' in div)) && 'FormData' in window && 'FileReader' in window;
  };

  observeDragAndDrop() {
    const editor = this.editor;
    const self = this;

    if (!this.isAvailable()) {
      console.log("Drag and Drop upload is not available on this Browser");
      return false;
    }

    const eventsToIgnore      = ['drag', 'dragstart', 'dragend', 'dragover', 'dragenter', 'dragleave', 'drop'];
    const eventsToAddClass    = ['drag', 'dragstart', 'dragover', 'dragenter'];
    const eventsToRemoveClass = ['dragleave', 'dragend', 'drop'];

    eventsToIgnore.forEach((event) => {
      editor.addEventListener(event, (e) => {
        e.preventDefault();
        e.stopPropagation();
      });
    });
    eventsToAddClass.forEach((event) => {
      editor.addEventListener(event, (e) => {
        editor.classList.add('is-dragover');
      });
    });
    eventsToRemoveClass.forEach((event) => {
      editor.addEventListener(event, (e) => {
        editor.classList.remove('is-dragover');
      });
    });
    editor.addEventListener('drop', (e) => {
      let droppedFiles = e.dataTransfer.files;
      if (droppedFiles) {
        for (let file of droppedFiles) {
          self.upload(file);
        }
        droppedFiles = null;
      }
    });
  };

  upload(file) {
    const editor = this.editor;
    const textarea = editor.querySelector('textarea');
    const ajaxData = new FormData();
    const self = this;
    ajaxData.append('file', file);
    let promise = new Promise((resolve, reject) => {
      let xhr = new XMLHttpRequest();
      let response;
      xhr.open('POST', '/admin/attachments');
      xhr.onreadystatechange = () => {
        if (xhr.readyState != 4) {
          editor.classList.add('is-uploading');
          if (textarea) {
            textarea.setAttribute('disabled', true);
          }
        } else if (xhr.status != 201) {
          response = JSON.parse(xhr.response);
          editor.classList.add('is-error');
          reject(response);
        } else {
          response = JSON.parse(xhr.response);
          editor.classList.add('is-success');
          resolve(response);
        }
      }
      xhr.send(ajaxData);
    });
    promise.then((response) => {
      console.log(response.message);
      editor.classList.remove('is-uploading');
      if (textarea) {
        textarea.removeAttribute('disabled');
        const imageTag = self.detectImageTag(file, response.url);
        self.insertImage(imageTag);
      }
    }).catch((response) => {
      if (textarea) {
        textarea.removeAttribute('disabled');
        console.error(response.message);
      }
    });
    return promise;
  };

  insertImage(imageTag) {
    const textarea = this.editor.querySelector('textarea');

    if (!textarea) {
      return;
    }

    if (textarea.value.length === 0) {
      textarea.value = imageTag;
    } else if (textarea.selectionStart > 0) {
      textarea.value = textarea.value.substr(0, textarea.selectionStart).trim() +
        "\n\n" + imageTag + "\n\n" +
        textarea.value.substr(textarea.selectionStart, textarea.value.length - 1).trim();
    } else {
      textarea.value = imageTag + "\n\n" + textarea.value.trim();
    }
  };

  detectImageTag(file, url) {
    let imageTag;
    const markup = document.querySelector('#post_markup option:checked').value;
    switch (markup) {
      case 'kramdown':
      case 'redcarpet':
        imageTag = '![' + file.name + '](' + url + ')';
        break;
      case 'redcloth':
        imageTag = '!' + url + '!';
        break;
      case 'html':
      case 'wikicloth':
      default:
        imageTag = '<img src="' + url + '" alt="' + file.name + '" />';
        break;
    }
    return imageTag;
  };
}

document.addEventListener('DOMContentLoaded', () => {
  const editor = document.querySelector('#editor');
  if (editor) {
    new FileUploader(editor);
  }

  const textarea = document.querySelector('#editor textarea');
  if (textarea) {
    const formObserver = new FormObserver(textarea);
    document.querySelector('#post_markup').addEventListener('change', (event) => {
      formObserver.handleMarkupChange(event);
    }, false);
  }
});
