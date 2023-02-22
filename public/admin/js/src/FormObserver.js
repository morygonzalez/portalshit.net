import Quill from 'quill'
import FileUploader from './FileUploader'

class FormObserver {
  constructor(textarea) {
    this.textarea = textarea;
    this.selected = document.querySelector('select[id$=_markup] option:checked').value;
    this.previousMarkup;
    this.setupEditor();
    this.initializeFields();
    this.adjustTextareaHeight();
    this.observeSubmit();
    this.observePreview();
    this.observeTextInput();
    this.observeWindowResize();
    this.observeFieldsChange();
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

  async setupQuill() {
    const raw_body = document.querySelector('#editor textarea').value;
    const markup = this.previousMarkup;
    const preview_body = await this.getPreview({raw_body, markup});
    const previewTab = document.querySelector('ul.preview-edit');
    console.log(preview_body)
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
    this.quill.clipboard.dangerouslyPasteHTML(preview_body);
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

  adjustTextareaHeight() {
    const textarea = this.textarea;
    const editor = textarea.parentNode;
    if (editor.dataset.mobile === "true") {
      return;
    }
    const offset = parseInt(textarea.getBoundingClientRect().top * 1.1);
    let newHeight = document.documentElement.clientHeight - offset;
    editor.style.height = `${newHeight}px`;
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

  async getPreview({markup, raw_body}) {
    const ajaxData = new FormData();
    ajaxData.append('raw_body', raw_body);
    ajaxData.append('markup', markup);
    const request = await fetch('/admin/previews', {
      method: 'POST',
      body: ajaxData
    });
    const response = await request.json();
    return response.body;
  }

  observePreview() {
    let editor;
    const preview = document.querySelector('#preview');
    const markupSelect = document.querySelector('#post_markup, #page_markup');
    const previewRadio = document.querySelector('input[type="radio"][name="ipreview"][value="preview"]');
    const editRadio = document.querySelector('input[type="radio"][name="ipreview"][value="edit"]');
    markupSelect.addEventListener('change', (e) => {
      const selected = e.target.value;
      e.target.querySelectorAll('option').forEach((option) => {
        if (option.value == selected) {
          option.setAttribute('selected', 'selected');
        } else {
          this.previousMarkup = option.value;
          option.removeAttribute('selected');
        }
      })
    });
    editRadio.addEventListener('change', (e) => {
      editor = document.querySelector('#editor');
      e.srcElement.parentElement.classList.add('selected');
      previewRadio.parentElement.classList.remove('selected');
      preview.style.display = 'none';
      editor.style.display = 'block';
      preview.innerHTML = '';
    });
    previewRadio.addEventListener('change', async (e) => {
      editor = document.querySelector('#editor');
      e.srcElement.parentElement.classList.add('selected');
      editRadio.parentElement.classList.remove('selected');
      const textarea = document.querySelector('#editor textarea');
      const raw_body = textarea.value;
      const markup = document.querySelector('#post_markup option:checked, #page_markup option:checked').value || 'redcarpet';
      const preview_body = await this.getPreview({markup, raw_body});
      const iframe = document.createElement('iframe');
      preview.appendChild(iframe);
      const doc = iframe.contentWindow.document;
      const style = `<style>
img { max-width: 100%; }
img { height: auto; }
html, body {
  font-size: 16px;
  font-family: "Lucida Sans Unicode","Lucida Grande",Arial,Helvetica,"ヒラギノ角ゴ Pro W3",HiraKakuPro-W3,Osaka,sans-serif;
  word-wrap: break-word;
  margin: 0;
}
figure {
  margin: 0;
}
</style>`;
      const result = new Promise(resolve => resolve(iframe));
      const renderIframe = () => {
        doc.open();
        doc.write(style + preview_body);
        doc.close();
      }
      const resizeIframe = () => {
        iframe.style.width = '100%';
        iframe.style.height = iframe.contentWindow.document.body.scrollHeight + 'px';
      }
      result
        .then(renderIframe)
        .then(resizeIframe)
        .finally(setTimeout(resizeIframe, 300));
      editor.style.display = 'none';
      preview.style.display = 'block';
    });
  }

  observeTextInput() {
    this.textarea.addEventListener('input', () => {
      this.adjustTextareaHeight();
    })
  }

  observeWindowResize() {
    window.onresize = () => {
      this.adjustTextareaHeight();
    }
  }

  initializeFields() {
    const fields = Array.from(document.querySelectorAll('div.field'));
    for (const field of fields) {
      const inputElement = field.querySelector('input[type="text"], textarea, input[type="datetime-local"], select option:checked');
      if (inputElement === null) {
        continue;
      }
      field.dataset.serialize = JSON.stringify(inputElement.value);
    }
  }

  observeFieldsChange() {
    const fields = Array.from(document.querySelectorAll('div.field'));
    for (const field of fields) {
      const inputElement = field.querySelector('input[type="text"], textarea, input[type="datetime-local"], select');
      if (inputElement === null) {
        continue;
      }
      inputElement.addEventListener('input', () => {
        if (field.dataset.serialize != JSON.stringify(inputElement.value)) {
          inputElement.dataset.changed = 'true';
          field.classList.add('edited');
        } else {
          inputElement.dataset.changed = 'false';
          field.classList.remove('edited');
        }
      })
    }
  }
}

export default FormObserver
