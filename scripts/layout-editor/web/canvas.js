const NS = 'http://www.w3.org/2000/svg';
export const clone = value => structuredClone(value);
export function svg(tag, attrs = {}) {
  const node = document.createElementNS(NS, tag);
  for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, value);
  return node;
}
const rotate = (x, y, degrees) => {
  const r = degrees * Math.PI / 180;
  return {x: x * Math.cos(r) - y * Math.sin(r), y: x * Math.sin(r) + y * Math.cos(r)};
};

export function selectionBox(items) {
  if (!items.length) return null;
  if (items.length === 1) return {...items[0]};
  const corners = items.flatMap(item => [-1, 1].flatMap(sx => [-1, 1].map(sy => {
    const p = rotate(sx * item.width / 2, sy * item.height / 2, item.rotation);
    return {x: item.x + p.x, y: item.y + p.y};
  })));
  const x0 = Math.min(...corners.map(p => p.x)), x1 = Math.max(...corners.map(p => p.x));
  const y0 = Math.min(...corners.map(p => p.y)), y1 = Math.max(...corners.map(p => p.y));
  return {x: (x0 + x1) / 2, y: (y0 + y1) / 2, width: x1 - x0, height: y1 - y0, rotation: 0};
}

export function drawArtwork(root, page, epoch) {
  root.replaceChildren();
  for (const item of page.layers) {
    if (!item.visible) continue;
    const group = svg('g', {'data-id': item.id, transform: `translate(${item.x} ${item.y}) rotate(${item.rotation})`});
    if (item.locked) group.classList.add('locked');
    group.append(svg('image', {href: `/api/asset/${item.assetId}?v=${epoch}`, x: -item.width / 2, y: -item.height / 2,
      width: item.width, height: item.height, preserveAspectRatio: 'none', 'pointer-events': 'all'}));
    root.append(group);
  }
}

export class Canvas {
  constructor(state, callbacks) {
    this.state = state;
    this.callbacks = callbacks;
    this.element = document.querySelector('#canvas');
    this.artwork = document.querySelector('#artwork');
    this.selection = document.querySelector('#selection');
    this.viewport = document.querySelector('#viewport');
    this.shell = document.querySelector('#stage-shell');
    this.scale = 1;
    this.zoom = 'fit';
    this.gesture = null;
    this.element.addEventListener('pointerdown', event => this.down(event));
    this.element.addEventListener('pointermove', event => this.move(event));
    this.element.addEventListener('pointerup', event => this.up(event));
    this.element.addEventListener('pointercancel', () => this.cancel());
    new ResizeObserver(() => this.resize()).observe(this.viewport);
  }
  point(event) {
    const point = new DOMPoint(event.clientX, event.clientY);
    return point.matrixTransform(this.element.getScreenCTM().inverse());
  }
  items() { return this.state.page?.layers.filter(item => this.state.selected.has(item.id)) || []; }
  resize() {
    const page = this.state.page;
    if (!page) return;
    const room = this.viewport.getBoundingClientRect();
    this.scale = this.zoom === 'fit' ? Math.max(.08, Math.min((room.width - 64) / page.width, (room.height - 64) / page.height)) : this.zoom;
    this.shell.style.width = `${page.width * this.scale}px`;
    this.shell.style.height = `${page.height * this.scale}px`;
    document.querySelector('#zoom-label').textContent = `${Math.round(this.scale * 100)}%`;
    this.drawSelection();
  }
  setZoom(value) { this.zoom = value === 'fit' ? value : Math.max(.08, Math.min(2, value)); this.resize(); }
  render() {
    if (!this.state.page) return;
    const page = this.state.page;
    this.element.setAttribute('viewBox', `0 0 ${page.width} ${page.height}`);
    this.element.style.background = page.background;
    drawArtwork(this.artwork, page, this.state.doc.epoch);
    document.querySelector('#canvas-empty').hidden = page.layers.length > 0;
    this.resize();
  }
  drawSelection() {
    this.selection.replaceChildren();
    const items = this.items().filter(item => item.visible);
    const box = selectionBox(items);
    if (!box) return;
    const group = svg('g', {transform: `translate(${box.x} ${box.y}) rotate(${box.rotation})`});
    group.append(svg('rect', {x: -box.width / 2, y: -box.height / 2, width: box.width, height: box.height, class: 'selection-frame'}));
    if (this.callbacks.canEdit() && !items.some(item => item.locked)) {
      const size = 8 / this.scale;
      for (const sx of [-1, 1]) for (const sy of [-1, 1]) {
        group.append(svg('rect', {x: sx * box.width / 2 - size / 2, y: sy * box.height / 2 - size / 2, width: size, height: size,
          class: 'handle', 'data-handle': 'scale', 'data-sx': sx, 'data-sy': sy}));
      }
      const top = -box.height / 2;
      group.append(svg('path', {d: `M0 ${top} V${top - 27 / this.scale}`, class: 'rotation-stem'}));
      group.append(svg('circle', {cx: 0, cy: top - 31 / this.scale, r: 5 / this.scale, class: 'handle rotate-handle', 'data-handle': 'rotate'}));
    }
    this.selection.append(group);
  }
  down(event) {
    if (event.button !== 0 || !this.state.page || this.gesture) return;
    const handle = event.target.closest('[data-handle]');
    const target = event.target.closest('[data-id]');
    if (!handle) {
      if (!target) { this.callbacks.select(null, false); return; }
      if (!this.state.selected.has(target.dataset.id) || event.shiftKey || event.ctrlKey || event.metaKey) {
        this.callbacks.select(target.dataset.id, event.shiftKey || event.ctrlKey || event.metaKey);
      }
    }
    const items = this.items();
    if (!this.callbacks.canEdit() || !items.length || items.some(item => item.locked) || (event.shiftKey && !handle)) return;
    const point = this.point(event), box = selectionBox(items);
    const kind = handle?.dataset.handle || 'move';
    const offset = rotate(-(Number(handle?.dataset.sx) || 1) * box.width / 2, -(Number(handle?.dataset.sy) || 1) * box.height / 2, box.rotation);
    this.gesture = {kind, start: point, box, before: clone(this.state.page), ids: new Set(this.state.selected),
      anchor: {x: box.x + offset.x, y: box.y + offset.y}, moved: false};
    this.element.setPointerCapture(event.pointerId);
    event.preventDefault();
  }
  move(event) {
    const g = this.gesture;
    if (!g || !this.callbacks.canEdit()) return;
    const point = this.point(event);
    if (Math.hypot(point.x - g.start.x, point.y - g.start.y) * this.scale < 2 && !g.moved) return;
    g.moved = true;
    const original = g.before.layers.filter(item => g.ids.has(item.id));
    let factor = 1, angle = 0;
    if (g.kind === 'scale') {
      const vx = g.start.x - g.anchor.x, vy = g.start.y - g.anchor.y;
      factor = ((point.x - g.anchor.x) * vx + (point.y - g.anchor.y) * vy) / (vx * vx + vy * vy);
      const min = Math.max(...original.map(item => Math.max(1 / item.width, 1 / item.height)));
      const max = Math.min(...original.map(item => Math.min(32768 / item.width, 32768 / item.height)));
      factor = Math.max(min, Math.min(max, factor));
    } else if (g.kind === 'rotate') {
      angle = (Math.atan2(point.y - g.box.y, point.x - g.box.x) - Math.atan2(g.start.y - g.box.y, g.start.x - g.box.x)) * 180 / Math.PI;
      if (event.shiftKey) angle = Math.round(angle / 15) * 15;
    }
    for (const start of original) {
      const item = this.state.page.layers.find(layer => layer.id === start.id);
      if (g.kind === 'move') { item.x = start.x + point.x - g.start.x; item.y = start.y + point.y - g.start.y; }
      else if (g.kind === 'scale') {
        item.x = g.anchor.x + (start.x - g.anchor.x) * factor;
        item.y = g.anchor.y + (start.y - g.anchor.y) * factor;
        item.width = start.width * factor; item.height = start.height * factor;
      } else {
        const offset = rotate(start.x - g.box.x, start.y - g.box.y, angle);
        item.x = g.box.x + offset.x; item.y = g.box.y + offset.y;
        item.rotation = ((start.rotation + angle) % 360 + 360) % 360;
      }
      item.x = Math.max(-100000, Math.min(100000, item.x));
      item.y = Math.max(-100000, Math.min(100000, item.y));
    }
    drawArtwork(this.artwork, this.state.page, this.state.doc.epoch);
    this.drawSelection();
  }
  up(event) {
    const gesture = this.gesture;
    if (!gesture) return;
    this.gesture = null;
    if (this.element.hasPointerCapture(event.pointerId)) this.element.releasePointerCapture(event.pointerId);
    if (gesture.moved) this.callbacks.commit(gesture.before);
  }
  cancel() {
    if (!this.gesture) return;
    this.state.page = this.gesture.before;
    this.state.page.revision = this.state.revision;
    this.gesture = null;
    this.render();
  }
}
