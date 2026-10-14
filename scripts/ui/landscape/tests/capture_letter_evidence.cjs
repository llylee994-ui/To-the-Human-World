// Offline screenshot of exported production geometry, not a game/device session.
const fs=require('fs'),path=require('path');
const {pathToFileURL}=require('url');
const {chromium}=require(process.argv[2]||'playwright');
const out=path.resolve(__dirname,'../../../../docs/验证/evidence/letter-presentation-r1');
(async()=>{
 const browser=await chromium.launch({headless:true});const page=await browser.newPage();const checks=[];
 for(const [width,height] of [[1140,510],[800,360],[1280,720],[1024,768]]){
  await page.setViewportSize({width,height});await page.goto(pathToFileURL(path.join(out,'offline-preview.html')).href);
  for(const label of ['before','snip','flight','after']){
   await page.evaluate(label=>window.LETTER_PREVIEW.draw(label),label);
   await page.evaluate(async()=>{await document.fonts.ready;await Promise.all([...document.images].map(i=>i.decode().catch(()=>{})));});
   const frame=await page.evaluate(()=>window.FRAME);
   for(const r of frame.layout.runs){if(r.x<0||r.x+r.w>frame.paper.w-8+.5)throw Error('inline run crosses reading width');}
   const c=frame.clip,p=frame.frame;
   if(c.x<p.x+32||c.y<p.y+32||c.x+c.w>p.x+p.w-32||c.y+c.h>p.y+p.h-32)throw Error('scroll clip outside paper interior');
   await page.screenshot({path:path.join(out,`offline-${width}-${label}.png`)});
   checks.push({width,height,label,runs:frame.layout.runs.length,holes:frame.holes.length,evidence:'production Lua geometry, simulated font/layout; NOT native/mobile'});
  }
 }
 fs.writeFileSync(path.join(out,'offline-checks.json'),JSON.stringify(checks,null,2));await browser.close();
 console.log('PASS 16 offline frames: measured runs and scroll clip remain within inset paper');
})().catch(e=>{console.error(e);process.exit(1)});
