'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const http = require('node:http');
const https = require('node:https');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');

const {
  aggregateAiUsage,
  aggregateUsage,
  dateKeys,
  decodeFirestoreFields,
  encodeFirestoreFields,
  githubReleaseDownloadUrl,
  githubReleaseTag,
  nextAvailableVersionCode,
  nextPatchVersion,
  parsePubspecVersion,
  releaseVersionCode,
  replacePubspecVersion,
  splitReleaseRetention,
  validateReleaseVersion,
} = require('./lib/core');

const HOST = process.env.RELEASE_CENTER_HOST || '127.0.0.1';
const PORT = Number(process.env.RELEASE_CENTER_PORT || 4173);
const PROJECT_ID = process.env.KIMJOD_FIREBASE_PROJECT || 'kimjot';
const GITHUB_REPOSITORY = process.env.KIMJOD_GITHUB_REPOSITORY || 'Kimmiejj/kimjot';
const RELEASES_BASE_URL = `https://github.com/${GITHUB_REPOSITORY}/releases`;
const ROOT = path.resolve(__dirname, '..');
const WEB_DIR = path.join(__dirname, 'web');
const PUBLISH_DIR = path.join(__dirname, 'publish');
const STATE_PATH = path.join(__dirname, 'state.json');
const PUBSPEC_PATH = path.join(ROOT, 'pubspec.yaml');
const APK_PATH = path.join(ROOT, 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk');
const FIREBASE_BIN = process.env.FIREBASE_BIN || defaultFirebasePath();
const FLUTTER_BIN = process.env.FLUTTER_BIN || defaultFlutterPath();
const MAX_STORED_RELEASES = 3;
const GOOGLE_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const GOOGLE_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

const restoredState = readReleaseState();
let activeJob = restoredState.release || null;
let stagedRelease = restoredState.stagedRelease || null;
let cachedToken = null;
let cachedMonitoring = null;

if (activeJob?.state === 'running') {
  activeJob.state = 'failed';
  activeJob.step = 'Interrupted';
  activeJob.error = 'Release Center was closed while this job was running. Start the step again.';
  activeJob.finishedAt = new Date().toISOString();
  activeJob.logs = [...(activeJob.logs || []), {
    at: activeJob.finishedAt,
    line: `ERROR: ${activeJob.error}`,
  }];
  persistReleaseState();
}

function readReleaseState() {
  try {
    if (!fs.existsSync(STATE_PATH)) return {};
    const state = JSON.parse(fs.readFileSync(STATE_PATH, 'utf8'));
    return state && typeof state === 'object' ? state : {};
  } catch (_) {
    return {};
  }
}

function persistReleaseState() {
  fs.mkdirSync(path.dirname(STATE_PATH), { recursive: true });
  fs.writeFileSync(STATE_PATH, `${JSON.stringify({
    release: publicJob(activeJob),
    stagedRelease,
  }, null, 2)}\n`, 'utf8');
}

function defaultFirebasePath() {
  if (process.platform !== 'win32') return 'firebase';
  const candidate = process.env.APPDATA
    ? path.join(process.env.APPDATA, 'npm', 'firebase.cmd')
    : '';
  return candidate && fs.existsSync(candidate) ? candidate : 'firebase.cmd';
}

function defaultFlutterPath() {
  if (process.platform !== 'win32') return 'flutter';
  const candidate = process.env.USERPROFILE
    ? path.join(process.env.USERPROFILE, 'development', 'flutter', 'bin', 'flutter.bat')
    : '';
  return candidate && fs.existsSync(candidate) ? candidate : 'flutter';
}

function jsonResponse(response, status, body) {
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
  });
  response.end(JSON.stringify(body));
}

function errorResponse(response, status, error) {
  jsonResponse(response, status, {
    error: error instanceof Error ? error.message : String(error),
  });
}

function readJsonBody(request) {
  return new Promise((resolve, reject) => {
    let body = '';
    request.setEncoding('utf8');
    request.on('data', (chunk) => {
      body += chunk;
      if (body.length > 32_000) {
        reject(new Error('Request body is too large'));
        request.destroy();
      }
    });
    request.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (_) {
        reject(new Error('Invalid JSON'));
      }
    });
    request.on('error', reject);
  });
}

function checkLocalMutation(request) {
  if (request.headers['content-type']?.split(';')[0] !== 'application/json') {
    throw new Error('Only application/json requests are supported');
  }
  const origin = request.headers.origin;
  if (origin && origin !== `http://${HOST}:${PORT}` && origin !== `http://localhost:${PORT}`) {
    throw new Error('Blocked request from another origin');
  }
}

async function statusPayload() {
  const pubspec = fs.readFileSync(PUBSPEC_PATH, 'utf8');
  const current = parsePubspecVersion(pubspec);
  let updateConfig = {};
  try {
    const token = await firebaseAccessToken();
    updateConfig = await getFirestoreDocument('app_config/android', token) || {};
  } catch (error) {
    updateConfig = { warning: authHelp(error) };
  }
  const retryBuild = activeJob?.action === 'build' && activeJob.state === 'failed';
  const suggested = stagedRelease
    ? {
        versionName: stagedRelease.versionName,
        versionCode: stagedRelease.versionCode,
      }
    : retryBuild
      ? {
          versionName: activeJob.versionName,
          versionCode: activeJob.versionCode,
        }
    : nextPatchVersion(current);
  return {
    projectId: PROJECT_ID,
    hostingUrl: RELEASES_BASE_URL,
    current,
    suggested,
    updateConfig,
    tools: {
      flutter: FLUTTER_BIN,
      firebase: FIREBASE_BIN,
      flutterFound: executableLooksAvailable(FLUTTER_BIN),
      firebaseFound: executableLooksAvailable(FIREBASE_BIN),
    },
    release: publicJob(activeJob),
    stagedRelease,
  };
}

function executableLooksAvailable(executable) {
  return executable.includes(path.sep) ? fs.existsSync(executable) : true;
}

function publicJob(job) {
  if (!job) return null;
  return {
    id: job.id,
    state: job.state,
    step: job.step,
    startedAt: job.startedAt,
    finishedAt: job.finishedAt,
    action: job.action,
    versionName: job.versionName,
    versionCode: job.versionCode,
    logs: job.logs.slice(-120),
    error: job.error,
    result: job.result,
  };
}

async function dashboardPayload(days = 30) {
  const safeDays = Math.min(90, Math.max(7, Number(days) || 30));
  const keys = dateKeys(safeDays);
  const warnings = [];
  let token = '';
  try {
    token = await firebaseAccessToken();
  } catch (error) {
    const dashboard = aggregateUsage(keys, {}, [], [], {});
    dashboard.summary.onlineNow = 0;
    dashboard.warnings = [authHelp(error)];
    return dashboard;
  }
  let authUsersResult = [];
  let presence = [];
  let dayResults = [];
  let releases = [];
  let config = {};
  let aiUsageDocuments = [];
  let monitoring = { available: false };
  try {
    [authUsersResult, presence, dayResults, releases, config, aiUsageDocuments, monitoring] = await Promise.all([
      listAuthUsers(token).catch((error) => {
        warnings.push(`Auth users unavailable: ${error.message}`);
        return [];
      }),
      listFirestoreDocuments('', 'usage_users', token),
      Promise.all(keys.map(async (day) => [day, await listFirestoreDocuments(`usage_days/${day}`, 'daily_users', token)])),
      listFirestoreDocuments('', 'app_releases', token, 30),
      getFirestoreDocument('app_config/android', token).catch(() => ({})),
      listFirestoreDocuments('', 'ai_usage', token),
      cloudMonitoringSnapshot(token),
    ]);
  } catch (error) {
    const dashboard = aggregateUsage(keys, {}, [], [], {});
    dashboard.summary.onlineNow = 0;
    dashboard.warnings = [authHelp(error)];
    return dashboard;
  }

  const byDay = Object.fromEntries(dayResults);
  const fallbackUsers = presence.map((item) => ({
    localId: item.uid || item.id,
    createdAt: '0',
  }));
  const users = authUsersResult.length ? authUsersResult : fallbackUsers;
  const sortedReleases = releases.sort((a, b) => String(b.publishedAt || '').localeCompare(String(a.publishedAt || '')));
  const dashboard = aggregateUsage(keys, byDay, users, sortedReleases, config || {});
  const onlineThreshold = Date.now() - (15 * 60 * 1000);
  dashboard.summary.onlineNow = presence.filter((item) => {
    const lastSeen = Date.parse(item.lastSeenAt || '');
    return Number.isFinite(lastSeen) && lastSeen >= onlineThreshold;
  }).length;
  dashboard.summary.totalUsers = Math.max(dashboard.summary.totalUsers, presence.length, dashboard.summary.active30Days);
  dashboard.firebase = firebaseUsageSnapshot(keys, byDay, presence, dashboard.summary.totalUsers, releases.length, aiUsageDocuments.length, monitoring);
  dashboard.ai = aggregateAiUsage(keys, aiUsageDocuments);
  dashboard.liveUsers = presence
    .map((item) => ({
      user: anonymousUserLabel(item.uid || item.id),
      versionName: item.versionName || 'unknown',
      platform: item.platform || 'unknown',
      lastSeenAt: item.lastSeenAt || null,
    }))
    .filter((item) => item.lastSeenAt)
    .sort((left, right) => String(right.lastSeenAt).localeCompare(String(left.lastSeenAt)))
    .slice(0, 8);
  dashboard.insights = buildInsights(dashboard);
  dashboard.warnings = warnings;
  return dashboard;
}

function firebaseUsageSnapshot(days, documentsByDay, presence, authUsers, releases, aiDocuments, monitoring) {
  const dailyDocuments = days.reduce((total, day) => total + (documentsByDay[day] || []).length, 0);
  const todayDocuments = (documentsByDay[days.at(-1)] || []).length;
  const lastHeartbeatAt = presence.reduce((latest, item) => {
    const parsed = Date.parse(item.lastSeenAt || '');
    return Number.isFinite(parsed) && parsed > latest ? parsed : latest;
  }, 0);
  return {
    authUsers,
    presenceDocuments: presence.length,
    dailyDocuments,
    todayDocuments,
    documentsScanned: presence.length + dailyDocuments + releases + aiDocuments + 1,
    lastHeartbeatAt: lastHeartbeatAt ? new Date(lastHeartbeatAt).toISOString() : null,
    source: 'Firestore + Firebase Auth',
    cloud: monitoring,
  };
}

async function cloudMonitoringSnapshot(token) {
  if (cachedMonitoring && cachedMonitoring.expiresAt > Date.now()) return cachedMonitoring.value;
  const definitions = {
    reads24h: ['firestore.googleapis.com/document/read_ops_count', 'sum'],
    writes24h: ['firestore.googleapis.com/document/write_ops_count', 'sum'],
    deletes24h: ['firestore.googleapis.com/document/delete_ops_count', 'sum'],
    storageBytes: ['firestore.googleapis.com/storage/data_and_index_storage_bytes', 'latest'],
    activeConnections: ['firestore.googleapis.com/network/active_connections', 'latest'],
  };
  const entries = await Promise.all(Object.entries(definitions).map(async ([key, [metric, mode]]) => {
    try {
      return [key, await cloudMonitoringMetric(metric, mode, token)];
    } catch (_) {
      return [key, null];
    }
  }));
  const values = Object.fromEntries(entries);
  const available = entries.some(([, value]) => value !== null);
  const result = { available, ...values, sampledAt: new Date().toISOString() };
  cachedMonitoring = { value: result, expiresAt: Date.now() + (available ? 60_000 : 120_000) };
  return result;
}

async function cloudMonitoringMetric(metricType, mode, token) {
  const end = new Date();
  const start = new Date(end.getTime() - 24 * 60 * 60 * 1000);
  const url = new URL(`https://monitoring.googleapis.com/v3/projects/${encodeURIComponent(PROJECT_ID)}/timeSeries`);
  url.searchParams.set('filter', `metric.type = "${metricType}"`);
  url.searchParams.set('interval.startTime', start.toISOString());
  url.searchParams.set('interval.endTime', end.toISOString());
  url.searchParams.set('view', 'FULL');
  url.searchParams.set('pageSize', '200');
  const result = await googleJson(url.toString(), token);
  const series = result.timeSeries || [];
  if (!series.length) return 0;
  if (mode === 'latest') {
    return series.reduce((total, item) => total + monitoringPointValue(item.points?.[0]), 0);
  }
  return series.reduce(
    (total, item) => total + (item.points || []).reduce((sum, point) => sum + monitoringPointValue(point), 0),
    0,
  );
}

function monitoringPointValue(point) {
  const value = point?.value || {};
  return Number(value.int64Value ?? value.doubleValue ?? 0) || 0;
}

function anonymousUserLabel(uid) {
  const suffix = crypto.createHash('sha256').update(String(uid || 'unknown')).digest('hex').slice(0, 5).toUpperCase();
  return `User ${suffix}`;
}

function buildInsights(dashboard) {
  const insights = [];
  const summary = dashboard.summary;
  const ai = dashboard.ai.summary;
  const activeRate = summary.totalUsers ? summary.active7Days / summary.totalUsers * 100 : 0;
  insights.push({
    tone: activeRate >= 25 ? 'good' : 'watch',
    title: `${activeRate.toFixed(0)}% ของผู้ใช้กลับมาใน 7 วัน`,
    detail: `${summary.active7Days} จาก ${summary.totalUsers} บัญชีที่ลงทะเบียน`,
  });
  if (ai.requests > 0 && ai.observabilityCoverage < 90) {
    insights.push({
      tone: 'watch',
      title: 'AI telemetry ยังเก็บรายละเอียดไม่ครบ',
      detail: `วัด latency และ token ได้ ${ai.observabilityCoverage.toFixed(0)}% ของ request ในช่วงนี้ ระบบจะเริ่มครบหลัง deploy backend รุ่นนี้`,
    });
  } else if (ai.measuredRequests > 0) {
    insights.push({
      tone: ai.successRate >= 95 ? 'good' : 'danger',
      title: `Gemini สำเร็จ ${ai.successRate.toFixed(1)}%`,
      detail: `${ai.failures} request ล้มเหลว · latency เฉลี่ย ${Math.round(ai.avgLatencyMs || 0)} ms`,
    });
  } else {
    insights.push({
      tone: 'neutral',
      title: 'ยังไม่มี Gemini request ที่วัดผลได้',
      detail: 'ตัวเลข token, latency และ success rate จะเริ่มแสดงหลังมีการเรียก AI backend',
    });
  }
  const topVersion = dashboard.versions[0];
  if (dashboard.versions.length > 1 && topVersion) {
    insights.push({
      tone: 'neutral',
      title: `เวอร์ชันหลักคือ v${topVersion.name}`,
      detail: `พบ ${dashboard.versions.length} เวอร์ชันที่ยังมีการใช้งานในช่วงนี้`,
    });
  }
  return insights.slice(0, 4);
}

async function firebaseAccessToken() {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) return cachedToken.token;

  const attempts = [
    () => accessTokenFromExplicitEnv(),
    () => accessTokenFromServiceAccount(),
    () => accessTokenFromGcloud(),
    () => accessTokenFromFirebaseConfig(),
  ];
  const errors = [];
  for (const attempt of attempts) {
    try {
      const result = await attempt();
      if (result?.token) {
        await validateAccessToken(result.token);
        cachedToken = result;
        return result.token;
      }
    } catch (error) {
      errors.push(error.message);
    }
  }
  throw new Error(`Could not authenticate with Firebase. ${errors.filter(Boolean).join(' | ')}`);
}

async function validateAccessToken(token) {
  const url = new URL('https://www.googleapis.com/oauth2/v1/tokeninfo');
  url.searchParams.set('access_token', token);
  const response = await fetch(url);
  const text = await response.text();
  if (!response.ok) {
    let detail = text;
    try {
      detail = JSON.parse(text).error_description || JSON.parse(text).error || text;
    } catch (_) {
      // Keep the original text.
    }
    throw new Error(`Access token was rejected by Google (${detail}). Run firebase login --reauth.`);
  }
}

function accessTokenFromExplicitEnv() {
  if (process.env.KIMJOD_GOOGLE_ACCESS_TOKEN) {
    return {
      token: process.env.KIMJOD_GOOGLE_ACCESS_TOKEN,
      expiresAt: Date.now() + 45 * 60 * 1000,
    };
  }
  if (!process.env.FIREBASE_TOKEN) return null;
  return refreshGoogleAccessToken(process.env.FIREBASE_TOKEN);
}

async function accessTokenFromServiceAccount() {
  const filePath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!filePath) return null;
  const credentials = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  if (!credentials.client_email || !credentials.private_key) {
    throw new Error('GOOGLE_APPLICATION_CREDENTIALS is not a service account JSON file');
  }
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = base64Url(JSON.stringify({
    iss: credentials.client_email,
    scope: 'https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/firebase',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claim}`;
  const signature = crypto.createSign('RSA-SHA256').update(unsigned).sign(credentials.private_key);
  const assertion = `${unsigned}.${base64Url(signature)}`;
  const data = await formPost('https://oauth2.googleapis.com/token', {
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion,
  });
  return {
    token: data.access_token,
    expiresAt: Date.now() + Number(data.expires_in || 3600) * 1000,
  };
}

async function accessTokenFromGcloud() {
  const bin = process.platform === 'win32' ? 'gcloud.cmd' : 'gcloud';
  const token = (await runCapturedCommand(bin, ['auth', 'print-access-token'], {
    cwd: ROOT,
    sensitive: true,
  })).trim();
  if (!token) throw new Error('gcloud did not return an access token');
  return { token, expiresAt: Date.now() + 45 * 60 * 1000 };
}

async function accessTokenFromFirebaseConfig() {
  const config = readFirebaseConfigstore();
  const account = selectFirebaseAccount(config);
  const refreshToken = account?.tokens?.refresh_token || config.tokens?.refresh_token;
  if (!refreshToken) throw new Error('Firebase CLI is not logged in. Run firebase login or set GOOGLE_APPLICATION_CREDENTIALS.');
  return refreshGoogleAccessToken(refreshToken);
}

function readFirebaseConfigstore() {
  const candidates = [];
  if (process.env.XDG_CONFIG_HOME) {
    candidates.push(path.join(process.env.XDG_CONFIG_HOME, 'configstore', 'firebase-tools.json'));
  }
  if (process.env.USERPROFILE) {
    candidates.push(path.join(process.env.USERPROFILE, '.config', 'configstore', 'firebase-tools.json'));
  }
  if (process.env.APPDATA) {
    candidates.push(path.join(process.env.APPDATA, 'configstore', 'firebase-tools.json'));
  }
  const existing = candidates.find((candidate) => fs.existsSync(candidate));
  if (!existing) throw new Error('Firebase CLI config was not found. Run firebase login.');
  return JSON.parse(fs.readFileSync(existing, 'utf8'));
}

function selectFirebaseAccount(config) {
  const accounts = [];
  if (config.user || config.tokens) accounts.push({ user: config.user, tokens: config.tokens });
  accounts.push(...(config.additionalAccounts || []));
  const activeEmail = config.activeAccounts?.[ROOT];
  if (activeEmail) {
    return accounts.find((account) => account.user?.email === activeEmail) || accounts[0];
  }
  return accounts[0];
}

function refreshGoogleAccessToken(refreshToken) {
  return formPost('https://accounts.google.com/o/oauth2/token', {
    refresh_token: refreshToken,
    client_id: GOOGLE_CLIENT_ID,
    client_secret: GOOGLE_CLIENT_SECRET,
    grant_type: 'refresh_token',
  }).then((data) => ({
    token: data.access_token,
    expiresAt: Date.now() + Number(data.expires_in || 3600) * 1000,
  }));
}

async function formPost(url, fields) {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(fields),
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : {};
  if (!response.ok) {
    throw new Error(data.error_description || data.error?.message || data.error || `Token request failed with ${response.status}`);
  }
  return data;
}

function base64Url(value) {
  const buffer = Buffer.isBuffer(value) ? value : Buffer.from(value);
  return buffer.toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

function authHelp(error) {
  return `${error.message}. Try: firebase login, or set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON with Firebase/Firestore access.`;
}

async function googleJson(url, token, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });
  if (response.status === 404 && options.allow404) return null;
  const text = await response.text();
  let data = {};
  try {
    data = text ? JSON.parse(text) : {};
  } catch (_) {
    data = { error: { message: text } };
  }
  if (!response.ok) {
    throw new Error(data.error?.message || `Google API returned ${response.status}`);
  }
  return data;
}

async function githubAccessToken() {
  const explicit = process.env.KIMJOD_GITHUB_TOKEN || process.env.GITHUB_TOKEN;
  if (explicit) return explicit;
  const output = await runCapturedCommand('git', ['credential', 'fill'], {
    cwd: ROOT,
    input: 'protocol=https\nhost=github.com\n\n',
    sensitive: true,
  });
  const credentials = {};
  for (const line of output.split(/\r?\n/)) {
    const separator = line.indexOf('=');
    if (separator > 0) credentials[line.slice(0, separator)] = line.slice(separator + 1);
  }
  if (!credentials.password) {
    throw new Error('GitHub sign-in was not found. Sign in with Git Credential Manager or set KIMJOD_GITHUB_TOKEN.');
  }
  return credentials.password;
}

async function githubJson(url, token, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'User-Agent': 'Kimjod-Release-Center',
      'X-GitHub-Api-Version': '2022-11-28',
      ...(options.headers || {}),
    },
  });
  if (response.status === 404 && options.allow404) return null;
  const text = await response.text();
  let data = {};
  try {
    data = text ? JSON.parse(text) : {};
  } catch (_) {
    data = { message: text };
  }
  if (!response.ok) {
    throw new Error(data.message || `GitHub API returned ${response.status}`);
  }
  return data;
}

async function validateGitHubAccess(token) {
  const repository = await githubJson(`https://api.github.com/repos/${GITHUB_REPOSITORY}`, token);
  if (repository.permissions && repository.permissions.push !== true) {
    throw new Error(`GitHub credential does not have write access to ${GITHUB_REPOSITORY}`);
  }
}

async function ensureGitHubRelease(release, token) {
  const tag = githubReleaseTag(release.versionName, release.versionCode);
  const tagUrl = `https://api.github.com/repos/${GITHUB_REPOSITORY}/releases/tags/${encodeURIComponent(tag)}`;
  const existing = await githubJson(tagUrl, token, { allow404: true });
  if (existing) return existing;
  return githubJson(`https://api.github.com/repos/${GITHUB_REPOSITORY}/releases`, token, {
    method: 'POST',
    body: JSON.stringify({
      tag_name: tag,
      name: `Kimjod ${release.versionName} (${release.versionCode})`,
      body: 'Android update published by Kimjod Release Center.',
      draft: false,
      prerelease: false,
    }),
  });
}

async function publishGitHubApk(release, apkPath, token) {
  const githubRelease = await ensureGitHubRelease(release, token);
  const existingAsset = (githubRelease.assets || []).find((asset) => asset.name === release.apkName);
  if (existingAsset?.state === 'uploaded' && Number(existingAsset.size) === Number(release.sizeBytes)) {
    return existingAsset;
  }
  if (existingAsset) {
    await githubJson(
      `https://api.github.com/repos/${GITHUB_REPOSITORY}/releases/assets/${existingAsset.id}`,
      token,
      { method: 'DELETE' },
    );
  }
  return uploadGitHubReleaseAsset(githubRelease.upload_url, apkPath, release.apkName, token);
}

async function listGitHubReleases(token) {
  return githubJson(`https://api.github.com/repos/${GITHUB_REPOSITORY}/releases?per_page=100`, token);
}

async function deleteGitHubReleaseAndTag(release, token) {
  await githubJson(
    `https://api.github.com/repos/${GITHUB_REPOSITORY}/releases/${release.id}`,
    token,
    { method: 'DELETE' },
  );
  await githubJson(
    `https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/tags/${encodeURIComponent(release.tag_name)}`,
    token,
    { method: 'DELETE', allow404: true },
  );
}

async function cleanupOldGitHubReleases(job, token) {
  const releases = await listGitHubReleases(token);
  const appReleases = releases.filter((release) => /^android-v\d+\.\d+\.\d+-\d+$/.test(String(release.tag_name || '')));
  const { remove } = splitReleaseRetention(appReleases, MAX_STORED_RELEASES);
  for (const release of remove) {
    await deleteGitHubReleaseAndTag(release, token);
    logJob(job, `Deleted old GitHub release ${release.tag_name}`);
  }
  if (!remove.length) logJob(job, `GitHub cleanup: ${appReleases.length}/${MAX_STORED_RELEASES} releases stored`);
}

function uploadGitHubReleaseAsset(uploadUrl, apkPath, apkName, token) {
  const target = new URL(uploadUrl.replace(/\{.*$/, ''));
  target.searchParams.set('name', apkName);
  const size = fs.statSync(apkPath).size;
  return new Promise((resolve, reject) => {
    const request = https.request(target, {
      method: 'POST',
      headers: {
        Accept: 'application/vnd.github+json',
        Authorization: `Bearer ${token}`,
        'Content-Length': size,
        'Content-Type': 'application/vnd.android.package-archive',
        'User-Agent': 'Kimjod-Release-Center',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    }, (response) => {
      let body = '';
      response.setEncoding('utf8');
      response.on('data', (chunk) => { body += chunk; });
      response.on('end', () => {
        let data = {};
        try {
          data = body ? JSON.parse(body) : {};
        } catch (_) {
          data = { message: body };
        }
        if (response.statusCode >= 200 && response.statusCode < 300) resolve(data);
        else reject(new Error(data.message || `GitHub upload returned ${response.statusCode}`));
      });
    });
    request.on('error', reject);
    const input = fs.createReadStream(apkPath);
    input.on('error', (error) => request.destroy(error));
    input.pipe(request);
  });
}

function firestoreDocumentUrl(documentPath) {
  const encoded = documentPath
    .split('/')
    .filter(Boolean)
    .map(encodeURIComponent)
    .join('/');
  const base = `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(PROJECT_ID)}/databases/(default)/documents`;
  return encoded ? `${base}/${encoded}` : `${base}/`;
}

async function getFirestoreDocument(documentPath, token) {
  const document = await googleJson(firestoreDocumentUrl(documentPath), token, { allow404: true });
  return document ? decodeFirestoreFields(document.fields) : null;
}

async function listFirestoreDocuments(parentPath, collectionId, token, pageSize = 1000) {
  const documents = [];
  let pageToken = '';
  do {
    const base = `${firestoreDocumentUrl(parentPath)}${encodeURIComponent(collectionId)}`;
    const url = new URL(base);
    url.searchParams.set('pageSize', String(pageSize));
    if (pageToken) url.searchParams.set('pageToken', pageToken);
    const result = await googleJson(url.toString(), token, { allow404: true });
    if (!result) return documents;
    for (const document of result.documents || []) {
      documents.push({
        id: document.name?.split('/').at(-1),
        ...decodeFirestoreFields(document.fields),
      });
    }
    pageToken = result.nextPageToken || '';
  } while (pageToken);
  return documents;
}

async function patchFirestoreDocument(documentPath, values, token) {
  const url = new URL(firestoreDocumentUrl(documentPath));
  for (const key of Object.keys(values)) {
    url.searchParams.append('updateMask.fieldPaths', key);
  }
  return googleJson(url.toString(), token, {
    method: 'PATCH',
    body: JSON.stringify({ fields: encodeFirestoreFields(values) }),
  });
}

async function deleteFirestoreDocument(documentPath, token) {
  return googleJson(firestoreDocumentUrl(documentPath), token, {
    method: 'DELETE',
    allow404: true,
  });
}

async function cleanupOldFirestoreReleases(job, token) {
  const releases = await listFirestoreDocuments('', 'app_releases', token, 100);
  const { remove } = splitReleaseRetention(releases, MAX_STORED_RELEASES);
  for (const release of remove) {
    if (!release.id) continue;
    await deleteFirestoreDocument(`app_releases/${release.id}`, token);
    logJob(job, `Deleted old release record v${release.versionName}+${release.versionCode}`);
  }
  if (!remove.length) logJob(job, `Release history cleanup: ${releases.length}/${MAX_STORED_RELEASES} records stored`);
}

async function deleteReleasesNewerThan(job, token, githubToken, targetVersionCode, keepReleaseId, keepTag) {
  setJobStep(job, 'Delete newer releases');
  const [firestoreReleases, githubReleases] = await Promise.all([
    listFirestoreDocuments('', 'app_releases', token, 100),
    listGitHubReleases(githubToken),
  ]);

  for (const release of firestoreReleases) {
    if (!release.id || release.id === keepReleaseId) continue;
    if (releaseVersionCode(release) <= targetVersionCode) continue;
    await deleteFirestoreDocument(`app_releases/${release.id}`, token);
    logJob(job, `Deleted newer release record v${release.versionName}+${release.versionCode}`);
  }

  for (const release of githubReleases) {
    if (release.tag_name === keepTag) continue;
    if (releaseVersionCode(release) <= targetVersionCode) continue;
    await deleteGitHubReleaseAndTag(release, githubToken);
    logJob(job, `Deleted newer GitHub release ${release.tag_name}`);
  }
}

function deleteLocalReleasesNewerThan(job, targetVersionCode, keepApkName) {
  const downloadsDir = path.join(PUBLISH_DIR, 'downloads');
  if (fs.existsSync(downloadsDir)) {
    for (const apkName of fs.readdirSync(downloadsDir)) {
      const match = apkName.match(/-(\d+)\.apk$/);
      if (apkName === keepApkName || !match || Number(match[1]) <= targetVersionCode) continue;
      fs.unlinkSync(path.join(downloadsDir, apkName));
      logJob(job, `Deleted newer local APK ${apkName}`);
    }
  }
  if (stagedRelease && Number(stagedRelease.versionCode) > targetVersionCode) {
    logJob(job, `Discarded staged v${stagedRelease.versionName}+${stagedRelease.versionCode}`);
    stagedRelease = null;
  }
}

async function listAuthUsers(token) {
  const users = [];
  let nextPageToken = '';
  do {
    const url = new URL(`https://identitytoolkit.googleapis.com/v1/projects/${encodeURIComponent(PROJECT_ID)}/accounts:batchGet`);
    url.searchParams.set('maxResults', '1000');
    if (nextPageToken) url.searchParams.set('nextPageToken', nextPageToken);
    const result = await googleJson(url.toString(), token);
    users.push(...(result.users || []));
    nextPageToken = result.nextPageToken || '';
  } while (nextPageToken);
  return users;
}

async function beginBuild(input) {
  if (activeJob?.state === 'running') {
    throw new Error('A release job is already running. Please wait for it to finish.');
  }
  const versionName = String(input.versionName || '').trim();
  const versionCode = Number(input.versionCode);
  validateReleaseVersion(versionName, versionCode);
  const current = parsePubspecVersion(fs.readFileSync(PUBSPEC_PATH, 'utf8'));
  if (versionCode < current.versionCode) {
    throw new Error(`versionCode must be at least ${current.versionCode}`);
  }
  const messageTh = String(input.messageTh || 'มีเวอร์ชันใหม่ กรุณาอัปเดตก่อนใช้งาน').trim().slice(0, 240);
  const messageEn = String(input.messageEn || 'A new version is required. Please update to continue.').trim().slice(0, 240);
  const job = {
    id: crypto.randomUUID(),
    action: 'build',
    state: 'running',
    step: 'Prepare build',
    startedAt: new Date().toISOString(),
    finishedAt: null,
    versionName,
    versionCode,
    logs: [],
    error: null,
    result: null,
  };
  activeJob = job;
  persistReleaseState();
  buildPipeline(job, { versionName, versionCode, messageTh, messageEn }).catch(() => {});
  return publicJob(job);
}

async function buildPipeline(job, release) {
  const originalPubspec = fs.readFileSync(PUBSPEC_PATH, 'utf8');
  try {
    logJob(job, `Starting build ${release.versionName}+${release.versionCode}`);
    setJobStep(job, 'Check Flutter');
    if (!executableLooksAvailable(FLUTTER_BIN)) throw new Error(`Flutter was not found at ${FLUTTER_BIN}`);

    setJobStep(job, 'Update version');
    const nextPubspec = replacePubspecVersion(originalPubspec, release.versionName, release.versionCode);
    fs.writeFileSync(PUBSPEC_PATH, nextPubspec, 'utf8');
    logJob(job, `Updated pubspec.yaml to ${release.versionName}+${release.versionCode}`);

    setJobStep(job, 'Build Android APK');
    await runLoggedCommand(
      job,
      FLUTTER_BIN,
      ['build', 'apk', '--release', `--build-name=${release.versionName}`, `--build-number=${release.versionCode}`],
      { cwd: ROOT },
    );
    if (!fs.existsSync(APK_PATH)) throw new Error('Build finished but app-release.apk was not found');

    setJobStep(job, 'Prepare files');
    const downloadsDir = path.join(PUBLISH_DIR, 'downloads');
    fs.mkdirSync(downloadsDir, { recursive: true });
    const apkName = `kimjod-${release.versionName}-${release.versionCode}.apk`;
    const publishedApk = path.join(downloadsDir, apkName);
    fs.copyFileSync(APK_PATH, publishedApk);
    const apkBuffer = fs.readFileSync(publishedApk);
    const sha256 = crypto.createHash('sha256').update(apkBuffer).digest('hex');
    const updateUrl = githubReleaseDownloadUrl(
      GITHUB_REPOSITORY,
      release.versionName,
      release.versionCode,
      apkName,
    );
    const builtAt = new Date().toISOString();
    const manifest = {
      applicationId: 'com.kimjot.project',
      versionName: release.versionName,
      versionCode: release.versionCode,
      updateUrl,
      downloadProvider: 'github-releases',
      releaseTag: githubReleaseTag(release.versionName, release.versionCode),
      sha256,
      sizeBytes: apkBuffer.length,
      builtAt,
    };
    fs.writeFileSync(path.join(PUBLISH_DIR, 'release.json'), `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
    logJob(job, `Prepared APK ${(apkBuffer.length / 1024 / 1024).toFixed(1)} MB and SHA-256`);

    stagedRelease = {
      ...manifest,
      apkName,
      messageTh: release.messageTh,
      messageEn: release.messageEn,
    };
    job.state = 'success';
    job.step = 'Ready to send';
    job.result = manifest;
    logJob(job, 'Build completed. Review the version, then press Send update.');
  } catch (error) {
    fs.writeFileSync(PUBSPEC_PATH, originalPubspec, 'utf8');
    logJob(job, 'Restored pubspec.yaml because the build did not finish');
    job.state = 'failed';
    job.step = 'Failed';
    job.error = error.message;
    logJob(job, `ERROR: ${error.message}`);
  } finally {
    job.finishedAt = new Date().toISOString();
    persistReleaseState();
  }
}

async function beginPublish() {
  if (activeJob?.state === 'running') {
    throw new Error('A release job is already running. Please wait for it to finish.');
  }
  if (!stagedRelease) {
    throw new Error('Build an APK before sending an update.');
  }
  const apkPath = path.join(PUBLISH_DIR, 'downloads', stagedRelease.apkName);
  if (!fs.existsSync(apkPath)) {
    throw new Error('The staged APK is missing. Build it again before sending.');
  }
  const job = {
    id: crypto.randomUUID(),
    action: 'publish',
    state: 'running',
    step: 'Prepare send',
    startedAt: new Date().toISOString(),
    finishedAt: null,
    versionName: stagedRelease.versionName,
    versionCode: stagedRelease.versionCode,
    logs: [],
    error: null,
    result: null,
  };
  activeJob = job;
  persistReleaseState();
  publishPipeline(job, { ...stagedRelease }).catch(() => {});
  return publicJob(job);
}

async function beginSendExisting(input) {
  if (activeJob?.state === 'running') {
    throw new Error('A release job is already running. Please wait for it to finish.');
  }
  const releaseId = String(input.releaseId || '').trim();
  if (!/^[A-Za-z0-9_-]+$/.test(releaseId)) {
    throw new Error('releaseId is invalid');
  }
  const token = await firebaseAccessToken();
  const release = await getFirestoreDocument(`app_releases/${releaseId}`, token);
  if (!release) throw new Error('Release was not found');
  validateReleaseVersion(release.versionName, Number(release.versionCode));
  if (!release.updateUrl) throw new Error('Release does not have a download URL');

  const job = {
    id: `send_${Date.now()}`,
    action: 'send-existing',
    state: 'running',
    step: 'Prepare',
    startedAt: new Date().toISOString(),
    finishedAt: null,
    versionName: release.versionName,
    versionCode: Number(release.versionCode),
    logs: [],
    error: null,
    result: null,
  };
  activeJob = job;
  persistReleaseState();
  sendExistingPipeline(job, { ...release, versionCode: Number(release.versionCode) }).catch(() => {});
  return publicJob(job);
}

async function ensureLocalGitTag(job, tag) {
  if (!/^android-v\d+\.\d+\.\d+-\d+$/.test(tag)) {
    throw new Error(`Rollback source tag is invalid: ${tag}`);
  }
  try {
    return String(await runCapturedCommand(
      'git',
      ['rev-parse', '--verify', `refs/tags/${tag}^{commit}`],
      { cwd: ROOT },
    )).trim();
  } catch (_) {
    setJobStep(job, 'Fetch rollback source');
    await runLoggedCommand(job, 'git', ['fetch', 'origin', 'tag', tag], { cwd: ROOT });
    return String(await runCapturedCommand(
      'git',
      ['rev-parse', '--verify', `refs/tags/${tag}^{commit}`],
      { cwd: ROOT },
    )).trim();
  }
}

function copyRollbackSigningConfiguration(worktree) {
  const sourceProperties = path.join(ROOT, 'android', 'key.properties');
  if (!fs.existsSync(sourceProperties)) return;
  const targetProperties = path.join(worktree, 'android', 'key.properties');
  fs.mkdirSync(path.dirname(targetProperties), { recursive: true });
  fs.copyFileSync(sourceProperties, targetProperties);

  const properties = fs.readFileSync(sourceProperties, 'utf8');
  const storeLine = properties.match(/^storeFile\s*=\s*(.+)\s*$/m);
  if (!storeLine) return;
  const storeFile = storeLine[1].trim();
  if (path.isAbsolute(storeFile)) return;
  const sourceStore = path.resolve(ROOT, 'android', 'app', storeFile);
  const targetStore = path.resolve(worktree, 'android', 'app', storeFile);
  if (!fs.existsSync(sourceStore)) {
    throw new Error('Android signing keystore referenced by key.properties was not found');
  }
  if (!targetStore.startsWith(`${worktree}${path.sep}`)) {
    throw new Error('Android signing keystore path must stay inside the project');
  }
  fs.mkdirSync(path.dirname(targetStore), { recursive: true });
  fs.copyFileSync(sourceStore, targetStore);
}

async function buildRollbackRelease(job, selectedRelease, versionCode) {
  const sourceRef = selectedRelease.sourceRef
    || selectedRelease.releaseTag
    || githubReleaseTag(selectedRelease.versionName, Number(selectedRelease.versionCode));
  const commit = await ensureLocalGitTag(job, sourceRef);
  const temporaryRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'kimjod-rollback-'));
  const worktree = path.join(temporaryRoot, 'source');
  let worktreeAdded = false;
  try {
    setJobStep(job, 'Prepare rollback source');
    await runLoggedCommand(job, 'git', ['worktree', 'add', '--detach', worktree, commit], { cwd: ROOT });
    worktreeAdded = true;
    copyRollbackSigningConfiguration(worktree);

    setJobStep(job, 'Build rollback APK');
    await runLoggedCommand(
      job,
      FLUTTER_BIN,
      [
        'build',
        'apk',
        '--release',
        `--build-name=${selectedRelease.versionName}`,
        `--build-number=${versionCode}`,
      ],
      { cwd: worktree },
    );

    const builtApk = path.join(worktree, 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk');
    if (!fs.existsSync(builtApk)) throw new Error('Rollback build finished but app-release.apk was not found');
    const downloadsDir = path.join(PUBLISH_DIR, 'downloads');
    fs.mkdirSync(downloadsDir, { recursive: true });
    const apkName = `kimjod-${selectedRelease.versionName}-${versionCode}.apk`;
    const apkPath = path.join(downloadsDir, apkName);
    fs.copyFileSync(builtApk, apkPath);
    const apkBuffer = fs.readFileSync(apkPath);
    const builtAt = new Date().toISOString();
    return {
      applicationId: 'com.kimjot.project',
      versionName: selectedRelease.versionName,
      versionCode,
      apkName,
      updateUrl: githubReleaseDownloadUrl(
        GITHUB_REPOSITORY,
        selectedRelease.versionName,
        versionCode,
        apkName,
      ),
      downloadProvider: 'github-releases',
      releaseTag: githubReleaseTag(selectedRelease.versionName, versionCode),
      sourceRef,
      rollbackTargetVersionCode: Number(selectedRelease.versionCode),
      sha256: crypto.createHash('sha256').update(apkBuffer).digest('hex'),
      sizeBytes: apkBuffer.length,
      builtAt,
      messageTh: selectedRelease.messageTh,
      messageEn: selectedRelease.messageEn,
    };
  } finally {
    if (worktreeAdded) {
      await runCapturedCommand('git', ['worktree', 'remove', '--force', worktree], { cwd: ROOT })
        .catch(() => {});
    }
    fs.rmSync(temporaryRoot, { recursive: true, force: true });
  }
}

function advanceMainBuildNumber(job, versionCode) {
  const pubspec = fs.readFileSync(PUBSPEC_PATH, 'utf8');
  const current = parsePubspecVersion(pubspec);
  if (current.versionCode >= versionCode) return;
  fs.writeFileSync(
    PUBSPEC_PATH,
    replacePubspecVersion(pubspec, current.versionName, versionCode),
    'utf8',
  );
  logJob(job, `Advanced main pubspec build number to ${versionCode}`);
}

async function publishPipeline(job, release) {
  try {
    release.downloadProvider = 'github-releases';
    release.releaseTag = githubReleaseTag(release.versionName, release.versionCode);
    release.updateUrl = githubReleaseDownloadUrl(
      GITHUB_REPOSITORY,
      release.versionName,
      release.versionCode,
      release.apkName,
    );
    logJob(job, `Sending ${release.versionName}+${release.versionCode} to users`);
    setJobStep(job, 'Check Firebase and GitHub');
    const [token, githubToken] = await Promise.all([
      firebaseAccessToken(),
      githubAccessToken(),
    ]);
    await validateGitHubAccess(githubToken);
    if (!executableLooksAvailable(FIREBASE_BIN)) throw new Error(`Firebase CLI was not found at ${FIREBASE_BIN}`);
    const currentConfig = await getFirestoreDocument('app_config/android', token) || {};
    if (release.versionCode < Number(currentConfig.minimumVersionCode || 0)) {
      throw new Error(`Cannot send versionCode ${release.versionCode}; users already require ${currentConfig.minimumVersionCode}`);
    }

    setJobStep(job, 'Deploy Firestore rules');
    await runLoggedCommand(
      job,
      FIREBASE_BIN,
      ['deploy', '--only', 'firestore:rules', '--project', PROJECT_ID, '--non-interactive'],
      { cwd: ROOT },
    );

    setJobStep(job, 'Upload APK to GitHub Releases');
    const apkPath = path.join(PUBLISH_DIR, 'downloads', release.apkName);
    const asset = await publishGitHubApk(release, apkPath, githubToken);
    release.updateUrl = asset.browser_download_url || githubReleaseDownloadUrl(
      GITHUB_REPOSITORY,
      release.versionName,
      release.versionCode,
      release.apkName,
    );
    logJob(job, `Uploaded APK: ${release.updateUrl}`);

    const publishedAt = new Date().toISOString();
    const manifest = { ...release, publishedAt };
    delete manifest.apkName;
    delete manifest.messageTh;
    delete manifest.messageEn;
    fs.writeFileSync(path.join(PUBLISH_DIR, 'release.json'), `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');

    setJobStep(job, 'Record release');
    const releaseId = `${publishedAt.replace(/[^0-9]/g, '').slice(0, 14)}_${release.versionCode}`;
    await patchFirestoreDocument(`app_releases/${releaseId}`, {
      ...manifest,
      messageTh: release.messageTh,
      messageEn: release.messageEn,
      publishedAt: new Date(publishedAt),
    }, token);

    await enableRequiredUpdate(job, release, token, publishedAt);

    setJobStep(job, 'Cleanup old releases');
    await cleanupStoredReleases(job, token, githubToken);

    stagedRelease = null;
    job.state = 'success';
    job.step = 'Sent to users';
    job.result = manifest;
    logJob(job, `Versions below ${release.versionCode} must now update before using the app.`);
  } catch (error) {
    job.state = 'failed';
    job.step = 'Failed';
    job.error = error.message;
    logJob(job, `ERROR: ${error.message}`);
  } finally {
    job.finishedAt = new Date().toISOString();
    persistReleaseState();
  }
}

async function sendExistingPipeline(job, release) {
  try {
    const targetVersionCode = Number(release.versionCode);
    logJob(job, `Rolling all users back to ${release.versionName}+${targetVersionCode}`);
    setJobStep(job, 'Check Firebase and GitHub');
    const [token, githubToken] = await Promise.all([
      firebaseAccessToken(),
      githubAccessToken(),
    ]);
    await validateGitHubAccess(githubToken);
    await verifyGitHubReleaseAsset(release, githubToken);

    const [currentConfig, firestoreReleases, githubReleases] = await Promise.all([
      getFirestoreDocument('app_config/android', token).then((value) => value || {}),
      listFirestoreDocuments('', 'app_releases', token, 100),
      listGitHubReleases(githubToken),
    ]);
    const currentPubspec = parsePubspecVersion(fs.readFileSync(PUBSPEC_PATH, 'utf8'));
    const rollbackVersionCode = nextAvailableVersionCode([
      currentPubspec.versionCode,
      Number(currentConfig.minimumVersionCode || 0),
      Number(currentConfig.highestPublishedVersionCode || 0),
      ...firestoreReleases,
      ...githubReleases,
    ]);
    logJob(job, `Using forward-only rollback build number ${rollbackVersionCode}`);

    const rollbackRelease = await buildRollbackRelease(job, release, rollbackVersionCode);
    setJobStep(job, 'Upload rollback APK');
    const rollbackApkPath = path.join(PUBLISH_DIR, 'downloads', rollbackRelease.apkName);
    const asset = await publishGitHubApk(rollbackRelease, rollbackApkPath, githubToken);
    rollbackRelease.updateUrl = asset.browser_download_url || rollbackRelease.updateUrl;

    const publishedAt = new Date().toISOString();
    const manifest = { ...rollbackRelease, publishedAt };
    delete manifest.apkName;
    delete manifest.messageTh;
    delete manifest.messageEn;
    fs.writeFileSync(
      path.join(PUBLISH_DIR, 'release.json'),
      `${JSON.stringify(manifest, null, 2)}\n`,
      'utf8',
    );

    setJobStep(job, 'Record rollback release');
    const rollbackReleaseId = `${publishedAt.replace(/[^0-9]/g, '').slice(0, 14)}_${rollbackVersionCode}`;
    await patchFirestoreDocument(`app_releases/${rollbackReleaseId}`, {
      ...manifest,
      messageTh: rollbackRelease.messageTh,
      messageEn: rollbackRelease.messageEn,
      publishedAt: new Date(publishedAt),
    }, token);

    await enableRequiredUpdate(job, rollbackRelease, token, publishedAt);
    await deleteReleasesNewerThan(
      job,
      token,
      githubToken,
      targetVersionCode,
      rollbackReleaseId,
      rollbackRelease.releaseTag,
    );
    deleteLocalReleasesNewerThan(job, targetVersionCode, rollbackRelease.apkName);
    advanceMainBuildNumber(job, rollbackVersionCode);
    await cleanupStoredReleases(job, token, githubToken);

    job.state = 'success';
    job.step = 'Rollback sent to users';
    job.versionCode = rollbackVersionCode;
    job.result = manifest;
    logJob(job, `All installs below build ${rollbackVersionCode} must now install rollback v${release.versionName}.`);
  } catch (error) {
    job.state = 'failed';
    job.step = 'Failed';
    job.error = error.message;
    logJob(job, `ERROR: ${error.message}`);
  } finally {
    job.finishedAt = new Date().toISOString();
    persistReleaseState();
  }
}

async function verifyGitHubReleaseAsset(release, token) {
  const tag = release.releaseTag || githubReleaseTag(release.versionName, Number(release.versionCode));
  const githubRelease = await githubJson(
    `https://api.github.com/repos/${GITHUB_REPOSITORY}/releases/tags/${encodeURIComponent(tag)}`,
    token,
    { allow404: true },
  );
  if (!githubRelease) throw new Error(`GitHub release ${tag} was not found`);
  const url = String(release.updateUrl || '');
  const asset = (githubRelease.assets || []).find((item) => url.includes(encodeURIComponent(item.name)) || url.includes(item.name));
  if (!asset || asset.state !== 'uploaded') {
    throw new Error(`APK asset for ${tag} was not found`);
  }
}

async function enableRequiredUpdate(job, release, token, publishedAt) {
  setJobStep(job, 'Enable required update');
  const currentConfig = await getFirestoreDocument('app_config/android', token) || {};
  await patchFirestoreDocument('app_config/android', {
    minimumVersionCode: Number(release.versionCode),
    highestPublishedVersionCode: Math.max(
      Number(currentConfig.highestPublishedVersionCode || 0),
      Number(currentConfig.minimumVersionCode || 0),
      Number(release.versionCode),
    ),
    latestVersionName: release.versionName,
    updateUrl: release.updateUrl,
    messageTh: release.messageTh || 'มีเวอร์ชันใหม่ กรุณาอัปเดตก่อนใช้งาน',
    messageEn: release.messageEn || 'A new version is required. Please update to continue.',
    publishedAt: new Date(publishedAt),
    sha256: release.sha256 || '',
  }, token);
}

async function cleanupStoredReleases(job, token, githubToken) {
  try {
    await cleanupOldGitHubReleases(job, githubToken);
    await cleanupOldFirestoreReleases(job, token);
  } catch (error) {
    logJob(job, `Cleanup warning: ${error.message}`);
  }
}

function setJobStep(job, step) {
  job.step = step;
  persistReleaseState();
}

function logJob(job, line) {
  const safe = String(line).replace(/ya29\.[A-Za-z0-9._-]+/g, '[REDACTED]');
  job.logs.push({ at: new Date().toISOString(), line: safe.slice(0, 1000) });
  persistReleaseState();
}

function runCapturedCommand(executable, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(executable, args, {
      cwd: options.cwd || ROOT,
      shell: process.platform === 'win32',
      windowsHide: true,
      env: { ...process.env, CI: '1' },
    });
    let output = '';
    let errorOutput = '';
    child.stdout.on('data', (chunk) => { output += chunk.toString(); });
    child.stderr.on('data', (chunk) => { errorOutput += chunk.toString(); });
    if (options.input) child.stdin.end(options.input);
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) return resolve(output);
      const message = options.sensitive
        ? `${path.basename(executable)} failed with code ${code}`
        : (errorOutput || output || `command failed with code ${code}`).trim();
      reject(new Error(message));
    });
  });
}

function runLoggedCommand(job, executable, args, options = {}) {
  return new Promise((resolve, reject) => {
    logJob(job, `$ ${path.basename(executable)} ${args.join(' ')}`);
    const child = spawn(executable, args, {
      cwd: options.cwd || ROOT,
      shell: process.platform === 'win32',
      windowsHide: true,
      env: { ...process.env, CI: '1' },
    });
    const consume = (chunk) => {
      for (const line of chunk.toString().split(/\r?\n/)) {
        if (line.trim()) logJob(job, line.trim());
      }
    };
    child.stdout.on('data', consume);
    child.stderr.on('data', consume);
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${path.basename(executable)} exited with code ${code}`));
    });
  });
}

function serveStatic(request, response, pathname) {
  const requested = pathname === '/' ? 'index.html' : pathname.slice(1);
  const filePath = path.resolve(WEB_DIR, requested);
  if (!filePath.startsWith(`${WEB_DIR}${path.sep}`) || !fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    return false;
  }
  const extension = path.extname(filePath);
  const contentTypes = {
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.svg': 'image/svg+xml',
  };
  response.writeHead(200, {
    'Content-Type': contentTypes[extension] || 'application/octet-stream',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
    'Content-Security-Policy': "default-src 'self'; style-src 'self'; script-src 'self'; img-src 'self' data:; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'",
  });
  fs.createReadStream(filePath).pipe(response);
  return true;
}

const server = http.createServer(async (request, response) => {
  const url = new URL(request.url, `http://${request.headers.host || `${HOST}:${PORT}`}`);
  try {
    if (request.method === 'GET' && url.pathname === '/api/status') {
      return jsonResponse(response, 200, await statusPayload());
    }
    if (request.method === 'GET' && url.pathname === '/api/dashboard') {
      return jsonResponse(response, 200, await dashboardPayload(url.searchParams.get('days')));
    }
    if (request.method === 'GET' && url.pathname === '/api/release/status') {
      return jsonResponse(response, 200, { release: publicJob(activeJob) });
    }
    if (request.method === 'POST' && (url.pathname === '/api/release' || url.pathname === '/api/release/build')) {
      checkLocalMutation(request);
      const body = await readJsonBody(request);
      return jsonResponse(response, 202, { release: await beginBuild(body) });
    }
    if (request.method === 'POST' && url.pathname === '/api/release/publish') {
      checkLocalMutation(request);
      await readJsonBody(request);
      return jsonResponse(response, 202, { release: await beginPublish() });
    }
    if (request.method === 'POST' && url.pathname === '/api/release/send-existing') {
      checkLocalMutation(request);
      const body = await readJsonBody(request);
      return jsonResponse(response, 202, { release: await beginSendExisting(body) });
    }
    if (request.method === 'GET' && serveStatic(request, response, url.pathname)) return;
    errorResponse(response, 404, new Error('Not found'));
  } catch (error) {
    errorResponse(response, 400, error);
  }
});

if (require.main === module) {
  fs.mkdirSync(PUBLISH_DIR, { recursive: true });
  server.listen(PORT, HOST, () => {
    console.log(`Kimjod Release Center: http://${HOST}:${PORT}`);
    console.log(`Firebase project: ${PROJECT_ID}`);
  });
}

module.exports = { dashboardPayload, server, statusPayload };
