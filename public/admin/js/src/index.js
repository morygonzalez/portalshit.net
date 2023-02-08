import FormObserver from './FormObserver'
import FileUploader from './FileUploader'

let editor;

const initEditorUpload = () => {
  editor = document.querySelector('#editor');
  if (editor) {
    new FileUploader(editor);
  }
}

const hideNotice = () => {
  const notice = document.querySelector('#notice');
  if (notice) {
    setTimeout(() => { notice.style.display = 'none' }, 3000);
  }
}

const adjustTextareaHeight = () => {
  const textarea = document.querySelector('#main form textarea');
  const editor = document.querySelector('#editor');
  const offset = parseInt(textarea.getBoundingClientRect().top * 1.1);
  let newHeight = document.documentElement.clientHeight - offset;
  editor.style.height = `${newHeight}px`;
}

window.onresize = adjustTextareaHeight;

document.addEventListener('DOMContentLoaded', () => {
  initEditorUpload();
  hideNotice();
  adjustTextareaHeight();

  const textarea = document.querySelector('#editor textarea');
  textarea.addEventListener('input', adjustTextareaHeight)

  if (textarea) {
    const formObserver = new FormObserver(textarea);
    document.querySelector('select[id$=_markup]').addEventListener('change', (event) => {
      formObserver.handleMarkupChange(event);
      initEditorUpload();
    }, false);
  }
});
