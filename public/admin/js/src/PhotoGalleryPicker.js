// Photo Gallery 用の一括アップロード。FileUploader が 1 枚ずつ即座に本文へ
// 挿入するのに対し、こちらは全枚数をためてレビューさせ、まとめて 1 つの
// ギャラリーブロックとして挿入する。
class PhotoGalleryPicker {
  constructor(editor) {
    this.editor = editor;
    this.images = [];
    this.coverId = null;
    this.root = document.querySelector('.photo-gallery-picker');
    if (!this.root) {
      return;
    }
    this.status = this.root.querySelector('.photo-gallery-picker__status');
    this.panel = document.querySelector('.gallery-review');
    this.list = this.panel && this.panel.querySelector('.gallery-review__list');
    this.observeFilePicker();
    this.observePanel();
  }

  observeFilePicker() {
    const input = this.root.querySelector('.photo-gallery-picker__input');
    if (!input) {
      return;
    }

    // FileUploader と同じ理由で addEventListener ではなく代入にしている。
    input.onchange = () => {
      this.collect(Array.from(input.files));
      input.value = '';
    };
  }

  observePanel() {
    if (!this.panel) {
      return;
    }

    this.panel.querySelector('.gallery-review__insert').onclick = () => this.insert();
    this.panel.querySelector('.gallery-review__cancel').onclick = () => this.close();
  }

  async collect(files) {
    const images = files.filter(file => /^image\//.test(file.type));
    if (images.length === 0) {
      return;
    }

    this.images = [];
    this.coverId = null;

    for (const [index, file] of images.entries()) {
      this.setStatus(`処理中… (${index + 1}/${images.length})`);
      try {
        this.images.push(await this.upload(file));
      } catch (error) {
        this.setStatus(`失敗しました: ${file.name} (${error.message})`);
        return;
      }
    }

    this.setStatus('');
    this.images.sort((a, b) => String(a.taken_at).localeCompare(String(b.taken_at)));
    this.coverId = this.images[0].s3_filename;
    this.open();
  }

  async upload(file) {
    const formData = new FormData();
    formData.append('file', file);
    const response = await fetch('/admin/photo_gallery/photos', {
      method: 'POST',
      body: formData
    });
    const data = await response.json();
    if (!response.ok) {
      throw new Error(data.message || 'Upload failed');
    }
    return data;
  }

  open() {
    this.renderList();
    this.panel.hidden = false;
  }

  close() {
    this.panel.hidden = true;
    this.images = [];
    this.coverId = null;
  }

  renderList() {
    this.list.textContent = '';

    this.images.forEach((image) => {
      const item = document.createElement('li');
      item.className = 'gallery-review__item';

      const thumb = document.createElement('img');
      thumb.className = 'gallery-review__thumb';
      thumb.src = image.thumb_url;
      thumb.alt = image.filename;

      const title = document.createElement('input');
      title.type = 'text';
      title.className = 'gallery-review__title';
      title.placeholder = 'タイトル';
      title.value = image.title || '';
      title.oninput = () => {
        image.title = title.value;
        image.alt = title.value;
      };

      const coverLabel = document.createElement('label');
      coverLabel.className = 'gallery-review__cover-label';
      const cover = document.createElement('input');
      cover.type = 'radio';
      cover.name = 'gallery-review-cover';
      cover.checked = image.s3_filename === this.coverId;
      cover.onchange = () => { this.coverId = image.s3_filename; };
      coverLabel.appendChild(cover);
      coverLabel.appendChild(document.createTextNode('カバー'));

      item.appendChild(thumb);
      item.appendChild(title);
      item.appendChild(coverLabel);
      this.list.appendChild(item);
    });
  }

  async insert() {
    this.setStatus('ギャラリーを生成中…');
    const formData = new FormData();
    formData.append('images', JSON.stringify(this.images));
    formData.append('cover_id', this.coverId || '');

    try {
      const response = await fetch('/admin/photo_gallery/render', {
        method: 'POST',
        body: formData
      });
      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.message || 'Render failed');
      }
      this.insertIntoTextarea(data.body);
      this.setStatus(`${this.images.length}枚のギャラリーを挿入しました`);
      setTimeout(() => this.setStatus(''), 3000);
      this.close();
    } catch (error) {
      this.setStatus(`生成に失敗しました: ${error.message}`);
    }
  }

  insertIntoTextarea(html) {
    const textarea = this.editor.querySelector('textarea');
    if (!textarea) {
      return;
    }

    const before = textarea.value.substring(0, textarea.selectionStart);
    const after = textarea.value.substring(textarea.selectionStart);
    textarea.value = `${before}\n${html}\n${after}`;
    const position = before.length + html.length + 2;
    textarea.setSelectionRange(position, position);
    textarea.dispatchEvent(new Event('input', { bubbles: true }));
  }

  setStatus(text) {
    if (this.status) {
      this.status.textContent = text;
    }
  }
}

export default PhotoGalleryPicker
