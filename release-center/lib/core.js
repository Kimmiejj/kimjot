'use strict';

const VERSION_PATTERN = /^(\d+)\.(\d+)\.(\d+)\+(\d+)$/;

function parsePubspecVersion(pubspec) {
  const match = pubspec.match(/^version:\s*([^\s#]+)\s*$/m);
  if (!match || !VERSION_PATTERN.test(match[1])) {
    throw new Error('Could not find version in x.y.z+build format in pubspec.yaml');
  }
  return parseVersion(match[1]);
}

function parseVersion(value) {
  const match = String(value).match(VERSION_PATTERN);
  if (!match) throw new Error('version must use x.y.z+build format');
  return {
    versionName: `${match[1]}.${match[2]}.${match[3]}`,
    versionCode: Number(match[4]),
    major: Number(match[1]),
    minor: Number(match[2]),
    patch: Number(match[3]),
  };
}

function nextPatchVersion(version) {
  return {
    versionName: `${version.major}.${version.minor}.${version.patch + 1}`,
    versionCode: version.versionCode + 1,
  };
}

function replacePubspecVersion(pubspec, versionName, versionCode) {
  validateReleaseVersion(versionName, versionCode);
  return pubspec.replace(
    /^version:\s*[^\s#]+\s*$/m,
    `version: ${versionName}+${versionCode}`,
  );
}

function validateReleaseVersion(versionName, versionCode) {
  if (!/^\d+\.\d+\.\d+$/.test(String(versionName))) {
    throw new Error('versionName must use x.y.z format');
  }
  if (!Number.isSafeInteger(Number(versionCode)) || Number(versionCode) < 1) {
    throw new Error('versionCode must be a positive integer');
  }
}

function decodeFirestoreValue(value) {
  if (!value || typeof value !== 'object') return null;
  if ('nullValue' in value) return null;
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return Number(value.doubleValue);
  if ('booleanValue' in value) return Boolean(value.booleanValue);
  if ('timestampValue' in value) return value.timestampValue;
  if ('mapValue' in value) return decodeFirestoreFields(value.mapValue.fields || {});
  if ('arrayValue' in value) {
    return (value.arrayValue.values || []).map(decodeFirestoreValue);
  }
  return null;
}

function decodeFirestoreFields(fields = {}) {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, decodeFirestoreValue(value)]),
  );
}

function encodeFirestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encodeFirestoreValue) } };
  }
  if (typeof value === 'object') {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value).map(([key, item]) => [key, encodeFirestoreValue(item)]),
        ),
      },
    };
  }
  throw new Error(`Unsupported Firestore value type: ${typeof value}`);
}

function encodeFirestoreFields(object) {
  return Object.fromEntries(
    Object.entries(object).map(([key, value]) => [key, encodeFirestoreValue(value)]),
  );
}

function dateKeys(days, now = new Date()) {
  const result = [];
  const local = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  for (let offset = days - 1; offset >= 0; offset -= 1) {
    const date = new Date(local);
    date.setDate(local.getDate() - offset);
    result.push(formatDateKey(date));
  }
  return result;
}

function formatDateKey(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function aggregateUsage(days, documentsByDay, users = [], releases = [], config = {}) {
  const seen7 = new Set();
  const seen30 = new Set();
  const featureCounts = {};
  const versionCounts = {};
  let sessions30 = 0;
  const lastSeven = new Set(days.slice(-7));

  const daily = days.map((day) => {
    const documents = documentsByDay[day] || [];
    let sessions = 0;
    for (const document of documents) {
      if (document.uid) {
        seen30.add(document.uid);
        if (lastSeven.has(day)) seen7.add(document.uid);
      }
      sessions += Number(document.sessions || 0);
      const features = document.features || {};
      for (const [feature, count] of Object.entries(features)) {
        featureCounts[feature] = (featureCounts[feature] || 0) + Number(count || 0);
      }
      const version = document.versionName || 'unknown';
      versionCounts[version] = (versionCounts[version] || 0) + 1;
    }
    sessions30 += sessions;
    return { day, activeUsers: documents.length, sessions };
  });

  const todayDocs = documentsByDay[days.at(-1)] || [];
  const startOfToday = new Date(`${days.at(-1)}T00:00:00`);
  const newToday = users.filter((user) => Number(user.createdAt || 0) >= startOfToday.getTime()).length;

  return {
    generatedAt: new Date().toISOString(),
    summary: {
      totalUsers: users.length,
      activeToday: todayDocs.length,
      active7Days: seen7.size,
      active30Days: seen30.size,
      sessions30Days: sessions30,
      newUsersToday: newToday,
    },
    daily,
    features: sortCounts(featureCounts),
    versions: sortCounts(versionCounts),
    recentReleases: releases.slice(0, 8),
    updateConfig: config,
  };
}

function sortCounts(counts) {
  return Object.entries(counts)
    .map(([name, count]) => ({ name, count }))
    .sort((a, b) => b.count - a.count);
}

module.exports = {
  aggregateUsage,
  dateKeys,
  decodeFirestoreFields,
  encodeFirestoreFields,
  formatDateKey,
  nextPatchVersion,
  parsePubspecVersion,
  parseVersion,
  replacePubspecVersion,
  validateReleaseVersion,
};
