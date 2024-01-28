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

const handleHamburgerClose = () => {
  document.querySelector('#main').onclick = () => {
    const checkbox = document.querySelector('#hamburger-checkbox');
    if (!checkbox.checked) {
      return;
    }
    checkbox.checked = false;
  }
}

document.addEventListener('DOMContentLoaded', () => {
  initEditorUpload();
  hideNotice();
  handleHamburgerClose();

  const textarea = document.querySelector('#editor textarea');

  if (textarea) {
    const formObserver = new FormObserver(textarea);
    document.querySelector('select[id$=_markup]').addEventListener('change', (event) => {
      formObserver.handleMarkupChange(event);
      initEditorUpload();
      formObserver.adjustTextareaHeight();
    }, false);
  }
});
