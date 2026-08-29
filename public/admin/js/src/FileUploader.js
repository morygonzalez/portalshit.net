class FileUploader {
  constructor(editor) {
    this.editor = editor;
    this.observeDragAndDrop();
    this.observeFilePicker();
  };

  isAvailable() {
    const div = document.createElement('div');
    return (('draggable' in div) || ('ondragstart' in div && 'ondrop' in div)) && 'FormData' in window && 'FileReader' in window;
  };

  observeDragAndDrop() {
    const editor = this.editor;
    const self = this;

    if (editor.dataset.uploadObserved) {
      console.log("The editor is already observed by FileUploader");
      return;
    }

    if (!this.isAvailable()) {
      console.log("Drag and Drop upload is not available on this Browser");
      return false;
    }

    const eventsToIgnore       = ['drag', 'dragstart', 'dragend', 'dragover', 'dragenter', 'dragleave', 'drop'];
    const eventsToAddClass     = ['drag', 'dragstart', 'dragover', 'dragenter'];
    const eventsToRemoveClass  = ['dragleave', 'dragend', 'drop'];
    const eventsToHandleUpload = ['drop', 'paste'];

    eventsToIgnore.forEach(event => {
      editor.addEventListener(event, (e) => {
        e.preventDefault();
        e.stopPropagation();
      });
    });
    eventsToAddClass.forEach(event => {
      editor.addEventListener(event, (e) => {
        editor.classList.add('is-dragover');
      });
    });
    eventsToRemoveClass.forEach(event => {
      editor.addEventListener(event, (e) => {
        editor.classList.remove('is-dragover');
      });
    });
    eventsToHandleUpload.forEach(event => {
      editor.addEventListener(event, (e) => {
        let source, droppedItems;
        if (event === 'paste') {
          source = e.clipboardData;
        } else {
          source = e.dataTransfer;
        }
        if (!source.types.some(type => type === 'Files')) {
          return;
        }
        droppedItems = source.items;
        let needLineBreak;
        for (const index in droppedItems) {
          const item = droppedItems[index];
          if (item.kind === 'file' && item.type.match('^image/')) {
            const file = droppedItems[index].getAsFile();
            needLineBreak = index !== droppedItems.length;
            if (file && /^image\//.test(file.type)) {
              self.upload(file, needLineBreak);
            }
          }
        }
        droppedItems = null;
        e.preventDefault();
      });
    });

    this.editor.dataset.uploadObserved = true;
  };

  observeFilePicker() {
    const input = document.querySelector('.image-picker__input');
    if (!input) {
      return;
    }

    // addEventListener ではなく代入にしているのは、markup 切り替えのたびに
    // FileUploader が再生成されても、この永続的な input に古いリスナーを
    // 積み重ねず、常に最新の editor を対象にするため。
    input.onchange = () => {
      this.uploadFiles(Array.from(input.files));
      input.value = '';
    };
  };

  async uploadFiles(files) {
    const images = files.filter(file => /^image\//.test(file.type));
    if (images.length === 0) {
      return;
    }

    const status = document.querySelector('.image-picker__status');
    for (const [index, file] of images.entries()) {
      if (status) {
        status.textContent = `アップロード中… (${index + 1}/${images.length})`;
      }
      const needLineBreak = index !== images.length - 1;
      try {
        await this.upload(file, needLineBreak);
      } catch (error) {
        if (status) {
          status.textContent = `アップロードに失敗しました: ${file.name}`;
        }
        return;
      }
    }
    if (status) {
      status.textContent = `${images.length}枚アップロードしました`;
      setTimeout(() => { status.textContent = ''; }, 3000);
    }
  };

  async upload(file, needLineBreak) {
    const editor = this.editor;
    const textarea = editor.querySelector('textarea');
    const ajaxData = new FormData();
    ajaxData.append('file', file);

    editor.classList.remove('is-success', 'is-error');
    if (textarea) {
      editor.classList.add('is-uploading');
      textarea.setAttribute('disabled', true);
    }

    try {
      const response = await fetch('/admin/attachments', {
        method: 'POST',
        body: ajaxData
      });
      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.message || 'Upload failed');
      }
      console.log(data.message);
      editor.classList.add('is-success');
      if (textarea) {
        const imageTag = this.detectImageTag(file, data.url);
        this.insertImage(imageTag, needLineBreak);
      }
      return data;
    } catch (error) {
      editor.classList.add('is-error');
      console.error(error.message);
      throw error;
    } finally {
      editor.classList.remove('is-uploading');
      if (textarea) {
        textarea.removeAttribute('disabled');
      }
    }
  };

  insertImage(imageTag, needLineBreak) {
    const textarea = this.editor.querySelector('textarea');

    if (!textarea) {
      return;
    }

    let beforeSelect = textarea.value.substr(0, textarea.selectionStart);
    let afterSelect = textarea.value.substr(textarea.selectionStart, textarea.value.length - 1);
    if (needLineBreak) {
      textarea.value = `${beforeSelect}${imageTag}\n${afterSelect}`;
    } else {
      textarea.value = `${beforeSelect}${imageTag}${afterSelect}`;
    }
    let position = textarea.value.indexOf(afterSelect);
    textarea.setSelectionRange(position, position);
  };

  detectImageTag(file, url) {
    let imageTag;
    const markup = document.querySelector('select[id$=_markup] option:checked').value;
    const fileName = file.name.replace(/\.(jpe?g|png|gif)/, "");
    switch (markup) {
      case 'kramdown':
      case 'redcarpet':
        imageTag = '![' + fileName + '](' + url + ')';
        break;
      case 'redcloth':
        imageTag = '!' + url + '!';
        break;
      case 'html':
      case 'wikicloth':
      default:
        imageTag = '<img src="' + url + '" alt="' + fileName + '" />';
        break;
    }
    return imageTag;
  };
}

export default FileUploader
