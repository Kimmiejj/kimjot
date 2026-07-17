'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  aggregateUsage,
  decodeFirestoreFields,
  githubReleaseDownloadUrl,
  githubReleaseTag,
  nextPatchVersion,
  parsePubspecVersion,
  replacePubspecVersion,
} = require('../lib/core');

test('parses and increments Flutter version', () => {
  const current = parsePubspecVersion('name: kimjod\nversion: 1.1.0+2\n');
  assert.deepEqual(nextPatchVersion(current), {
    versionName: '1.1.1',
    versionCode: 3,
  });
  assert.match(
    replacePubspecVersion('name: kimjod\nversion: 1.1.0+2\n', '1.2.0', 4),
    /version: 1\.2\.0\+4/,
  );
});

test('builds a stable GitHub Release APK URL', () => {
  assert.equal(githubReleaseTag('1.1.2', 5), 'android-v1.1.2-5');
  assert.equal(
    githubReleaseDownloadUrl('Kimmiejj/kimjot', '1.1.2', 5, 'kimjod-1.1.2-5.apk'),
    'https://github.com/Kimmiejj/kimjot/releases/download/android-v1.1.2-5/kimjod-1.1.2-5.apk',
  );
});

test('decodes Firestore REST values', () => {
  assert.deepEqual(
    decodeFirestoreFields({
      sessions: { integerValue: '4' },
      features: {
        mapValue: { fields: { scan: { integerValue: '2' } } },
      },
    }),
    { sessions: 4, features: { scan: 2 } },
  );
});

test('aggregates active users, sessions, features and versions', () => {
  const result = aggregateUsage(
    ['2026-07-16', '2026-07-17'],
    {
      '2026-07-16': [
        { uid: 'a', sessions: 2, versionName: '1.1.0', features: { home: 2 } },
      ],
      '2026-07-17': [
        { uid: 'a', sessions: 1, versionName: '1.1.0', features: { scan: 1 } },
        { uid: 'b', sessions: 1, versionName: '1.1.1', features: { home: 1 } },
      ],
    },
    [{ localId: 'a', createdAt: '1784210000000' }, { localId: 'b', createdAt: '1784290000000' }],
    [],
    {},
  );

  assert.equal(result.summary.totalUsers, 2);
  assert.equal(result.summary.activeToday, 2);
  assert.equal(result.summary.active30Days, 2);
  assert.equal(result.summary.sessions30Days, 4);
  assert.deepEqual(result.features, [
    { name: 'home', count: 3 },
    { name: 'scan', count: 1 },
  ]);
});
