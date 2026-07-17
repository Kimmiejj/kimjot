'use strict';

const featureLabels = {
  home: 'Home',
  scan: 'Slip scan',
  analytics: 'Analytics',
  settings: 'Settings',
  album_sync: 'Album sync',
};
const chartColors = ['#43c79a', '#7685e6', '#ff907d', '#e0b752', '#5ba8dc', '#a17ad8'];
const AUTO_REFRESH_MS = 15000;

let formInitialized = false;
let pollingTimer = null;
let autoRefreshTimer = null;
let loading = false;
let stagedRelease = null;

const byId = (id) => document.getElementById(id);
const number = (value) => new Intl.NumberFormat('th-TH').format(Number(value || 0));

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
    byId('syncStatus').textContent = `Synced ${new Date(dashboard.generatedAt).toLocaleTimeString('th-TH', { hour12: false })}`;
  } catch (error) {
    showAlert(error.message);
    byId('syncStatus').textContent = 'Sync failed';
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
    showAlert('Flutter or Firebase CLI was not found. Check the tool paths before releasing.');
  }
  if (status.updateConfig?.warning) {
    showAlert(status.updateConfig.warning);
  }
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
  const size = stagedRelease.sizeBytes
    ? ` • ${(stagedRelease.sizeBytes / 1024 / 1024).toFixed(1)} MB`
    : '';
  byId('stageStatus').textContent = `พร้อมส่ง v${stagedRelease.versionName}+${stagedRelease.versionCode}${size}`;
}

function renderDashboard(data) {
  const summary = data.summary;
  byId('totalUsers').textContent = number(summary.totalUsers);
  byId('onlineNow').textContent = number(summary.onlineNow);
  byId('active7Days').textContent = number(summary.active7Days);
  byId('sessions30Days').textContent = number(summary.sessions30Days);
  byId('newUsersToday').textContent = `New today ${number(summary.newUsersToday)}`;
  byId('activeToday').textContent = `Today ${number(summary.activeToday)}`;
  byId('active30Days').textContent = `Active 30 days ${number(summary.active30Days)}`;
  if (data.warnings?.length) showAlert(data.warnings.join(' | '));
  renderDailyChart(data.daily);
  renderFeatures(data.features);
  renderVersions(data.versions);
  renderHistory(data.recentReleases);
}

function renderDailyChart(daily) {
  const container = byId('dailyChart');
  container.replaceChildren();
  if (!daily.length) {
    container.innerHTML = '<div class="empty-chart">No usage data yet</div>';
    return;
  }
  const width = 760;
  const height = 315;
  const padding = { left: 34, right: 16, top: 18, bottom: 35 };
  const max = Math.max(4, ...daily.map((item) => item.activeUsers));
  const chartWidth = width - padding.left - padding.right;
  const chartHeight = height - padding.top - padding.bottom;
  const point = (item, index) => ({
    x: padding.left + (daily.length === 1 ? chartWidth / 2 : index * chartWidth / (daily.length - 1)),
    y: padding.top + chartHeight - (item.activeUsers / max) * chartHeight,
  });
  const points = daily.map(point);
  const pathData = points.map((item, index) => `${index ? 'L' : 'M'} ${item.x.toFixed(2)} ${item.y.toFixed(2)}`).join(' ');
  const areaData = `${pathData} L ${points.at(-1).x} ${padding.top + chartHeight} L ${points[0].x} ${padding.top + chartHeight} Z`;
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('viewBox', `0 0 ${width} ${height}`);
  svg.innerHTML = '<defs><linearGradient id="areaGradient" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#77d9b7" stop-opacity=".38"/><stop offset="100%" stop-color="#77d9b7" stop-opacity="0"/></linearGradient></defs>';
  for (let index = 0; index <= 4; index += 1) {
    const y = padding.top + chartHeight * index / 4;
    const line = document.createElementNS(svg.namespaceURI, 'line');
    line.setAttribute('x1', padding.left);
    line.setAttribute('x2', width - padding.right);
    line.setAttribute('y1', y);
    line.setAttribute('y2', y);
    line.setAttribute('class', 'grid-line');
    svg.append(line);
    const label = document.createElementNS(svg.namespaceURI, 'text');
    label.setAttribute('x', 2);
    label.setAttribute('y', y + 4);
    label.setAttribute('class', 'axis-label');
    label.textContent = Math.round(max * (1 - index / 4));
    svg.append(label);
  }
  const area = document.createElementNS(svg.namespaceURI, 'path');
  area.setAttribute('d', areaData);
  area.setAttribute('class', 'chart-area');
  svg.append(area);
  const line = document.createElementNS(svg.namespaceURI, 'path');
  line.setAttribute('d', pathData);
  line.setAttribute('class', 'chart-line');
  svg.append(line);
  points.forEach((item, index) => {
    const circle = document.createElementNS(svg.namespaceURI, 'circle');
    circle.setAttribute('cx', item.x);
    circle.setAttribute('cy', item.y);
    circle.setAttribute('r', index === points.length - 1 ? 4.5 : 2.4);
    circle.setAttribute('class', 'chart-dot');
    const title = document.createElementNS(svg.namespaceURI, 'title');
    title.textContent = `${daily[index].day}: ${daily[index].activeUsers} users / ${daily[index].sessions} sessions`;
    circle.append(title);
    svg.append(circle);
    if (index % 5 === 0 || index === points.length - 1) {
      const label = document.createElementNS(svg.namespaceURI, 'text');
      label.setAttribute('x', item.x);
      label.setAttribute('y', height - 8);
      label.setAttribute('text-anchor', 'middle');
      label.setAttribute('class', 'axis-label');
      label.textContent = daily[index].day.slice(5).replace('-', '/');
      svg.append(label);
    }
  });
  container.append(svg);
}

function renderFeatures(features) {
  const legend = byId('featureLegend');
  const donut = byId('featureDonut');
  legend.replaceChildren();
  const total = features.reduce((sum, item) => sum + item.count, 0);
  donut.querySelector('strong').textContent = number(total);
  if (!total) {
    donut.style.background = '#e8efec';
    const empty = document.createElement('p');
    empty.className = 'empty';
    empty.textContent = 'Feature usage will appear after users open telemetry-enabled builds.';
    legend.append(empty);
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
    count.textContent = number(item.count);
    row.append(marker, label, count);
    legend.append(row);
  });
}

function renderVersions(versions) {
  const container = byId('versionBars');
  container.replaceChildren();
  if (!versions.length) {
    container.innerHTML = '<p class="empty">No version telemetry yet</p>';
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

function renderHistory(releases) {
  const container = byId('releaseHistory');
  container.replaceChildren();
  if (!releases.length) {
    container.innerHTML = '<p class="empty">No releases published from this center yet</p>';
    return;
  }
  releases.forEach((release) => {
    const row = document.createElement('div');
    row.className = 'release-row';
    const version = document.createElement('strong');
    version.textContent = `v${release.versionName}+${release.versionCode}`;
    const size = document.createElement('span');
    size.textContent = release.sizeBytes ? `${(release.sizeBytes / 1024 / 1024).toFixed(1)} MB` : '-';
    const link = document.createElement('a');
    link.href = release.updateUrl || '#';
    link.target = '_blank';
    link.rel = 'noreferrer';
    link.textContent = release.updateUrl || 'No URL';
    const time = document.createElement('time');
    time.textContent = release.publishedAt ? new Date(release.publishedAt).toLocaleString('th-TH', { dateStyle: 'short', timeStyle: 'short' }) : '-';
    row.append(version, size, link, time);
    container.append(row);
  });
}

function renderJob(job) {
  if (!job) return;
  const state = byId('jobState');
  state.className = `job-state ${job.state}`;
  const stateLabels = { running: 'Running', success: 'Success', failed: 'Failed' };
  state.textContent = stateLabels[job.state] || 'Ready';
  byId('jobStep').textContent = job.step;
  const progress = job.state === 'success' ? 100 : job.state === 'failed' ? 100 : progressForStep(job.step);
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
  byId('releaseButtonText').textContent = running && job.action === 'build' ? job.step : 'Build APK';
  byId('publishButtonText').textContent = running && job.action === 'publish' ? job.step : 'ส่งอัปเดตให้ผู้ใช้';
  if (job.state === 'failed') showAlert(`Release failed: ${job.error}`);
  if (!running && pollingTimer) {
    clearInterval(pollingTimer);
    pollingTimer = null;
    if (job.state === 'success') {
      formInitialized = false;
      loadAll();
    }
  }
}

function progressForStep(step) {
  const steps = ['Prepare', 'Check', 'Update version', 'Build', 'Prepare files', 'Deploy', 'Record release', 'Enable required update', 'Ready', 'Sent'];
  const index = steps.findIndex((item) => step.includes(item));
  return index < 0 ? 8 : Math.max(8, index / (steps.length - 1) * 100);
}

async function pollJob() {
  try {
    const result = await api('/api/release/status');
    renderJob(result.release);
  } catch (error) {
    showAlert(error.message);
  }
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
    const result = await api('/api/release/build', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    renderJob(result.release);
    pollingTimer = setInterval(pollJob, 1800);
  } catch (error) {
    byId('releaseButton').disabled = false;
    showAlert(error.message);
  }
});

byId('publishButton').addEventListener('click', async () => {
  clearAlert();
  byId('publishButton').disabled = true;
  try {
    const result = await api('/api/release/publish', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{}',
    });
    renderJob(result.release);
    pollingTimer = setInterval(pollJob, 1800);
  } catch (error) {
    byId('publishButton').disabled = !stagedRelease;
    showAlert(error.message);
  }
});

document.addEventListener('visibilitychange', () => {
  if (!document.hidden) loadAll({ silent: true });
});

autoRefreshTimer = setInterval(() => loadAll({ silent: true }), AUTO_REFRESH_MS);
loadAll();
