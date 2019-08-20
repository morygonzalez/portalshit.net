import Quill from 'quill'
import FileUploader from './FileUploader'

class FormObserver {
  constructor(textarea) {
    this.textarea = textarea;
    this.selected = document.querySelector('select[id$=_markup] option:checked').value;
    this.setupEditor();
    this.observeSubmit();
    this.observePreview();
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
    const previewTab = document.querySelector('ul.preview-edit');
    previewTab.style.display = 'none';
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
    const previewTab = document.querySelector('ul.preview-edit');
    previewTab.style.display = 'block';
    this.quill = Quill.find(document.querySelector('#editor'));
    if (this.quill) {
      const qlToolbar = document.querySelector('.ql-toolbar');
      const qlContainer = document.querySelector('.ql-container');
      const content = this.quill.root.innerHTML;
      textarea.value = content;
      qlContainer.remove();
      qlToolbar.remove();
      const editor = document.createElement('div');
      editor.setAttribute('id', 'editor');
      editor.appendChild(textarea);
      previewTab.parentNode.insertBefore(editor, previewTab.nextSibling);
    }
  }

  selectLocalImage() {
    const editor = document.querySelector('#editor');
    const input = document.createElement('input');
    input.setAttribute('type', 'file');
    input.setAttribute('accept', 'image/*');
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

  observePreview() {
    let editor;
    const preview = document.querySelector('#preview');
    const previewRadio = document.querySelector('input[type="radio"][name="ipreview"][value="preview"]');
    const editRadio = document.querySelector('input[type="radio"][name="ipreview"][value="edit"]');
    editRadio.addEventListener('change', (e) => {
      editor = document.querySelector('#editor');
      e.srcElement.parentElement.classList.add('selected');
      previewRadio.parentElement.classList.remove('selected');
      preview.style.display = 'none';
      editor.style.display = 'block';
      preview.innerHTML = '';
    });
    previewRadio.addEventListener('change', (e) => {
      editor = document.querySelector('#editor');
      e.srcElement.parentElement.classList.add('selected');
      editRadio.parentElement.classList.remove('selected');
      const textarea = document.querySelector('#editor textarea');
      const body = textarea.value;
      const markup = document.querySelector('#post_markup option[selected="selected"]').value;
      const self = this;
      const ajaxData = new FormData();
      ajaxData.append('raw_body', body);
      ajaxData.append('markup', markup);
      let promise = new Promise((resolve, reject) => {
        let xhr = new XMLHttpRequest();
        let response;
        xhr.open('POST', '/admin/previews');
        xhr.onreadystatechange = () => {
          if (xhr.readyState != 4) {
            // waiting response
          } else if (xhr.status != 201) {
            response = JSON.parse(xhr.response);
            reject(response);
          } else {
            response = JSON.parse(xhr.response);
            resolve(response);
          }
        }
        xhr.send(ajaxData);
      });
      promise.then(response => {
        const iframe = document.createElement('iframe');
        preview.appendChild(iframe);
        const doc = iframe.contentWindow.document;
        const style = `<style>
          img { max-width: 100%; }
          html, body {
            font-size: 16px;
            font-family: "Lucida Sans Unicode","Lucida Grande",Arial,Helvetica,"ヒラギノ角ゴ Pro W3",HiraKakuPro-W3,Osaka,sans-serif;
            word-wrap: break-word;
          }
        </style>`;
        const result = new Promise(resolve => { resolve(iframe) });
        const renderIframe = () => {
          doc.open();
          doc.write(style);
          doc.write(response.body);
          doc.close();
        }
        const resizeIframe = () => {
          iframe.style.width = '100%';
          iframe.style.height = iframe.contentWindow.document.body.scrollHeight + 'px';
        }
        result.then(renderIframe).then(resizeIframe);
        editor.style.display = 'none';
        preview.style.display = 'block';
      }).catch(response => {
        console.error(response.message);
      });
    });
  }
}

export default FormObserver
