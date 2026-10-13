// Isolated CSS replay of actual Lua widget props. Does not control a game/browser UI.
const path=require('path'),fs=require('fs');
const {pathToFileURL}=require('url');
const {chromium}=require(process.argv[2]||'playwright');
const out=path.resolve(__dirname,'../../../../docs/验证/evidence',process.argv[3]||'mobile-safe-r1');
(async()=>{
 const browser=await chromium.launch({headless:true});const page=await browser.newPage();const checks=[];
 for(const [width,height] of [[2048,917],[1280,720],[800,360],[1024,768]]){
  await page.setViewportSize({width,height});await page.goto(pathToFileURL(path.join(out,'offline-preview.html')).href);
  for(const scene of ['home','seaside','shop','shop-page2','shop-furniture','shop-furniture-page2','shop-ticket','brew','journal']){
   await page.evaluate(scene=>window.MOBILE_PREVIEW.draw(scene),scene);
   await page.evaluate(async()=>{await document.fonts.ready;await Promise.all([...document.images].map(i=>i.decode().catch(()=>{})));await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));});
   const geometry=await page.evaluate(scene=>{
    const rect=id=>{const r=document.getElementById(id).getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height};};
    const selected={'shop':'ing_sea_salt','shop-page2':'ing_ashen_herb','shop-furniture':'decor_tablecloth','shop-furniture-page2':'decor_lamp','shop-ticket':'travel_ticket'}[scene];
    const ids=selected?['closePanel','buy_'+selected,'shopPreviousPage','shopNextPage']:scene==='seaside'?['returnHome','nextDay','seasideShop','startSalvage']:scene==='journal'?['closePanel']:['nextDay','toggleHomeHints'];
    if(selected)for(const label of document.querySelectorAll('[id^="shopName_"],[id^="shopPrice_"],[id^="shopStatus_"]'))ids.push(label.id);
    return {capsule:rect('simulatedCapsule'),controls:Object.fromEntries(ids.map(id=>[id,rect(id)])),surface:rect('playPanel')};
   },scene);
   for(const [id,r] of Object.entries(geometry.controls)){
    const c=geometry.capsule;
    if(r.x<0||r.y<0||r.x+r.w>width+.5||r.y+r.h>height+.5)throw Error(`out of viewport ${scene}/${id} ${width}x${height}: ${JSON.stringify(r)}`);
    if(r.x<c.x+c.w&&r.x+r.w>c.x&&r.y<c.y+c.h&&r.y+r.h>c.y)throw Error(`capsule overlap ${scene}/${id} ${width}x${height}`);
   }
   if(Math.abs(geometry.surface.x)>.5||Math.abs(geometry.surface.w-width)>.5)throw Error('not fullscreen');
   await page.screenshot({path:path.join(out,`offline-${scene}-${width}x${height}.png`)});
   checks.push({width,height,scene,geometry,evidence:'CSS replay with simulated host; NOT phone/native/touch'});
  }
 }
 fs.writeFileSync(path.join(out,'offline-layout-checks.json'),JSON.stringify(checks,null,2));await browser.close();console.log('36 CSS projections checked: controls and complete goods labels in bounds, no capsule overlaps');
})().catch(e=>{console.error(e);process.exit(1)});
