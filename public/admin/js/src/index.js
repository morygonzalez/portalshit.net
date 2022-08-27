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

document.addEventListener('DOMContentLoaded', () => {
  initEditorUpload();
  hideNotice();

  const textarea = document.querySelector('#editor textarea');
  if (textarea) {
    const formObserver = new FormObserver(textarea);
    document.querySelector('select[id$=_markup]').addEventListener('change', (event) => {
      formObserver.handleMarkupChange(event);
      initEditorUpload();
    }, false);
  }
});
