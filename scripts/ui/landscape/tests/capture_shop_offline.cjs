// Isolated Chromium capture of exported Lua props; never controls the native game.
const path = require('path');
const fs = require('fs');
const { pathToFileURL } = require('url');
const { chromium } = require(process.argv[2] || 'playwright');
const root = path.resolve(__dirname, '../../../..');
const out = path.join(root, 'docs/验证/evidence', process.argv[3] || 'shop-counter-r1');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  const checks = [];
  for (const [width, height] of [[1280,720],[1600,720],[1024,768],[800,360]]) {
    await page.setViewportSize({width, height});
    await page.goto(pathToFileURL(path.join(out, 'offline-preview.html')).href);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({path: path.join(out, `offline-shop-${width}x${height}.png`)});
    const geometry = await page.evaluate(() => {
      const rect = id => {
        const r = document.getElementById(id).getBoundingClientRect();
        return {x:r.x,y:r.y,w:r.width,h:r.height};
      };
      return {close:rect('closePanel'),buy:rect('buy_ing_sea_salt'),goods:rect('shopGoodsScroll'),detail:rect('shopDetailScroll')};
    });
    for (const id of ['close','buy']) {
      const r=geometry[id];
      if (r.x<0 || r.y<0 || r.x+r.w>width+.1 || r.y+r.h>height+.1 || r.h<30) throw Error(`unreachable ${id} at ${width}x${height}: ${JSON.stringify(r)}`);
    }
    // Selection switches to another exported real Lua tree, never simulates a purchase.
    await page.locator('#shop_select_ing_night_dew').click();
    if (await page.locator('#shopItemName').innerText() !== '夜露') throw Error('offline selection replay failed');
    await page.screenshot({path: path.join(out, `offline-shop-dew-${width}x${height}.png`)});
    if (process.argv[3] === 'shop-ticket-r1') {
      await page.evaluate(() => window.SHOP_PREVIEW.draw('travel_ticket'));
      await page.screenshot({path: path.join(out, `offline-ticket-${width}x${height}.png`)});
      const ticket = await page.locator('#shop_select_travel_ticket').boundingBox();
      if (ticket.y + ticket.height > height+.1) throw Error(`ticket below viewport at ${width}x${height}`);
      await page.evaluate(() => window.SHOP_PREVIEW.draw('travel_ticket_confirm'));
      await page.screenshot({path: path.join(out, `offline-ticket-confirm-${width}x${height}.png`)});
      const footer = await page.locator('#confirmTravelTicket').boundingBox();
      if (footer.y + footer.height > height+.1) throw Error(`confirmation footer below viewport at ${width}x${height}`);
    }
    checks.push({width,height,geometry,evidence:'actual Lua props -> CSS; NOT native layout/touch'});
  }
  fs.writeFileSync(path.join(out,'offline-layout-checks.json'),JSON.stringify(checks,null,2));
  await browser.close();
  console.log(`Offline shop: ${checks.length} viewport projections captured; controls in bounds.`);
})().catch(e=>{console.error(e);process.exit(1)});
