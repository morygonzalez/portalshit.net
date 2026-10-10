const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { test } = require('node:test');

// 本番は webpack が ES Modules を読み込む。テストでは追加の変換ツールを使わない。
const source = fs.readFileSync(path.join(__dirname, '../src/PhotoGalleryOrdering.js'), 'utf8');
const ordering = import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
const photos = [
  { filename: 'Album 10.jpg', taken_at: '2020:01:01 10:00:00' },
  { filename: 'Album 2.jpg', taken_at: '2022-01-01' },
  { filename: 'Album 1.jpg', taken_at: '2021-01-01' }
];

test('filename order is the default and leaves the source unchanged', async () => {
  const { default: sortImages } = await ordering;
  assert.deepEqual(sortImages(photos).map(image => image.filename), ['Album 1.jpg', 'Album 2.jpg', 'Album 10.jpg']);
  assert.equal(photos[0].filename, 'Album 10.jpg');
});

test('capture time order is oldest first', async () => {
  const { default: sortImages } = await ordering;
  assert.deepEqual(sortImages(photos, 'taken_at').map(image => image.filename), ['Album 10.jpg', 'Album 1.jpg', 'Album 2.jpg']);
});

test('EXIF and ISO dates are equivalent, with Japan time as the default', async () => {
  const { captureTime } = await ordering;
  const expected = captureTime('2025:02:01 10:00:00');
  for (const value of ['2025-02-01 10:00:00 +0900', '2025-02-01T10:00:00+09:00', '2025-02-01T01:00:00Z']) {
    assert.equal(captureTime(value), expected);
  }
  assert.equal(captureTime('2025-02-01'), captureTime('2025:02:01 00:00:00'));
  for (const value of ['2025-02-30', '2025:02:01 24:00:00', '2025:02:01 10:00:60', '', null, 'invalid']) {
    assert.equal(captureTime(value), null);
  }
});

test('equal times and unknown times use numeric filename order, unknown times last', async () => {
  const { default: sortImages } = await ordering;
  const images = [
    { filename: '10.jpg', taken_at: '2025:02:01 10:00:00' },
    { filename: '2.jpg', taken_at: '2025-02-01T01:00:00Z' },
    { filename: '3.jpg', taken_at: '2025-02-30' },
    { filename: '1.jpg', taken_at: null }
  ];
  assert.deepEqual(sortImages(images, 'taken_at').map(image => image.filename), ['2.jpg', '10.jpg', '1.jpg', '3.jpg']);
});
