export function captureTime(value) {
  // EXIF の日付と ISO 形式を扱う。時差のない値はサーバー同様に日本時間。
  const normalized = String(value || '').trim().replace(/^(\d{4}):(\d{2}):(\d{2})/, '$1-$2-$3');
  const match = normalized.match(/^(\d{4}-\d{2}-\d{2})(?:[T ](\d{2}:\d{2}:\d{2}(?:\.\d+)?))?(?:\s*(Z|[+-]\d{2}:?\d{2}))?$/);
  if (!match) return null;

  const time = match[2] || '00:00:00';
  const local = new Date(`${match[1]}T${time}Z`);
  // Date.parse が 2 月 30 日などを翌月に補正するのを防ぐ。
  if (Number.isNaN(local.getTime()) || local.toISOString().slice(0, 19) !== `${match[1]}T${time.slice(0, 8)}`) return null;
  const zone = (match[3] || '+09:00').replace(/^([+-]\d{2})(\d{2})$/, '$1:$2');
  const timestamp = Date.parse(`${match[1]}T${time}${zone}`);
  return Number.isNaN(timestamp) ? null : timestamp;
}

export default function sortImages(images, sortBy = 'filename') {
  return images.map((image, index) => ({ image, index, time: captureTime(image.taken_at) }))
    .sort((a, b) => {
      if (sortBy === 'taken_at') {
        if (a.time === null && b.time !== null) return 1;
        if (a.time !== null && b.time === null) return -1;
        if (a.time !== null && b.time !== null && a.time !== b.time) return a.time - b.time;
      }
      return String(a.image.filename).localeCompare(String(b.image.filename), undefined, { numeric: true }) || a.index - b.index;
    }).map(item => item.image);
}
