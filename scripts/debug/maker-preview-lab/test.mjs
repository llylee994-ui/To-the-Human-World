// Exercises the actual bundled asset server and cleanup method, not reimplementations.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { randomBytes } from 'node:crypto';
import { pipeline } from 'node:stream';
import vm from 'node:vm';
import { openPersistentPreview } from './persistence.mjs';

const original = process.argv.includes('--original');
const bundle = fs.readFileSync(original ? 'D:/taptap/.mpv/cli/maker.original.js' : 'D:/taptap/.mpv/cli/dist/maker.js','utf8');
const project = 'D:/taptap/To-the-Human-World';
const dir = fs.mkdtempSync('D:/taptap/.mpv/test-');
fs.mkdirSync(path.join(dir,'dist','1'),{recursive:true});
fs.writeFileSync(path.join(dir,'dist','latest.json'),JSON.stringify({version:'1',client:'abc'}));
fs.writeFileSync(path.join(dir,'dist','1','manifest-abc.json'),JSON.stringify({target:'client',files:[]}));
const context = vm.createContext({fs28:fs,path29:path,http,randomBytes,pipeline,fs33:fs,path34:path});
const begin = bundle.indexOf('async function startPreviewAssetServer(');
const end = bundle.indexOf('var init_assets',begin);
vm.runInContext(bundle.slice(begin,end),context);
const cleanupBegin=bundle.indexOf('clearAssetCache() {');
const cleanupEnd=bundle.indexOf('      appendLog(line)',cleanupBegin);
const cleanup=vm.runInContext('({' + bundle.slice(cleanupBegin,cleanupEnd) + '}).clearAssetCache',context);
process.env.MAKER_PREVIEW_PERSISTENCE_LAB='1';
const persistence=openPersistentPreview(project,false,path.join(dir,'storage'));
const marker=path.join(persistence.cacheRoot,'savedata-probe');
fs.writeFileSync(marker,'evidence');
let server;
let assertions=0;
try {
  server=await context.startPreviewAssetServer(dir,undefined,persistence);
  const url=server.url;
  assert.equal((await fetch(url+'latest.json')).status,200); assertions++;
  assert.equal((await fetch(url+'latest.json',{headers:{Origin:'https://example.invalid'}})).status,403); assertions++;
  assert.equal((await fetch(url+'unlisted.json')).status,404); assertions++;
  assert.equal((await fetch(url+'latest.json',{method:'POST'})).status,405); assertions++;
  if (!original) {
    await assert.rejects(context.startPreviewAssetServer(dir,undefined,openPersistentPreview(project,false,path.join(dir,'storage'))),/EADDRINUSE/); assertions++;
  }
  await server.close(); server=undefined;
  cleanup.call({persistence,assetCache:persistence.cacheRoot,recordError(e){throw new Error(e);}});
  assert.ok(fs.existsSync(marker),'savedata must survive cleanup'); assertions++;
  const same=openPersistentPreview(project,false,path.join(dir,'storage'));
  server=await context.startPreviewAssetServer(dir,undefined,same);
  assert.equal(server.url,url,'same URL and port after restart'); assertions++;
  assert.equal(fs.readFileSync(marker,'utf8'),'evidence'); assertions++;
  await server.close(); server=undefined;
  const ephemeral=fs.mkdtempSync(path.join(dir,'ephemeral-'));
  cleanup.call({temporaryCache:ephemeral,recordError(e){throw new Error(e);}});
  assert.equal(fs.existsSync(ephemeral),false,'default cleanup still applies'); assertions++;
  assert.throws(()=>openPersistentPreview(project,true,path.join(dir,'storage')),/restricted/); assertions++;
  delete process.env.MAKER_PREVIEW_PERSISTENCE_LAB;
  assert.equal(openPersistentPreview(project,false),undefined); assertions++;
  console.log(JSON.stringify({passed:assertions,bundle:original?'original':'candidate',directory:dir}));
} finally {
  if (server) await server.close();
}
