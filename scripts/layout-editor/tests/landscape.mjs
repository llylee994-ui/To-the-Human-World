// Uses the same optional Playwright installation as browser.mjs; all data is isolated.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdir, writeFile, readFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
const require = createRequire(import.meta.url);
const {chromium} = require('../.local/qa/node_modules/playwright');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const runDir = path.join(root, '.local', `landscape-${Date.now()}`);
await mkdir(runDir, {recursive: true});
const checks = [], errors = [];
let browser, server, serverLog = '';
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(check, label) {
  const end = Date.now() + 12000;
  while (Date.now() < end) { if (await check()) return; await delay(100); }
  throw new Error(`Timed out: ${label}`);
}
const data = page => page.evaluate(async () => (await fetch('/api/state')).json());
const saved = page => until(async () => (await page.locator('#save-status').textContent()).includes('已保存'), 'saved');
const pagesOnly = doc => doc.pages.map(({revision, ...page}) => page);
function pass(message) { checks.push(message); console.log('PASS', message); }
async function choose(page, value) {
  await page.locator('#page-size').selectOption(value);
  const width = value === 'landscape' ? 1920 : 1080;
  await until(async () => (await data(page)).pages.find(p => p.id === primaryPageId).width === width, 'persisted page dimensions');
  await saved(page);
}
let primaryPageId;
async function download(page, button, filename) {
  const event = page.waitForEvent('download'); await page.locator(button).click();
  const result = await event; await result.saveAs(path.join(runDir, filename));
  return path.join(runDir, filename);
}
try {
  server = spawn('python', ['-B', 'server.py', '--no-browser', '--port', '0', '--data-dir', path.join(runDir, 'data')], {cwd: root, windowsHide: true});
  const url = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('server timeout')), 10000);
    server.stdout.on('data', chunk => { serverLog += chunk; const match = serverLog.match(/http:\/\/127\.0\.0\.1:\d+/); if (match) { clearTimeout(timer); resolve(match[0]); } });
    server.stderr.on('data', chunk => serverLog += chunk);
    server.on('error', reject); server.on('exit', code => { clearTimeout(timer); reject(new Error(`server exited ${code}: ${serverLog}`)); });
  });
  browser = await chromium.launch({channel: 'chrome', headless: true, ignoreDefaultArgs: ['--hide-scrollbars']});
  const context = await browser.newContext({viewport: {width: 1440, height: 900}, acceptDownloads: true});
  const page = await context.newPage(); page.on('pageerror', error => errors.push(String(error)));
  await page.goto(url); await saved(page);
  const original = (await data(page)).pages[0]; primaryPageId = original.id;
  assert.equal(original.width, 1080); assert.equal(original.height, 1920);
  assert.equal(await page.locator('#page-size').inputValue(), 'portrait');
  pass('Existing default portrait is unchanged');

  const fixture = path.join(runDir, 'transparent.png');
  await new Promise((resolve, reject) => {
    const child = spawn('python', ['-B', '-c', "import sys;sys.path.insert(0,'tests');from test_store import png;from pathlib import Path;Path(sys.argv[1]).write_bytes(png(240,180))", fixture], {cwd: root, windowsHide: true});
    child.on('error', reject); child.on('exit', code => code === 0 ? resolve() : reject(new Error('fixture failed')));
  });
  await page.locator('#image-input').setInputFiles(fixture);
  await until(async () => await page.locator('.asset-card').count() === 1, 'upload');
  await page.locator('.asset-card').click(); await saved(page);
  await page.locator('#duplicate').click(); await saved(page);
  await page.locator('.layer-row').first().click(); await page.locator('.layer-row').last().click({modifiers: ['Shift']});
  await page.locator('#group').click(); await saved(page);
  await page.locator('.layer-row').first().locator('button[aria-label^="锁定"]').click(); await saved(page);
  await page.locator('.layer-row').first().locator('button[aria-label^="隐藏"]').click(); await saved(page);
  const before = (await data(page)).pages[0];
  const viewer = await context.newPage(); viewer.on('pageerror', error => errors.push(String(error))); await viewer.goto(url);
  await until(async () => await viewer.locator('#page-size').isDisabled(), 'reader cannot resize');
  await choose(page, 'landscape');
  const after = (await data(page)).pages[0];
  assert.equal(after.width, 1920); assert.equal(after.height, 1080);
  assert.deepEqual(after.layers, before.layers.map(layer => ({...layer, x: layer.x + 420, y: layer.y - 420})));
  assert.equal(await page.locator('#canvas').getAttribute('viewBox'), '0 0 1920 1080');
  await until(async () => await viewer.locator('#page-size').inputValue() === 'landscape', 'reader gets dimensions');
  assert.ok(await viewer.locator('#page-size').isDisabled());
  pass('Landscape keeps sizes, group offsets, IDs, hidden/locked state; reader syncs without editing');

  await page.locator('#undo').click(); await saved(page);
  assert.deepEqual(pagesOnly(await data(page))[0], pagesOnly({pages: [before]})[0]);
  await page.locator('#redo').click(); await saved(page);
  assert.deepEqual(pagesOnly(await data(page))[0], pagesOnly({pages: [after]})[0]);
  await choose(page, 'portrait'); assert.deepEqual((await data(page)).pages[0].layers, before.layers);
  await choose(page, 'landscape');
  pass('Undo/redo and repeated direction changes preserve artwork without cumulative scaling');

  await page.locator('#new-page').click(); await page.locator('#name-input').fill('独立竖版页');
  await page.locator('#name-dialog button[value=ok]').click();
  await until(async () => (await data(page)).pages.length === 2 && await page.locator('#current-name').textContent() === '独立竖版页', 'new page created and selected');
  await saved(page);
  const second = (await data(page)).pages[1];
  assert.equal(second.width, 1080); assert.equal(second.height, 1920);
  assert.equal((await data(page)).pages[0].width, 1920);
  await page.locator(`.page-row[data-page-id="${original.id}"]`).click(); await saved(page);
  await page.locator('#release').click(); await page.reload(); await saved(page);
  assert.equal(await page.locator('#page-size').inputValue(), 'landscape');
  await viewer.close();
  pass('Different pages retain independent dimensions and refresh restores landscape');

  // Restore visibility for the preview checks. This only changes the isolated fixture.
  await page.locator('.layer-row').first().locator('button[aria-label^="显示"]').click(); await saved(page);
  const snapshot = pagesOnly(await data(page));
  const zip = await download(page, '#export', 'mixed-pages.zip');
  await choose(page, 'portrait');
  page.once('dialog', dialog => dialog.accept()); await page.locator('#project-input').setInputFiles(zip);
  await until(async () => JSON.stringify(pagesOnly(await data(page))) === JSON.stringify(snapshot), 'ZIP restores mixed pages');
  await saved(page);
  pass('ZIP restores portrait/landscape dimensions and exact layer content');

  await page.locator('#preview').click();
  const png = await download(page, '#preview-download', 'landscape-original.png');
  const bytes = await readFile(png);
  assert.equal(bytes.readUInt32BE(16), 1920); assert.equal(bytes.readUInt32BE(20), 1080);
  for (const ratio of [16 / 9, 19.5 / 9, 20 / 9]) {
    await page.locator('#preview-ratio').selectOption(String(ratio));
    const box = (await page.locator('#preview-stage svg').getAttribute('viewBox')).split(' ').map(Number);
    assert.ok(Math.abs(box[2] / box[3] - ratio) < 1e-9);
    assert.ok(Math.abs(box[1] * 2 + box[3] - 1080) < 1e-9);
  }
  await download(page, '#preview-download', 'landscape-20-9.png');
  const cropBytes = await readFile(path.join(runDir, 'landscape-20-9.png'));
  assert.equal(cropBytes.readUInt32BE(16), 1920); assert.equal(cropBytes.readUInt32BE(20), 864);
  pass('Landscape preview presets crop centrally; PNG is 1920x1080 or 1920x864 as selected');

  await page.locator('#preview-ratio').selectOption('original');
  for (const viewport of [{width: 1440, height: 900}, {width: 1024, height: 768}, {width: 800, height: 600}]) {
    await page.setViewportSize(viewport);
    await until(async () => {
      const image = await page.locator('#preview-stage svg').boundingBox(), stage = await page.locator('#preview-stage').boundingBox();
      return image && stage && image.width <= stage.width - 39 && image.height <= stage.height - 39 && Math.abs(image.width / image.height - 16 / 9) < .01;
    }, 'preview fits without stretching');
    await page.screenshot({path: path.join(runDir, `preview-${viewport.width}.png`)});
    await page.locator('#preview-dialog .close-dialog').click();
    assert.ok(await page.locator('#page-size').isVisible());
    const control = await page.locator('#page-size').boundingBox(), tools = await page.locator('.edit-actions').boundingBox();
    assert.ok(control.x + control.width <= tools.x + 1 || control.y + control.height <= tools.y + 1, 'size control does not overlap tools');
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
    await page.screenshot({path: path.join(runDir, `editor-${viewport.width}.png`)});
    await page.locator('#preview').click();
  }
  pass('Landscape editing and preview fit three desktop window sizes');
  await page.locator('#preview-dialog .close-dialog').click();
  await page.locator(`.page-row[data-page-id="${second.id}"]`).click(); await saved(page);
  await page.locator('#preview').click();
  await page.locator('#preview-ratio').selectOption('0.45');
  assert.ok((await page.locator('#preview-stage svg').getAttribute('viewBox')).startsWith('108 '));
  pass('Portrait preview ratios still work after visiting a landscape page');
  assert.deepEqual(errors, []);
  await writeFile(path.join(runDir, 'results.json'), JSON.stringify({version: 'landscape-r1', checks, errors}, null, 2));
  const files = ['mixed-pages.zip', 'landscape-original.png', 'landscape-20-9.png', ...[1440, 1024, 800].flatMap(width => [`editor-${width}.png`, `preview-${width}.png`])];
  const manifest = {version: 'landscape-r1', pageId: original.id, files: {}};
  for (const file of files) manifest.files[file] = createHash('sha256').update(await readFile(path.join(runDir, file))).digest('hex');
  await writeFile(path.join(runDir, 'manifest.json'), JSON.stringify(manifest, null, 2));
  console.log('ARTIFACTS', runDir);
} catch (error) {
  console.error(error); await writeFile(path.join(runDir, 'failure.txt'), String(error) + '\n' + errors.join('\n'));
  if (browser) for (const context of browser.contexts()) for (const page of context.pages()) await page.screenshot({path: path.join(runDir, 'failure.png')}).catch(() => {});
  console.error('ARTIFACTS', runDir); process.exitCode = 1;
} finally { if (browser) await browser.close(); if (server) server.kill(); }
