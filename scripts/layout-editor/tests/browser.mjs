// Optional test-only dependency: npm install --prefix .local/qa playwright
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
const runDir = path.join(root, '.local', `browser-${Date.now()}`);
await mkdir(runDir, {recursive: true});
const server = spawn('python', ['-B','server.py','--no-browser','--port','0','--data-dir',path.join(runDir,'data')], {cwd:root,windowsHide:true});
let serverLog = '';
const url = await new Promise((resolve,reject) => {
  const timeout = setTimeout(() => reject(new Error('Server startup timeout')),10000);
  server.stdout.on('data', chunk => { serverLog += chunk; const match=serverLog.match(/http:\/\/127\.0\.0\.1:\d+/); if(match){clearTimeout(timeout);resolve(match[0]);} });
  server.stderr.on('data', chunk => serverLog += chunk);
  server.on('exit',code => {clearTimeout(timeout);reject(new Error(`Server exited ${code}: ${serverLog}`));});
});
let browser;
const checks = [], errors = [];
function pass(message) { checks.push(message); console.log('PASS',message); }
async function until(check, label, timeout=12000) { const end=Date.now()+timeout; while(Date.now()<end){if(await check())return;await new Promise(resolve=>setTimeout(resolve,100));} throw new Error(`Timed out: ${label}`); }
async function data(page) { return page.evaluate(async()=> (await fetch('/api/state')).json()); }
async function saved(page) { await until(async()=> (await page.locator('#save-status').textContent()).includes('已保存'), 'saved'); }
async function count(page,n) { await until(async()=>await page.locator('.layer-row').count()===n,`layers ${n}`); await saved(page); }
async function nameDialog(page,button,name) { await page.locator(button).click(); await page.locator('#name-input').fill(name); await page.locator('#name-dialog button[value=ok]').click(); await saved(page); }
try {
  browser = await chromium.launch({channel:'chrome',headless:true});
  const context=await browser.newContext({viewport:{width:1440,height:1000},acceptDownloads:true});
  const page=await context.newPage();
  page.on('pageerror',error=>errors.push(String(error)));
  await page.goto(url); await saved(page);
  await page.screenshot({path:path.join(runDir,'v0.1-empty.png')});
  assert.equal(await page.locator('.page-row').count(),1); pass('Initial page, blank canvas, and live local service');
  // Tiny transparent raster fixtures test the upload pipeline, not production artwork.
  const fixture = path.join(runDir,'transparent.png');
  const generator=spawn('python',['-B','-c',"import sys;sys.path.insert(0,'tests');from test_store import png;from pathlib import Path;Path(sys.argv[1]).write_bytes(png(240,180))",fixture],{cwd:root,windowsHide:true});
  await new Promise((resolve,reject)=>generator.on('exit',code=>code===0?resolve():reject(new Error('fixture'))));
  await page.locator('#image-input').setInputFiles(fixture);
  await until(async()=>await page.locator('.asset-card').count()===1,'asset uploaded');
  await page.locator('.asset-card').click(); await count(page,1);
  let doc=await data(page), originalPage=doc.pages[0].id, layerId=doc.pages[0].layers[0].id;
  assert.equal(doc.assets.length,1); pass('Transparent PNG upload and add-to-canvas');
  const image=page.locator('#artwork image').first();
  const bbox=await image.boundingBox();
  await page.mouse.move(bbox.x+bbox.width/2,bbox.y+bbox.height/2); await page.mouse.down(); await page.mouse.move(bbox.x+bbox.width/2+55,bbox.y+bbox.height/2-40,{steps:8}); await page.mouse.up(); await saved(page);
  doc=await data(page); assert.ok(doc.pages[0].layers[0].x>540); const movedX=doc.pages[0].layers[0].x;
  const handle=await page.locator('[data-handle=scale][data-sx="1"][data-sy="1"]').boundingBox();
  await page.mouse.move(handle.x+handle.width/2,handle.y+handle.height/2); await page.mouse.down(); await page.mouse.move(handle.x+handle.width/2+38,handle.y+handle.height/2+28,{steps:8}); await page.mouse.up(); await saved(page);
  doc=await data(page); assert.ok(doc.pages[0].layers[0].width>240);
  const rotation=await page.locator('[data-handle=rotate]').boundingBox();
  await page.mouse.move(rotation.x+rotation.width/2,rotation.y+rotation.height/2); await page.mouse.down(); await page.mouse.move(rotation.x+rotation.width/2+50,rotation.y+rotation.height/2+25,{steps:8}); await page.mouse.up(); await saved(page);
  doc=await data(page); assert.ok(doc.pages[0].layers[0].rotation>1); pass('Pointer drag, proportional corner scaling, and rotation');
  await page.locator('#duplicate').click(); await count(page,2);
  await page.locator('#delete').click(); await count(page,1);
  assert.equal((await data(page)).assets.length,1);
  await page.locator('#undo').click(); await count(page,2);
  await page.locator('#redo').click(); await count(page,1);
  await page.locator('#undo').click(); await count(page,2); pass('Duplicate, delete preserving original asset, undo and redo');
  await page.locator('.layer-row').first().locator('button[aria-label^="隐藏"]').click(); await saved(page);
  assert.equal(await page.locator('#artwork image').count(),1);
  await page.locator('.layer-row').first().locator('button[aria-label^="显示"]').click(); await saved(page);
  await page.locator('.layer-row').first().locator('button[aria-label^="锁定"]').click(); await saved(page);
  assert.equal(await page.locator('#delete').isDisabled(),true);
  await page.keyboard.press('Delete'); assert.equal(await page.locator('.layer-row').count(),2);
  await page.locator('.layer-row').first().locator('button[aria-label^="解锁"]').click(); await saved(page); pass('Hide/show and lock protecting a layer from deletion');
  const orderBefore=(await data(page)).pages[0].layers.map(item=>item.id);
  const top=page.locator('.layer-row').first(), bottom=page.locator('.layer-row').last();
  const bottomBox=await bottom.boundingBox();
  await top.dragTo(bottom,{targetPosition:{x:60,y:bottomBox.height-3}}); await saved(page);
  const orderAfter=(await data(page)).pages[0].layers.map(item=>item.id);
  assert.deepEqual(orderAfter,[...orderBefore].reverse()); pass('Layer drag reorder changes persisted drawing order');
  await page.locator('.layer-row').first().click(); await page.locator('.layer-row').last().click({modifiers:['Shift']});
  await page.locator('#group').click(); await saved(page);
  doc=await data(page); assert.ok(doc.pages[0].layers.every(item=>item.groupId===doc.pages[0].layers[0].groupId && item.groupId));
  const groupedBefore=doc.pages[0].layers;
  const groupRotate=await page.locator('[data-handle=rotate]').boundingBox();
  await page.mouse.move(groupRotate.x+groupRotate.width/2,groupRotate.y+groupRotate.height/2); await page.mouse.down(); await page.mouse.move(groupRotate.x+groupRotate.width/2+28,groupRotate.y+groupRotate.height/2+22,{steps:6}); await page.mouse.up(); await saved(page);
  const groupedAfter=(await data(page)).pages[0].layers;
  const distance=items=>Math.hypot(items[0].x-items[1].x,items[0].y-items[1].y);
  assert.ok(Math.abs(distance(groupedBefore)-distance(groupedAfter))<0.001);
  assert.ok(Math.abs(groupedBefore[0].width-groupedAfter[0].width)<0.001);
  await page.locator('#duplicate').click(); await count(page,4);
  doc=await data(page); assert.notEqual(doc.pages[0].layers[0].groupId,doc.pages[0].layers[2].groupId);
  await page.locator('#undo').click(); await count(page,2);
  await page.locator('.layer-row').first().click();
  await page.locator('.layer-row').first().locator('button[aria-label^="隐藏"]').click(); await saved(page); assert.equal(await page.locator('#artwork image').count(),0);
  await page.locator('#undo').click(); await saved(page); assert.equal(await page.locator('#artwork image').count(),2);
  await page.locator('#group').click(); await saved(page); pass('Group rotation preserves relative positions; group copies, visibility, and undo preserve members');
  await nameDialog(page,'#rename-page','主页 · 排版试验');
  assert.equal((await data(page)).pages[0].id,originalPage);
  await nameDialog(page,'#new-page','读信页'); await count(page,0);
  await page.locator('.asset-card').click(); await count(page,1);
  doc=await data(page); assert.equal(doc.pages[0].layers.length,2); assert.equal(doc.pages[1].layers.length,1); assert.equal(doc.assets.length,1);
  pass('Stable page IDs, rename, independent page layouts, shared assets');
  const second=await context.newPage(); second.on('pageerror',error=>errors.push(String(error))); await second.goto(url);
  await until(async()=>await second.locator('#acquire').isVisible(),'second window reader');
  assert.equal(await second.locator('#delete').isDisabled(),true);
  await page.locator('#duplicate').click(); await count(page,2);
  await until(async()=>await second.locator('.layer-row').count()===2,'live other-window update');
  await page.locator('#release').click(); await second.locator('#acquire').click(); await saved(second);
  assert.equal(await second.locator('#undo').isDisabled(),true);
  await second.locator('.layer-row').first().click(); await second.locator('#delete').click(); await count(second,1);
  await until(async()=>await page.locator('.layer-row').count()===1,'writer handoff propagated');
  await page.locator(`.page-row[data-page-id="${originalPage}"]`).click(); await saved(page);
  await page.locator('.layer-row').first().click(); await page.locator('#duplicate').click(); await count(page,3);
  assert.equal((await data(page)).pages[1].layers.length,1); pass('Same-page read-only, live sync, explicit handoff, isolated undo, different-page parallel edits');
  await page.reload(); await until(async()=> (await page.locator('#save-status').textContent()).includes('已保存') || (await page.locator('#acquire').isVisible()),'reload');
  if(await page.locator('#acquire').isVisible()){await page.locator('#acquire').click();await saved(page);}
  assert.equal(await page.locator('.layer-row').count(),3); pass('Browser refresh restores persisted page and assets');
  const downloadEvent=page.waitForEvent('download'); await page.locator('#export').click(); const archive=await downloadEvent; const zipPath=path.join(runDir,'v0.1-project.zip'); await archive.saveAs(zipPath);
  assert.ok((await readFile(zipPath)).length>200);
  // Other writer blocks replacement without losing edits.
  page.once('dialog',dialog=>dialog.accept()); await page.locator('#project-input').setInputFiles(zipPath);
  await until(async()=> (await page.locator('#toast').textContent()).includes('其他窗口'),'import blocked');
  await second.locator('#release').click();
  await page.locator('.layer-row').first().click(); await page.locator('#delete').click(); await count(page,2);
  page.once('dialog',dialog=>dialog.accept()); await page.locator('#project-input').setInputFiles(zipPath);
  await count(page,3); assert.equal((await data(page)).assets.length,1); pass('Complete ZIP download, concurrent import guard, import restores layouts and assets');
  await page.locator('#preview').click(); assert.equal(await page.locator('#preview-stage image').count(),3);
  await page.locator('#preview-ratio').selectOption('0.45');
  const viewBox=await page.locator('#preview-stage svg').getAttribute('viewBox'); assert.ok(viewBox.startsWith('108 '));
  const pngEvent=page.waitForEvent('download'); await page.locator('#preview-download').click(); const pngDownload=await pngEvent; await pngDownload.saveAs(path.join(runDir,'v0.1-preview.png'));
  await page.locator('#preview-dialog .close-dialog').click(); pass('Preview, 9:20 crop, and PNG export');
  // Use supplied concept as test composition only; leave production storage untouched.
  const concept=path.resolve(root,'../../docs/设计/原型/home-storybook-v04.png');
  await page.locator('#image-input').setInputFiles(concept); await until(async()=>await page.locator('.asset-card').count()===2,'concept upload');
  await page.locator('.asset-card').last().click(); await count(page,4);
  await page.screenshot({path:path.join(runDir,'v0.1-editor.png')});
  await page.setViewportSize({width:1024,height:768}); await page.screenshot({path:path.join(runDir,'v0.1-editor-1024.png')});
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false); pass('1440px and 1024px desktop layout screenshots');
  await page.route('**/api/save',route=>route.abort());
  await page.locator('#duplicate').click(); await until(async()=>await page.locator('#recover').isVisible(),'offline save protection');
  assert.equal(await page.locator('#delete').isDisabled(),true);
  const draftEvent=page.waitForEvent('download'); await page.locator('#save-draft').click(); const draft=await draftEvent; await draft.saveAs(path.join(runDir,'unsaved-page.json'));
  await page.unroute('**/api/save');
  page.once('dialog',dialog=>dialog.accept()); await page.locator('#recover').click(); await saved(page);
  assert.equal(await page.locator('.layer-row').count(),4); pass('Failed save freezes edits, preserves downloadable draft, explicit recovery');
  // Review files are deliberately captured from ONE saved snapshot and share a manifest hash.
  await page.setViewportSize({width:1440,height:1000});
  await page.locator('#preview').click();
  await page.locator('#preview-ratio').selectOption('original');
  const reviewPngEvent=page.waitForEvent('download'); await page.locator('#preview-download').click();
  await (await reviewPngEvent).saveAs(path.join(runDir,'v0.1-review-preview.png'));
  await page.locator('#preview-dialog .close-dialog').click();
  const reviewZipEvent=page.waitForEvent('download'); await page.locator('#export').click();
  await (await reviewZipEvent).saveAs(path.join(runDir,'v0.1-review-project.zip'));
  await page.locator('#toast').waitFor({state:'hidden',timeout:8000});
  await page.screenshot({path:path.join(runDir,'v0.1-review-editor.png')});
  const reviewState=await data(page); delete reviewState.csrf; delete reviewState.leases;
  await writeFile(path.join(runDir,'v0.1-review-state.json'),JSON.stringify(reviewState,null,2));
  const manifest={version:'0.1.0',projectId:reviewState.id,epoch:reviewState.epoch,revision:reviewState.revision,files:{}};
  for(const file of ['v0.1-review-preview.png','v0.1-review-project.zip','v0.1-review-editor.png','v0.1-review-state.json']) manifest.files[file]=createHash('sha256').update(await readFile(path.join(runDir,file))).digest('hex');
  await writeFile(path.join(runDir,'v0.1-review-manifest.json'),JSON.stringify(manifest,null,2));
  pass('Matching review screenshot, preview PNG, and full project ZIP from one saved state');
  assert.deepEqual(errors,[]); pass('No browser JavaScript exceptions');
  await writeFile(path.join(runDir,'results.json'),JSON.stringify({version:'0.1.0',checks,errors,serverLog},null,2));
  console.log('ARTIFACTS',runDir);
} catch(error) {
  console.error(error);
  if(browser)for(const context of browser.contexts())for(const page of context.pages())try{await page.screenshot({path:path.join(runDir,`failure-${context.pages().indexOf(page)}.png`)});}catch{}
  await writeFile(path.join(runDir,'failure.txt'),String(error)+'\n'+serverLog+'\n'+errors.join('\n'));
  console.error('ARTIFACTS',runDir); process.exitCode=1;
} finally { if(browser)await browser.close(); server.kill(); }
