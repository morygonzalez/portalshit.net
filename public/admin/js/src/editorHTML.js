import DOMPurify from 'dompurify'

const sanitizerOptions = {
  USE_PROFILES: { html: true },
  FORBID_TAGS: ['iframe', 'style'],
  FORBID_ATTR: ['contenteditable']
};

export function sanitizeEditorHTML(html) {
  return DOMPurify.sanitize(html, sanitizerOptions);
}

export function serializeEditorHTML(root) {
  const copy = root.cloneNode(true);
  const document = copy.ownerDocument;

  copy.querySelectorAll('.ql-ui, .ql-cursor').forEach(node => node.remove());
  copy.querySelectorAll('ol').forEach(list => {
    let group;
    let previousType;
    for (const item of Array.from(list.children)) {
      const type = item.getAttribute('data-list');
      if (!group || type !== previousType) {
        group = document.createElement(type && type !== 'ordered' ? 'ul' : 'ol');
        if (type === 'checked' || type === 'unchecked') {
          group.setAttribute('data-checked', String(type === 'checked'));
        }
        list.before(group);
        previousType = type;
      }
      item.removeAttribute('data-list');
      group.append(item);
    }
    list.remove();
  });

  copy.querySelectorAll('.ql-code-block-container').forEach(container => {
    const pre = document.createElement('pre');
    pre.className = 'ql-syntax';
    pre.textContent = Array.from(container.children, line => line.textContent).join('\n') + '\n';
    container.replaceWith(pre);
  });

  const clean = document.createElement('div');
  clean.append(DOMPurify.sanitize(copy, { ...sanitizerOptions, RETURN_DOM_FRAGMENT: true }));
  for (const pre of clean.querySelectorAll('pre')) {
    // HTML parsers skip the first newline immediately after a pre start tag.
    if (pre.textContent.startsWith('\n')) pre.prepend('\n');
  }
  return clean.firstElementChild.innerHTML;
}
