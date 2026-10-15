// Isolated browser/data profile: never edits the designer's actual project.
const assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const {mkdir,writeFile}=require('node:fs/promises');
const path=require('node:path');
const {chromium}=require(process.argv[2]||'playwright');
const root=path.resolve(__dirname,'..');
const out=path.join(root,'.local',`panel-browser-${Date.now()}`);
async function until(fn,label){const end=Date.now()+15000;while(Date.now()<end){if(await fn())return;await new Promise(r=>setTimeout(r,100));}throw Error(label);}
(async()=>{
 await mkdir(out,{recursive:true});
 const server=spawn('python',['-B','panel_materials.py','--no-browser','--port','0','--data-dir',path.join(out,'data')],{cwd:root,windowsHide:true});
 let stdout='',stderr='',browser;
 server.stdout.on('data',d=>stdout+=d);server.stderr.on('data',d=>stderr+=d);
 try{
  await until(()=>stdout.match(/http:\/\/127\.0\.0\.1:\d+/),'editor did not start: '+stderr);
  const url=stdout.match(/http:\/\/127\.0\.0\.1:\d+/)[0];
  browser=await chromium.launch({headless:true});
  const page=await browser.newPage({viewport:{width:1440,height:1000},acceptDownloads:true});
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  const data=()=>page.evaluate(async()=>(await fetch('/api/state')).json());
  const saved=()=>until(async()=>(await page.locator('#save-status').innerText()).includes('已保存'),'autosave not confirmed');
  await page.goto(url);await saved();
  assert.equal(await page.locator('.page-row').count(),2);
  assert.equal(await page.locator('.asset-card').count(),10);
  const before=await data();
  const slip=before.pages[0].layers.find(l=>l.id==='tray-slip-0');
  const box=await page.locator('#artwork g[data-id="tray-slip-0"] image').boundingBox();
  await page.mouse.move(box.x+box.width/2,box.y+box.height/2);await page.mouse.down();
  await page.mouse.move(box.x+box.width/2+25,box.y+box.height/2+18,{steps:7});await page.mouse.up();await saved();
  assert.notEqual((await data()).pages[0].layers.find(l=>l.id===slip.id).x,slip.x);
  await page.locator('#undo').click();await saved();
  assert.equal((await data()).pages[0].layers.find(l=>l.id===slip.id).x,slip.x);
  await page.screenshot({path:path.join(out,'tray-editor.png')});
  await page.locator('.page-row[data-page-id="panel-journal"]').click();
  await until(async()=>(await page.locator('#current-name').innerText())==='记录书界面','journal page did not finish loading');await saved();
  assert.equal(await page.locator('#artwork g[data-id="journal-book"]').count(),1);
  await page.locator('.layer-row[data-id="journal-flowers"]').click();
  await page.keyboard.press('ArrowRight');await saved();
  const changed=(await data()).pages[1].layers.find(l=>l.id==='journal-flowers').x;
  assert.equal(changed,before.pages[1].layers.find(l=>l.id==='journal-flowers').x+1);
  await page.reload();await saved();
  assert.equal((await data()).pages[1].layers.find(l=>l.id==='journal-flowers').x,changed);
  await page.locator('.page-row[data-page-id="panel-journal"]').click();
  await until(async()=>(await page.locator('#current-name').innerText())==='记录书界面','journal page did not finish loading');await saved();
  await page.screenshot({path:path.join(out,'journal-editor.png')});
  const download=page.waitForEvent('download');await page.locator('#export').click();
  await (await download).saveAs(path.join(out,'reference-project.zip'));
  await page.locator('#preview').click();await page.locator('#preview-stage svg').waitFor();
  assert.equal(await page.locator('#preview-stage #selection').count(),0);
  assert.deepEqual(errors,[]);
  await writeFile(path.join(out,'checks.json'),JSON.stringify({passed:['two seeded pages','10 original assets','pointer drag and undo','page switching','keyboard adjustment','reload persistence','ZIP export','clean preview'],evidence:'real browser / isolated project; not game UI',url},null,2));
  console.log('PASS panel studio browser: drag, undo, switch, save/reload, export, preview. Evidence: '+out);
 }finally{if(browser)await browser.close();server.kill();}
})().catch(e=>{console.error(e);process.exit(1)});
