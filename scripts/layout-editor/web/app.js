import {Canvas, clone, drawArtwork, svg} from './canvas.js';
const $ = selector => document.querySelector(selector);
const clientId = crypto.randomUUID(); // Never shared through localStorage/sessionStorage: copied tabs need new identities.
const state = {doc: null, page: null, selected: new Set(), token: null, revision: 0, dirty: false, sequence: 0,
  connected: false, conflict: false, transition: false, undo: [], redo: [], csrf: '', saveFlight: null};
let saveTimer, toastTimer, polling = false, heartbeat = false, assetSignature = '', pageSignature = '';
const canEdit = () => Boolean(state.page && state.token && state.connected && !state.conflict && !state.transition);
const canvas = new Canvas(state, {canEdit, select, commit});
const icon = name => `<svg aria-hidden="true"><use href="#i-${name}"/></svg>`;
function toast(message) { $('#toast').textContent = message; $('#toast').hidden = false; clearTimeout(toastTimer); toastTimer = setTimeout(() => $('#toast').hidden = true, 4800); }
function fail(error) { toast(error.message || String(error)); }
async function request(path, data, raw = false) {
  const options = data === undefined ? {} : {method: 'POST', headers: {'X-Editor-Token': state.csrf, 'Content-Type': raw ? 'application/octet-stream' : 'application/json'}, body: raw ? data : JSON.stringify(data)};
  const response = await fetch(path, {...options, signal: AbortSignal.timeout(15000)});
  const result = await response.json();
  if (!response.ok) { const error = new Error(result.error || '请求失败'); error.status = response.status; throw error; }
  return result;
}
const context = () => ({clientId, epoch: state.doc.epoch, pageId: state.page?.id, token: state.token});
function status() {
  let message = '已保存到本机', bad = false;
  if (!state.connected) { message = '连接中断 · 请保留窗口'; bad = true; }
  else if (state.conflict) { message = '未保存 · 需要核对最新版本'; bad = true; }
  else if (state.dirty || state.saveFlight || canvas.gesture) message = '正在保存…';
  else if (!state.token) message = '实时查看 · 已同步';
  $('#save-status').replaceChildren();
  $('#save-status').append(document.createElement('i'), document.createTextNode(message));
  $('#save-status').classList.toggle('error', bad);
  $('#connection-banner').hidden = Boolean(state.token && state.connected && !state.conflict);
  $('#banner-text').textContent = !state.connected ? '本机服务暂时断开。请保持启动窗口运行，当前未保存内容保留在此窗口。' : state.conflict ? '编辑会话或页面版本已变化。旧修改未覆盖新成果；可先下载未保存布局，再载入最新版本。' : '此页为实时查看。释放编辑权后，可在这里继续排版。';
  $('#acquire').hidden = Boolean(state.token || state.conflict || !state.connected);
  $('#recover').hidden = !state.conflict;
  $('#save-draft').hidden = !state.dirty && !state.conflict;
  $('#window-status').textContent = state.token && !state.conflict ? '本窗口编辑此页 · 其他窗口实时查看' : '页面独立 · 素材共享';
  $('#release').disabled = !canEdit();
  $('#rename-page').disabled = !canEdit();
  $('#undo').disabled = !canEdit() || !state.undo.length;
  $('#redo').disabled = !canEdit() || !state.redo.length;
  const selected = canvas.items();
  const editable = canEdit() && selected.length && !selected.some(item => item.locked);
  for (const id of ['delete', 'duplicate']) $(`#${id}`).disabled = !editable;
  $('#group').disabled = !editable || selected.length < 2;
  $('#selection-label').textContent = selected.length ? `${selected.length} 个图层已选中${selected.some(item => item.locked) ? ' · 已锁定' : ''}` : '点击物件开始排版 · Shift 多选';
}
function selectedGroup(id) {
  const item = state.page.layers.find(layer => layer.id === id);
  return item ? state.page.layers.filter(layer => item.groupId ? layer.groupId === item.groupId : layer.id === id).map(layer => layer.id) : [];
}
function select(id, additive) {
  if (!state.page) return;
  const ids = id ? selectedGroup(id) : [];
  if (!additive) state.selected.clear();
  const remove = additive && ids.every(key => state.selected.has(key));
  for (const key of ids) remove ? state.selected.delete(key) : state.selected.add(key);
  renderLayers(); canvas.drawSelection(); status();
}
function renderPages() {
  const signature = JSON.stringify([state.doc.pages.map(page => [page.id, page.name]), state.page?.id, state.doc.leases]);
  if (signature === pageSignature) return;
  pageSignature = signature;
  $('#pages').replaceChildren();
  $('#page-count').textContent = String(state.doc.pages.length).padStart(2, '0');
  for (const [index, page] of state.doc.pages.entries()) {
    const button = document.createElement('button');
    button.className = `page-row${page.id === state.page?.id ? ' active' : ''}`;
    button.dataset.pageId = page.id;
    button.innerHTML = `${icon('page')}<span class="name"></span><small>${String(index + 1).padStart(2, '0')}</small>`;
    button.querySelector('.name').textContent = page.name;
    if (state.doc.leases[page.id]?.owner !== clientId && state.doc.leases[page.id]) {
      const dot = document.createElement('span'); dot.className = 'lock-dot'; dot.title = '另一窗口正在编辑'; button.append(dot);
    }
    button.onclick = () => switchPage(page.id).catch(fail);
    $('#pages').append(button);
  }
}
function renderAssets() {
  const query = $('#asset-search').value.trim().toLowerCase();
  const signature = JSON.stringify([state.doc.epoch, state.doc.assets, query]);
  if (signature === assetSignature) return;
  assetSignature = signature;
  $('#assets').replaceChildren();
  $('#asset-count').textContent = state.doc.assets.length;
  $('#assets-empty').hidden = state.doc.assets.length > 0;
  for (const asset of state.doc.assets.filter(item => item.name.toLowerCase().includes(query))) {
    const button = document.createElement('button'); button.className = 'asset-card'; button.dataset.assetId = asset.id;
    button.title = `${asset.name} · ${asset.width} × ${asset.height} · 点击添加`;
    const thumb = document.createElement('div'); thumb.className = 'asset-thumb';
    const image = document.createElement('img'); image.src = `/api/asset/${asset.id}?v=${state.doc.epoch}`; image.alt = ''; image.draggable = false; image.loading = 'lazy';
    const name = document.createElement('span'); name.textContent = asset.name;
    thumb.append(image); button.append(thumb, name); button.onclick = () => addAsset(asset); $('#assets').append(button);
  }
}
let dragged = null;
function renderLayers() {
  if (!state.page) return;
  $('#layers').replaceChildren();
  $('#layers-empty').hidden = state.page.layers.length > 0;
  $('#layer-count').textContent = state.page.layers.length;
  for (const item of [...state.page.layers].reverse()) {
    const row = document.createElement('div'); row.className = `layer-row${state.selected.has(item.id) ? ' selected' : ''}${!item.visible ? ' dim' : ''}${item.groupId ? ' grouped' : ''}`;
    row.dataset.id = item.id; row.draggable = canEdit() && !item.locked;
    row.tabIndex = 0; row.setAttribute('role', 'button'); row.setAttribute('aria-label', item.name);
    const image = document.createElement('img'); image.className = 'layer-thumb'; image.src = `/api/asset/${item.assetId}?v=${state.doc.epoch}`; image.draggable = false; image.alt = '';
    const name = document.createElement('span'); name.className = 'layer-name'; name.textContent = item.name; name.title = item.name + (item.groupId ? ' · 已成组' : '');
    row.append(image, name);
    for (const [kind, glyph, label] of [['visible', item.visible ? 'eye' : 'hide', item.visible ? '隐藏' : '显示'], ['locked', item.locked ? 'lock' : 'unlock', item.locked ? '解锁' : '锁定']]) {
      const button = document.createElement('button'); button.className = `icon${item[kind] ? ' active' : ''}`; button.innerHTML = icon(glyph); button.title = `${label} ${item.name}`; button.setAttribute('aria-label', `${label} ${item.name}`); button.disabled = !canEdit();
      button.onclick = event => { event.stopPropagation(); const value = !item[kind]; mutate(page => { for (const id of selectedGroup(item.id)) page.layers.find(layer => layer.id === id)[kind] = value; }); };
      row.append(button);
    }
    row.onclick = event => select(item.id, event.shiftKey || event.ctrlKey || event.metaKey);
    row.onkeydown = event => { if (event.key === 'Enter') select(item.id, event.shiftKey); };
    row.ondragstart = event => { if (!row.draggable) return event.preventDefault(); dragged = item.id; event.dataTransfer.setData('text/plain', item.id); event.dataTransfer.effectAllowed = 'move'; };
    row.ondragover = event => { if (dragged && canEdit()) { event.preventDefault(); row.classList.add('drag-over'); } };
    row.ondragleave = () => row.classList.remove('drag-over');
    row.ondragend = () => { dragged = null; document.querySelectorAll('.drag-over').forEach(node => node.classList.remove('drag-over')); };
    row.ondrop = event => {
      event.preventDefault(); row.classList.remove('drag-over');
      const source = dragged; dragged = null;
      if (!source || !canEdit()) return;
      const ids = selectedGroup(source), targets = selectedGroup(item.id);
      if (ids.includes(item.id) || state.page.layers.some(layer => ids.includes(layer.id) && layer.locked)) return;
      const upper = event.clientY < row.getBoundingClientRect().top + row.clientHeight / 2;
      mutate(page => {
        const moving = page.layers.filter(layer => ids.includes(layer.id));
        page.layers = page.layers.filter(layer => !ids.includes(layer.id));
        const positions = targets.map(id => page.layers.findIndex(layer => layer.id === id));
        page.layers.splice(upper ? Math.max(...positions) + 1 : Math.min(...positions), 0, ...moving);
      });
    };
    $('#layers').append(row);
  }
}
function render() {
  if (!state.doc || !state.page) return;
  $('#current-name').textContent = state.page.name;
  $('.page-heading>.subtle').textContent = `${state.page.width} × ${state.page.height}`;
  state.selected = new Set([...state.selected].filter(id => state.page.layers.some(item => item.id === id)));
  renderPages(); renderAssets(); renderLayers(); canvas.render(); status();
}
function commit(before) {
  if (!canEdit()) { state.page = before; canvas.render(); return; }
  if (JSON.stringify(before) === JSON.stringify(state.page)) return;
  state.undo.push(before); if (state.undo.length > 100) state.undo.shift(); state.redo = [];
  changed();
}
function changed() { state.dirty = true; state.sequence++; render(); clearTimeout(saveTimer); saveTimer = setTimeout(() => save().catch(fail), 220); }
function mutate(operation) {
  if (!canEdit()) { toast('先取得本页编辑权，再调整画面。'); return; }
  if (canvas.gesture) return;
  const before = clone(state.page); operation(state.page); commit(before);
}
async function save() {
  if (state.saveFlight) { await state.saveFlight; return; }
  if (!state.dirty) return;
  if (canvas.gesture) { clearTimeout(saveTimer); saveTimer = setTimeout(() => save().catch(fail), 220); return; }
  if (!canEdit()) throw new Error('当前修改尚未保存，请先恢复连接或核对页面版本。');
  const page = clone(state.page), sequence = state.sequence;
  state.saveFlight = (async () => {
    try {
      const result = await request('/api/save', {...context(), page, revision: state.revision});
      state.revision = result.page.revision;
      state.page.revision = state.revision;
      state.dirty = state.sequence !== sequence;
    } catch (error) {
      state.conflict = true;
      if (!error.status) state.connected = false;
      throw error;
    } finally { state.saveFlight = null; status(); }
  })();
  status(); await state.saveFlight;
  if (state.dirty) { clearTimeout(saveTimer); saveTimer = setTimeout(() => save().catch(fail), 100); }
}
async function flush() {
  if (canvas.gesture) throw new Error('请先松开正在拖动的物件。');
  clearTimeout(saveTimer);
  if (state.saveFlight) await state.saveFlight;
  while (state.dirty) await save();
  if (state.conflict) throw new Error('请先核对最新页面版本。');
}
async function release() {
  await flush();
  if (state.token) await request('/api/release', context());
  state.token = null; state.undo = []; state.redo = []; render();
}
function installPage(page) { state.page = clone(page); state.revision = page.revision; state.dirty = false; state.conflict = false; state.selected.clear(); state.undo = []; state.redo = []; }
async function acquire() {
  if (state.dirty || state.conflict) throw new Error('请先保存或处理未保存的布局。');
  const result = await request('/api/lease', context());
  installPage(result.page); state.token = result.token; render();
}
async function switchPage(id) {
  if (state.transition || id === state.page?.id) return;
  await flush(); state.transition = true; status();
  try {
    if (state.token) await request('/api/release', context());
    state.token = null;
    state.doc = await request('/api/state'); state.csrf = state.doc.csrf;
    installPage(state.doc.pages.find(page => page.id === id) || state.doc.pages[0]);
    try { await acquire(); } catch (error) { if (error.status !== 423) throw error; }
    localStorage.setItem('human-layout-page', state.page.id);
  } finally { state.transition = false; render(); }
}
async function sync() {
  if (polling || state.transition || canvas.gesture) return;
  polling = true;
  try {
    const doc = await request('/api/state');
    state.connected = true; state.csrf = doc.csrf;
    if (!state.doc) {
      state.doc = doc;
      installPage(doc.pages.find(page => page.id === localStorage.getItem('human-layout-page')) || doc.pages[0]);
      try { await acquire(); } catch (error) { if (error.status !== 423) throw error; }
    } else if (doc.epoch !== state.doc.epoch) {
      if (state.dirty || state.saveFlight) { state.conflict = true; state.token = null; }
      else { state.doc = doc; state.token = null; installPage(doc.pages[0]); render(); }
    } else {
      state.doc = doc;
      const page = doc.pages.find(item => item.id === state.page.id);
      const lease = doc.leases[state.page.id];
      if (state.token && (!lease || lease.owner !== clientId || lease.token !== state.token)) {
        if (state.dirty || state.saveFlight) state.conflict = true;
        state.token = null; state.undo = []; state.redo = [];
      }
      if (!state.token && !state.dirty && !state.conflict && page && page.revision !== state.revision) { installPage(page); render(); }
    }
    renderPages(); renderAssets(); status(); canvas.drawSelection();
  } catch (error) { state.connected = false; status(); }
  finally { polling = false; }
}
async function renew() {
  if (!state.token || heartbeat || state.transition || state.conflict) return;
  heartbeat = true;
  const expected = context();
  try {
    const result = await request('/api/lease', expected);
    if (state.page?.id !== expected.pageId || state.token !== expected.token) return;
    if (result.token !== expected.token) { state.conflict = true; state.token = result.token; canvas.cancel(); }
  } catch (error) {
    if (state.page?.id !== expected.pageId) return;
    if (error.status) { state.conflict = true; state.token = null; canvas.cancel(); }
    else state.connected = false;
  } finally { heartbeat = false; status(); }
}
function addAsset(asset) {
  mutate(page => {
    const scale = Math.min(page.width * .72 / asset.width, page.height * .72 / asset.height, 1);
    const item = {id: crypto.randomUUID(), assetId: asset.id, name: asset.name, x: page.width / 2, y: page.height / 2,
      width: asset.width * scale, height: asset.height * scale, rotation: 0, visible: true, locked: false, groupId: null};
    page.layers.push(item); state.selected = new Set([item.id]);
  });
}
function removeSelected() { if (canvas.items().some(item => item.locked)) return; mutate(page => { page.layers = page.layers.filter(item => !state.selected.has(item.id)); }); }
function duplicate() {
  if (canvas.items().some(item => item.locked)) return;
  mutate(page => {
    const groups = new Map(), ids = [];
    for (const source of [...page.layers].filter(item => state.selected.has(item.id))) {
      const item = clone(source); item.id = crypto.randomUUID(); item.x += 24; item.y += 24;
      if (item.groupId) { if (!groups.has(item.groupId)) groups.set(item.groupId, crypto.randomUUID()); item.groupId = groups.get(item.groupId); }
      page.layers.push(item); ids.push(item.id);
    }
    state.selected = new Set(ids);
  });
}
function group() {
  const items = canvas.items();
  if (items.length < 2 || items.some(item => item.locked)) return;
  mutate(page => {
    const existing = items[0].groupId;
    if (existing && items.every(item => item.groupId === existing)) items.forEach(item => item.groupId = null);
    else {
      const index = page.layers.findIndex(item => state.selected.has(item.id));
      const id = crypto.randomUUID(); items.forEach(item => item.groupId = id);
      page.layers = page.layers.filter(item => !state.selected.has(item.id)); page.layers.splice(index, 0, ...items);
    }
  });
}
function history(redo = false) {
  if (!canEdit() || canvas.gesture) return;
  const source = redo ? state.redo : state.undo, target = redo ? state.undo : state.redo;
  if (!source.length) return;
  target.push(clone(state.page)); state.page = source.pop(); state.page.revision = state.revision; changed();
}
async function askName(heading, initial) {
  const dialog = $('#name-dialog'); $('#name-title').textContent = heading; $('#name-input').value = initial;
  dialog.returnValue = ''; dialog.showModal(); $('#name-input').select();
  return new Promise(resolve => dialog.addEventListener('close', () => resolve(dialog.returnValue === 'ok' ? $('#name-input').value.trim() : null), {once: true}));
}
async function upload(files) {
  if (!state.connected || state.transition) throw new Error('请先恢复连接，再上传图片。');
  $('#upload').disabled = true;
  let count = 0;
  try {
    for (const file of files) {
      if (file.size > 30 * 1024 * 1024) { toast(`${file.name} 超过 30 MB，已跳过`); continue; }
      await request('/api/assets?' + new URLSearchParams({epoch: state.doc.epoch, name: file.name.slice(0, 80)}), file, true); count++;
    }
    await sync(); toast(`已加入 ${count} 张素材，点击缩略图放入画布。`);
  } finally { $('#upload').disabled = false; $('#image-input').value = ''; }
}
function download(blob, name) { const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = name; a.click(); setTimeout(() => URL.revokeObjectURL(a.href), 30000); }
function downloadDraft() { download(new Blob([JSON.stringify({format: 'human-layout-unsaved-page', epoch: state.doc.epoch, page: state.page}, null, 2)], {type: 'application/json'}), '未保存页面-应急恢复.json'); toast('已下载未保存页面数据；原图仍在项目素材库。此文件供恢复核对，不是完整项目包。'); }
async function exportProject() {
  await flush();
  const response = await fetch('/api/export'); if (!response.ok) throw new Error('导出失败，请检查启动窗口。');
  download(await response.blob(), `寄往人间-排版项目-v0.1-${new Date().toISOString().slice(0,10)}.zip`); toast('完整项目已导出，包含所有页面和原始素材。');
}
async function importProject(file) {
  if (!file) return;
  await flush();
  if (!confirm('导入会替换当前所有页面和素材。系统会先保存完整备份；其他窗口需先释放编辑权。继续导入？')) return;
  state.transition = true; status();
  try {
    const latest = await request('/api/state');
    const result = await request('/api/import?' + new URLSearchParams({clientId, epoch: state.doc.epoch, revision: latest.revision}), file, true);
    state.token = null; state.doc = null; state.page = null; state.undo = []; state.redo = [];
    toast(`已导入；原项目备份：${result.backup}`);
  } finally { state.transition = false; $('#project-input').value = ''; await sync(); render(); }
}
function preview() {
  if (!state.page) return;
  const ratio = $('#preview-ratio').value;
  const page = state.page;
  let width = page.width, height = page.height;
  if (ratio !== 'original') { const r = Number(ratio); if (width / height > r) width = height * r; else height = width / r; }
  const root = svg('svg', {xmlns: 'http://www.w3.org/2000/svg', viewBox: `${(page.width - width) / 2} ${(page.height - height) / 2} ${width} ${height}`, width, height});
  root.append(svg('rect', {x: 0, y: 0, width: page.width, height: page.height, fill: page.background}));
  const artwork = svg('g'); drawArtwork(artwork, page, state.doc.epoch); root.append(artwork);
  $('#preview-stage').replaceChildren(root); $('#preview-name').textContent = page.name;
}
async function previewPNG() {
  const root = $('#preview-stage svg').cloneNode(true);
  for (const image of root.querySelectorAll('image')) {
    const response = await fetch(image.getAttribute('href')); if (!response.ok) throw new Error('素材读取失败');
    const data = await response.blob();
    const source = await new Promise((resolve, reject) => { const reader = new FileReader(); reader.onload = () => resolve(reader.result); reader.onerror = reject; reader.readAsDataURL(data); });
    image.setAttribute('href', source);
  }
  const source = URL.createObjectURL(new Blob([new XMLSerializer().serializeToString(root)], {type: 'image/svg+xml;charset=utf-8'}));
  try {
    const image = new Image(); image.src = source; await image.decode();
    const output = document.createElement('canvas'); output.width = Number(root.getAttribute('width')); output.height = Number(root.getAttribute('height'));
    output.getContext('2d').drawImage(image, 0, 0);
    const blob = await new Promise(resolve => output.toBlob(resolve, 'image/png'));
    if (!blob) throw new Error('预览图片生成失败'); download(blob, `${state.page.name}-v0.1-预览.png`);
  } finally { URL.revokeObjectURL(source); }
}
function action(id, handler) { $(id).onclick = () => Promise.resolve().then(handler).catch(fail); }
action('#new-page', async () => { const name = await askName('新建页面', `页面 ${state.doc.pages.length + 1}`); if (!name) return; await flush(); const page = await request('/api/pages', {...context(), name}); await switchPage(page.id); });
action('#rename-page', async () => { const id = state.page.id; const name = await askName('重命名页面', state.page.name); if (name && state.page.id === id) mutate(page => page.name = name); });
action('#upload', () => $('#image-input').click()); action('#empty-upload', () => $('#image-input').click());
$('#image-input').onchange = event => upload([...event.target.files]).catch(fail);
$('#asset-search').oninput = renderAssets;
action('#undo', () => history()); action('#redo', () => history(true)); action('#delete', removeSelected); action('#duplicate', duplicate); action('#group', group);
action('#zoom-in', () => canvas.setZoom(canvas.scale * 1.2)); action('#zoom-out', () => canvas.setZoom(canvas.scale / 1.2)); action('#fit', () => canvas.setZoom('fit'));
action('#release', release); action('#acquire', acquire); action('#save-draft', downloadDraft);
action('#recover', async () => {
  if (state.dirty && !confirm('载入最新版本会放弃本窗口未保存修改。建议先点“下载未保存布局”。确定继续？')) return;
  state.dirty = false; state.conflict = false; state.token = null; state.doc = null; await sync(); render();
});
action('#export', exportProject); action('#import', () => $('#project-input').click());
$('#project-input').onchange = event => importProject(event.target.files[0]).catch(fail);
action('#help', () => $('#help-dialog').showModal());
action('#preview', async () => { await flush(); preview(); $('#preview-dialog').showModal(); });
$('#preview-ratio').onchange = preview;
action('#preview-download', previewPNG);
document.querySelectorAll('.close-dialog').forEach(button => button.onclick = () => button.closest('dialog').close());
window.addEventListener('keydown', event => {
  if (event.target.matches('input,textarea,select') || document.querySelector('dialog[open]')) return;
  const modifier = event.ctrlKey || event.metaKey;
  if (modifier && event.key.toLowerCase() === 'z') { event.preventDefault(); history(event.shiftKey); }
  else if (modifier && event.key.toLowerCase() === 'y') { event.preventDefault(); history(true); }
  else if (modifier && event.key.toLowerCase() === 'd') { event.preventDefault(); duplicate(); }
  else if (modifier && event.key.toLowerCase() === 'g') { event.preventDefault(); group(); }
  else if (modifier && event.key.toLowerCase() === 's') { event.preventDefault(); flush().catch(fail); }
  else if (['Delete','Backspace'].includes(event.key)) { event.preventDefault(); removeSelected(); }
  else if (event.key === 'Escape') { canvas.cancel(); select(null); }
  else if (event.key.startsWith('Arrow') && state.selected.size && !canvas.items().some(item => item.locked)) {
    event.preventDefault(); const delta = event.shiftKey ? 10 : 1;
    mutate(page => { for (const item of page.layers.filter(layer => state.selected.has(layer.id))) { if (event.key === 'ArrowLeft') item.x -= delta; if (event.key === 'ArrowRight') item.x += delta; if (event.key === 'ArrowUp') item.y -= delta; if (event.key === 'ArrowDown') item.y += delta; } });
  }
});
window.addEventListener('beforeunload', event => { if (state.dirty || state.saveFlight || canvas.gesture) { event.preventDefault(); event.returnValue = ''; } });
window.addEventListener('pagehide', () => {
  if (state.token && !state.dirty && !state.saveFlight) fetch('/api/release', {method: 'POST', headers: {'X-Editor-Token': state.csrf, 'Content-Type': 'application/json'}, body: JSON.stringify(context()), keepalive: true}).catch(() => {});
});
window.addEventListener('focus', () => sync());
await sync(); render(); setInterval(sync, 1200); setInterval(renew, 4000);
