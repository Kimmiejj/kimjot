'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  aggregateAiUsage,
  aggregateUsage,
  decodeFirestoreFields,
  githubReleaseDownloadUrl,
  githubReleaseTag,
  nextPatchVersion,
  parsePubspecVersion,
  replacePubspecVersion,
  splitReleaseRetention,
} = require('../lib/core');

test('aggregates Gemini requests, tokens, reliability and dimensions', () => {
  const result = aggregateAiUsage(
    ['2026-07-16', '2026-07-17'],
    [
      {
        uid: 'a', day: '2026-07-16', count: 2, successCount: 2,
        inputTokens: 120, outputTokens: 30, totalLatencyMs: 800, latencySamples: 2,
        models: { 'gemini-fast': 2 }, routes: { chat: 2 },
      },
      {
        uid: 'b', day: '2026-07-17', count: 2, successCount: 1, failureCount: 1,
        inputTokens: 90, outputTokens: 20, totalLatencyMs: 600, latencySamples: 1,
        models: { 'gemini-deep': 1 }, routes: { analysis: 2 },
        lastRequestAt: '2026-07-17T12:00:00Z',
      },
      { uid: 'ignored', day: '2026-07-15', count: 99 },
    ],
  );

  assert.equal(result.summary.requests, 4);
  assert.equal(result.summary.requestsToday, 2);
  assert.equal(result.summary.activeUsers, 2);
  assert.equal(result.summary.tokens, 260);
  assert.equal(result.summary.successRate, 75);
  assert.equal(result.summary.avgLatencyMs, 1400 / 3);
  assert.deepEqual(result.models, [
    { name: 'gemini-fast', count: 2 },
    { name: 'gemini-deep', count: 1 },
  ]);
});

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

test('keeps only newest releases for retention cleanup', () => {
  const retention = splitReleaseRetention([
    { tag: 'old', publishedAt: '2026-07-15T12:00:00Z' },
    { tag: 'newest', publishedAt: '2026-07-17T12:00:00Z' },
    { tag: 'middle', publishedAt: '2026-07-16T12:00:00Z' },
    { tag: 'older', publishedAt: '2026-07-14T12:00:00Z' },
  ], 3);
  assert.deepEqual(retention.keep.map((release) => release.tag), ['newest', 'middle', 'old']);
  assert.deepEqual(retention.remove.map((release) => release.tag), ['older']);
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
