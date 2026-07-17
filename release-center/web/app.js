'use strict';

const featureLabels = {
  home: 'หน้าหลัก',
  scan: 'สแกนสลิป',
  analytics: 'วิเคราะห์',
  settings: 'ตั้งค่า',
  album_sync: 'ซิงก์อัลบั้ม',
};
const routeLabels = {
  chat: 'AI chat', analysis: 'วิเคราะห์', slip_analyze: 'อ่านสลิป',
  slip_amount: 'ตรวจยอด', voice_transcribe: 'ถอดเสียง', voice_transaction: 'Voice entry',
};
const chartColors = ['#43c79a', '#7685e6', '#ff907d', '#e0b752', '#5ba8dc', '#a17ad8'];
const AUTO_REFRESH_MS = 15000;

let formInitialized = false;
let pollingTimer = null;
let loading = false;
let stagedRelease = null;

const byId = (id) => document.getElementById(id);
const number = (value) => new Intl.NumberFormat('th-TH').format(Number(value || 0));
const compactNumber = (value) => new Intl.NumberFormat('en', { notation: 'compact', maximumFractionDigits: 1 }).format(Number(value || 0));

async function api(path, options) {
  const response = await fetch(path, options);
  const body = await response.json();
  if (!response.ok) throw new Error(body.error || `HTTP ${response.status}`);
  return body;
}

function showAlert(message) {
  const alert = byId('pageAlert');
  alert.textContent = message;
  alert.classList.remove('hidden');
}

function clearAlert() {
  byId('pageAlert').classList.add('hidden');
}

async function loadAll({ silent = false } = {}) {
  if (loading) return;
  loading = true;
  if (!silent) clearAlert();
  byId('refreshButton').disabled = true;
  try {
    const [status, dashboard] = await Promise.all([
      api('/api/status'),
      api('/api/dashboard?days=30'),
    ]);
    renderStatus(status);
    renderDashboard(dashboard);
    const time = new Date(dashboard.generatedAt).toLocaleTimeString('th-TH', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false });
    byId('syncStatus').textContent = `อัปเดต ${time} · auto 15s`;
  } catch (error) {
    showAlert(error.message);
    byId('syncStatus').textContent = 'เชื่อมต่อไม่สำเร็จ';
  } finally {
    loading = false;
    byId('refreshButton').disabled = false;
  }
}

function renderStatus(status) {
  byId('projectLabel').textContent = status.projectId;
  byId('currentVersion').textContent = `v${status.current.versionName}+${status.current.versionCode}`;
  byId('hostingLink').href = status.hostingUrl;
  if (!formInitialized) {
    byId('versionName').value = status.suggested.versionName;
    byId('versionCode').value = status.suggested.versionCode;
    formInitialized = true;
  }
  if (!status.tools.flutterFound || !status.tools.firebaseFound) {
    showAlert('ไม่พบ Flutter หรือ Firebase CLI กรุณาตรวจสอบ tool path ก่อน release');
  }
  if (status.updateConfig?.warning) showAlert(status.updateConfig.warning);
  renderStagedRelease(status.stagedRelease);
  if (status.release) renderJob(status.release);
}

function renderStagedRelease(release) {
  stagedRelease = release || null;
  const publishButton = byId('publishButton');
  const running = byId('jobState').classList.contains('running');
  publishButton.disabled = !stagedRelease || running;
  if (!stagedRelease) {
    byId('stageStatus').textContent = 'ยังไม่มี APK ที่พร้อมส่ง';
    return;
  }
  const size = stagedRelease.sizeBytes ? ` · ${(stagedRelease.sizeBytes / 1024 / 1024).toFixed(1)} MB` : '';
  byId('stageStatus').textContent = `พร้อมส่ง v${stagedRelease.versionName}+${stagedRelease.versionCode}${size}`;
}

function renderDashboard(data) {
  const summary = data.summary || {};
  const firebase = data.firebase || {};
  const ai = data.ai || { summary: {}, daily: [], models: [], routes: [] };
  byId('todayLabel').textContent = new Date().toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }).toUpperCase();
  byId('totalUsers').textContent = number(summary.totalUsers);
  byId('onlineNow').textContent = number(summary.onlineNow);
  byId('newUsersToday').textContent = `+${number(summary.newUsersToday)} บัญชีใหม่วันนี้`;
  byId('onlineContext').textContent = `${number(summary.activeToday)} active วันนี้`;
  byId('activeToday').textContent = number(summary.activeToday);
  byId('active7Days').textContent = number(summary.active7Days);
  byId('active30Days').textContent = number(summary.active30Days);
  byId('sessions30Days').textContent = number(summary.sessions30Days);
  byId('aiRequestsToday').textContent = number(ai.summary.requestsToday);
  byId('aiRequestContext').textContent = ai.summary.lastRequestAt ? `ล่าสุด ${relativeTime(ai.summary.lastRequestAt)}` : 'ยังไม่มี request วันนี้';
  byId('firebaseToday').textContent = number(firebase.todayDocuments || summary.activeToday);
  byId('firebaseContext').textContent = `${number(firebase.dailyDocuments)} daily docs ใน 30 วัน`;

  renderFirebase(firebase, data.warnings || []);
  renderAi(ai);
  renderDailyChart(data.daily || [], ai.daily || []);
  renderInsights(data.insights || []);
  renderFeatures(data.features || []);
  renderVersions(data.versions || []);
  renderLiveUsers(data.liveUsers || []);
  renderHistory(data.recentReleases || []);
  if (data.warnings?.length) showAlert(data.warnings.join(' | '));
}

function renderFirebase(firebase, warnings) {
  const cloud = firebase.cloud || {};
  byId('firebaseReads').textContent = cloud.available ? compactNumber(cloud.reads24h) : '—';
  byId('firebaseWrites').textContent = cloud.available ? compactNumber(cloud.writes24h) : '—';
  byId('firebaseStorage').textContent = cloud.available ? formatBytes(cloud.storageBytes) : '—';
  byId('firebaseConnections').textContent = cloud.available ? number(cloud.activeConnections) : '—';
  const health = byId('firebaseHealth');
  health.className = `health-pill ${warnings.length ? 'watch' : 'good'}`;
  health.innerHTML = `<i></i>${warnings.length ? 'Degraded' : 'Connected'}`;
  const age = firebase.lastHeartbeatAt ? Date.now() - Date.parse(firebase.lastHeartbeatAt) : Infinity;
  byId('firebaseFreshness').textContent = firebase.lastHeartbeatAt ? relativeTime(firebase.lastHeartbeatAt) : 'ยังไม่มี heartbeat';
  const freshness = age < 5 * 60e3 ? 100 : age < 15 * 60e3 ? 72 : age < 60 * 60e3 ? 38 : 8;
  byId('firebaseFreshnessBar').style.width = `${freshness}%`;
  byId('firebaseScope').textContent = cloud.available
    ? `Cloud Monitoring (อาจช้าได้ ~4 นาที) · ${number(firebase.authUsers)} Auth accounts · ${number(firebase.presenceDocuments)} presence docs · ไม่ใช่ยอด billing ขั้นสุดท้าย`
    : `Cloud Monitoring ไม่มีสิทธิ์หรือยังไม่มีข้อมูล · แสดง ${number(firebase.dailyDocuments)} telemetry docs จาก Firestore แทน`;
}

function formatBytes(value) {
  const bytes = Number(value || 0);
  if (bytes < 1024) return `${number(bytes)} B`;
  if (bytes < 1024 ** 2) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 ** 3) return `${(bytes / 1024 ** 2).toFixed(1)} MB`;
  return `${(bytes / 1024 ** 3).toFixed(2)} GB`;
}

function renderAi(ai) {
  const summary = ai.summary || {};
  byId('aiRequests').textContent = number(summary.requests);
  byId('aiSuccessRate').textContent = summary.successRate == null ? '—' : `${summary.successRate.toFixed(1)}%`;
  byId('aiLatency').textContent = summary.avgLatencyMs == null ? '—' : `${compactNumber(Math.round(summary.avgLatencyMs))} ms`;
  byId('aiTokens').textContent = compactNumber(summary.tokens);
  const health = byId('aiHealth');
  let tone = 'neutral';
  let label = summary.requests ? 'Partial data' : 'Idle';
  if (summary.measuredRequests > 0) {
    tone = summary.successRate >= 95 ? 'good' : 'danger';
    label = summary.successRate >= 95 ? 'Healthy' : 'Needs attention';
  }
  health.className = `health-pill ${tone}`;
  health.innerHTML = `<i></i>${label}`;
  renderChips('aiModels', ai.models || [], (name) => name.replace(/^gemini-/, ''));
  renderChips('aiRoutes', ai.routes || [], (name) => routeLabels[name] || name.replaceAll('_', ' '));
  byId('aiCoverage').textContent = summary.requests
    ? `Observability coverage ${Math.round(summary.observabilityCoverage || 0)}% · ${number(summary.inputTokens)} input + ${number(summary.outputTokens)} output tokens`
    : 'Token, latency และ success rate จะเริ่มแสดงหลังมีการเรียก AI backend';
}

function renderChips(id, items, labelFor) {
  const container = byId(id);
  container.replaceChildren();
  if (!items.length) {
    const empty = document.createElement('em');
    empty.textContent = 'ยังไม่มีข้อมูล';
    container.append(empty);
    return;
  }
  items.slice(0, 3).forEach((item) => {
    const chip = document.createElement('span');
    chip.textContent = `${labelFor(item.name)} · ${number(item.count)}`;
    container.append(chip);
  });
}

function renderDailyChart(daily, aiDaily) {
  const container = byId('dailyChart');
  container.replaceChildren();
  if (!daily.length) {
    container.innerHTML = '<div class="empty-chart">ยังไม่มี usage data</div>';
    return;
  }
  const aiByDay = Object.fromEntries(aiDaily.map((item) => [item.day, item.requests]));
  const series = daily.map((item) => ({ ...item, aiRequests: aiByDay[item.day] || 0 }));
  const width = 820;
  const height = 288;
  const padding = { left: 32, right: 12, top: 16, bottom: 31 };
  const maxUsers = Math.max(4, ...series.map((item) => item.activeUsers));
  const maxAi = Math.max(4, ...series.map((item) => item.aiRequests));
  const chartWidth = width - padding.left - padding.right;
  const chartHeight = height - padding.top - padding.bottom;
  const pointsFor = (field, max) => series.map((item, index) => ({
    x: padding.left + (series.length === 1 ? chartWidth / 2 : index * chartWidth / (series.length - 1)),
    y: padding.top + chartHeight - (item[field] / max) * chartHeight,
  }));
  const userPoints = pointsFor('activeUsers', maxUsers);
  const aiPoints = pointsFor('aiRequests', maxAi);
  const pathFor = (points) => points.map((item, index) => `${index ? 'L' : 'M'} ${item.x.toFixed(2)} ${item.y.toFixed(2)}`).join(' ');
  const userPath = pathFor(userPoints);
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('viewBox', `0 0 ${width} ${height}`);
  svg.innerHTML = '<defs><linearGradient id="areaGradient" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#77d9b7" stop-opacity=".34"/><stop offset="100%" stop-color="#77d9b7" stop-opacity="0"/></linearGradient></defs>';
  for (let index = 0; index <= 4; index += 1) {
    const y = padding.top + chartHeight * index / 4;
    appendSvg(svg, 'line', { x1: padding.left, x2: width - padding.right, y1: y, y2: y, class: 'grid-line' });
    const label = appendSvg(svg, 'text', { x: 1, y: y + 3, class: 'axis-label' });
    label.textContent = Math.round(maxUsers * (1 - index / 4));
  }
  appendSvg(svg, 'path', { d: `${userPath} L ${userPoints.at(-1).x} ${padding.top + chartHeight} L ${userPoints[0].x} ${padding.top + chartHeight} Z`, class: 'chart-area' });
  appendSvg(svg, 'path', { d: userPath, class: 'chart-line' });
  appendSvg(svg, 'path', { d: pathFor(aiPoints), class: 'ai-chart-line' });
  userPoints.forEach((point, index) => {
    const circle = appendSvg(svg, 'circle', { cx: point.x, cy: point.y, r: index === userPoints.length - 1 ? 4 : 2.1, class: 'chart-dot' });
    const title = appendSvg(circle, 'title', {});
    title.textContent = `${series[index].day}: ${series[index].activeUsers} users · ${series[index].sessions} sessions · ${series[index].aiRequests} AI requests`;
    appendSvg(svg, 'circle', { cx: aiPoints[index].x, cy: aiPoints[index].y, r: 1.8, class: 'ai-chart-dot' });
    if (index % 6 === 0 || index === userPoints.length - 1) {
      const label = appendSvg(svg, 'text', { x: point.x, y: height - 7, 'text-anchor': 'middle', class: 'axis-label' });
      label.textContent = series[index].day.slice(5).replace('-', '/');
    }
  });
  container.append(svg);
}

function appendSvg(parent, tag, attributes) {
  const element = document.createElementNS('http://www.w3.org/2000/svg', tag);
  Object.entries(attributes).forEach(([key, value]) => element.setAttribute(key, value));
  parent.append(element);
  return element;
}

function renderInsights(insights) {
  const container = byId('insightList');
  container.replaceChildren();
  if (!insights.length) {
    container.innerHTML = '<p class="empty">ยังไม่มีข้อมูลเพียงพอสำหรับวิเคราะห์</p>';
    return;
  }
  insights.forEach((insight) => {
    const item = document.createElement('div');
    item.className = `insight-item ${insight.tone || 'neutral'}`;
    const title = document.createElement('strong');
    title.textContent = insight.title;
    const detail = document.createElement('p');
    detail.textContent = insight.detail;
    item.append(title, detail);
    container.append(item);
  });
}

function renderFeatures(features) {
  const legend = byId('featureLegend');
  const donut = byId('featureDonut');
  legend.replaceChildren();
  const total = features.reduce((sum, item) => sum + item.count, 0);
  donut.querySelector('strong').textContent = compactNumber(total);
  if (!total) {
    donut.style.background = '#e8efec';
    legend.innerHTML = '<p class="empty">ยังไม่มี feature event</p>';
    return;
  }
  let accumulated = 0;
  const segments = features.slice(0, 6).map((item, index) => {
    const start = accumulated;
    accumulated += item.count / total * 100;
    return `${chartColors[index]} ${start}% ${accumulated}%`;
  });
  donut.style.background = `conic-gradient(${segments.join(',')})`;
  features.slice(0, 6).forEach((item, index) => {
    const row = document.createElement('div');
    row.className = 'legend-row';
    const marker = document.createElement('i');
    marker.style.background = chartColors[index];
    const label = document.createElement('span');
    label.textContent = featureLabels[item.name] || item.name;
    const count = document.createElement('strong');
    count.textContent = compactNumber(item.count);
    row.append(marker, label, count);
    legend.append(row);
  });
}

function renderVersions(versions) {
  const container = byId('versionBars');
  container.replaceChildren();
  if (!versions.length) {
    container.innerHTML = '<p class="empty">ยังไม่มี version telemetry</p>';
    return;
  }
  const max = Math.max(...versions.map((item) => item.count));
  versions.slice(0, 7).forEach((item) => {
    const row = document.createElement('div');
    row.className = 'bar-row';
    const label = document.createElement('span');
    label.textContent = `v${item.name}`;
    const track = document.createElement('div');
    track.className = 'bar-track';
    const bar = document.createElement('i');
    bar.style.width = `${item.count / max * 100}%`;
    track.append(bar);
    const count = document.createElement('strong');
    count.textContent = number(item.count);
    row.append(label, track, count);
    container.append(row);
  });
}

function renderLiveUsers(users) {
  const container = byId('liveUsers');
  container.replaceChildren();
  if (!users.length) {
    container.innerHTML = '<p class="empty">ยังไม่มี heartbeat</p>';
    return;
  }
  users.forEach((user) => {
    const row = document.createElement('div');
    row.className = 'activity-row';
    const identity = document.createElement('div');
    identity.className = 'activity-user';
    const avatar = document.createElement('span');
    avatar.className = 'avatar';
    avatar.textContent = user.user.slice(-2);
    const copy = document.createElement('div');
    const name = document.createElement('strong');
    name.textContent = user.user;
    const meta = document.createElement('small');
    meta.textContent = `${user.platform} · v${user.versionName}`;
    copy.append(name, meta);
    identity.append(avatar, copy);
    const time = document.createElement('time');
    time.textContent = relativeTime(user.lastSeenAt);
    row.append(identity, time);
    container.append(row);
  });
}

function relativeTime(value) {
  const elapsed = Math.max(0, Date.now() - Date.parse(value));
  if (!Number.isFinite(elapsed)) return 'ไม่ทราบเวลา';
  if (elapsed < 60e3) return 'เมื่อสักครู่';
  if (elapsed < 60 * 60e3) return `${Math.floor(elapsed / 60e3)} นาทีที่แล้ว`;
  if (elapsed < 24 * 60 * 60e3) return `${Math.floor(elapsed / 3600e3)} ชม.ที่แล้ว`;
  return `${Math.floor(elapsed / 86400e3)} วันที่แล้ว`;
}

function renderHistory(releases) {
  const container = byId('releaseHistory');
  container.replaceChildren();
  if (!releases.length) {
    container.innerHTML = '<p class="empty">ยังไม่มี release ที่เผยแพร่จาก Control Room</p>';
    return;
  }
  releases.forEach((release) => {
    const row = document.createElement('div');
    row.className = 'release-row';
    const version = document.createElement('strong');
    version.textContent = `v${release.versionName}+${release.versionCode}`;
    const size = document.createElement('span');
    size.textContent = release.sizeBytes ? `${(release.sizeBytes / 1024 / 1024).toFixed(1)} MB` : '—';
    const link = document.createElement('a');
    link.href = release.updateUrl || '#';
    link.target = '_blank';
    link.rel = 'noreferrer';
    link.textContent = release.updateUrl || 'ไม่มี URL';
    const time = document.createElement('time');
    time.textContent = release.publishedAt ? new Date(release.publishedAt).toLocaleString('th-TH', { dateStyle: 'short', timeStyle: 'short' }) : '—';
    const sendButton = document.createElement('button');
    sendButton.className = 'mini-button send-existing-button';
    sendButton.type = 'button';
    sendButton.dataset.releaseId = release.id || '';
    sendButton.dataset.version = `${release.versionName}+${release.versionCode}`;
    sendButton.disabled = !release.id;
    sendButton.textContent = 'ส่ง';
    row.append(version, size, link, time, sendButton);
    container.append(row);
  });
}

function renderJob(job) {
  if (!job) return;
  const state = byId('jobState');
  state.className = `job-state ${job.state}`;
  const stateLabels = { running: 'กำลังทำงาน', success: 'สำเร็จ', failed: 'ล้มเหลว' };
  state.textContent = stateLabels[job.state] || 'พร้อม';
  byId('jobStep').textContent = job.step;
  const progress = job.state === 'success' || job.state === 'failed' ? 100 : progressForStep(job.step);
  byId('pipelineProgress').style.width = `${progress}%`;
  const terminal = byId('releaseLogs');
  terminal.replaceChildren();
  job.logs.forEach((entry) => {
    const row = document.createElement('p');
    const time = document.createElement('time');
    time.textContent = new Date(entry.at).toLocaleTimeString('th-TH', { hour12: false });
    row.append(time, document.createTextNode(entry.line));
    terminal.append(row);
  });
  terminal.scrollTop = terminal.scrollHeight;
  const running = job.state === 'running';
  byId('releaseButton').disabled = running;
  byId('publishButton').disabled = running || !stagedRelease;
  document.querySelectorAll('.send-existing-button').forEach((button) => { button.disabled = running || !button.dataset.releaseId; });
  byId('releaseButtonText').textContent = running && job.action === 'build' ? job.step : 'Build APK';
  byId('publishButtonText').textContent = running && job.action === 'publish' ? job.step : 'ส่งอัปเดตให้ผู้ใช้';
  if (job.state === 'failed') showAlert(`Release ล้มเหลว: ${job.error}`);
  if (!running && pollingTimer) {
    clearInterval(pollingTimer);
    pollingTimer = null;
    if (job.state === 'success') { formInitialized = false; loadAll(); }
  }
}

function progressForStep(step) {
  const steps = ['Prepare', 'Check', 'Update version', 'Build', 'Prepare files', 'Deploy', 'Record release', 'Enable required update', 'Cleanup', 'Ready', 'Sent'];
  const index = steps.findIndex((item) => step.includes(item));
  return index < 0 ? 8 : Math.max(8, index / (steps.length - 1) * 100);
}

async function pollJob() {
  try {
    const result = await api('/api/release/status');
    renderJob(result.release);
  } catch (error) { showAlert(error.message); }
}

byId('refreshButton').addEventListener('click', () => loadAll());
byId('releaseForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  clearAlert();
  byId('releaseButton').disabled = true;
  try {
    const payload = {
      versionName: byId('versionName').value.trim(),
      versionCode: Number(byId('versionCode').value),
      messageTh: byId('messageTh').value.trim(),
      messageEn: byId('messageEn').value.trim(),
    };
    const result = await api('/api/release/build', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
    renderJob(result.release);
    pollingTimer = setInterval(pollJob, 1800);
  } catch (error) { byId('releaseButton').disabled = false; showAlert(error.message); }
});

byId('publishButton').addEventListener('click', async () => {
  clearAlert();
  byId('publishButton').disabled = true;
  try {
    const result = await api('/api/release/publish', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
    renderJob(result.release);
    pollingTimer = setInterval(pollJob, 1800);
  } catch (error) { byId('publishButton').disabled = !stagedRelease; showAlert(error.message); }
});

byId('releaseHistory').addEventListener('click', async (event) => {
  const button = event.target.closest('.send-existing-button');
  if (!button) return;
  const ok = window.confirm(`ส่ง v${button.dataset.version} ให้ผู้ใช้หรือไม่?\n\nAndroid จะไม่ downgrade เครื่องที่มี versionCode สูงกว่า`);
  if (!ok) return;
  clearAlert();
  button.disabled = true;
  try {
    const result = await api('/api/release/send-existing', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ releaseId: button.dataset.releaseId }) });
    renderJob(result.release);
    pollingTimer = setInterval(pollJob, 1800);
  } catch (error) { button.disabled = false; showAlert(error.message); }
});

document.querySelectorAll('.nav-link').forEach((link) => {
  link.addEventListener('click', () => {
    document.querySelectorAll('.nav-link').forEach((item) => item.classList.toggle('active', item === link));
  });
});
document.addEventListener('visibilitychange', () => { if (!document.hidden) loadAll({ silent: true }); });
setInterval(() => loadAll({ silent: true }), AUTO_REFRESH_MS);
loadAll();
