-- Graphical native integration verification with real UI callbacks, not OS/human mouse input.
local app,camera,node,ready,frame=nil,nil,nil,false,0
local report={input='official synthetic UI.HandleMouseMove/Down/Up -> real widget hit testing/pressed release/onClick + native camera rays; no OS/human mouse input',storage='isolated MemoryStorage only',entries={},captures={}}
local ids={'home.drawer','home.journal','home.tray','home.caseFile','home.merchantShip','home.letterPaper','home.stove','home.net'}
local index,phase=1,'hints'
local baseline,writes
local function capture(name)
 if name:sub(1,6)=='entry-' and os.getenv('D3_QA_CAPTURE_ALL')=='0' then report.captures[name]='not requested';return true end
 local im=Image();local ok=graphics:TakeScreenShot(im)
 if ok then ok=im:SavePNG(os.getenv('D3_CLOUD_OUTPUT')..'/'..name..'.png') end
 report.captures[name]=ok;return ok
end
local function finish(ok,err)
 ready=false;report.status=ok and 'PASS' or 'FAIL';report.error=err;report.phase=phase
 print('[CLOUD INTERACTION RESULT] '..cjson.encode(report))
 local f=File(os.getenv('D3_CLOUD_OUTPUT')..'/interaction-report.json',FILE_WRITE);f:WriteLine(cjson.encode(report));f:Close()
 engine:Exit()
end
local UI=require('urhox-libs/UI')
local function pointer(x,y)
 local scale=UI.GetScale();x=x*scale;y=y*scale
 UI.HandleMouseMove(x,y);UI.HandleMouseDown(x,y,MOUSEB_LEFT);UI.HandleMouseUp(x,y,MOUSEB_LEFT)
end
local function click(id)
 local widget=assert(app.view.root:FindById(id),'missing UI '..id)
 local r=widget:GetAbsoluteLayout();assert(r.w>0 and r.h>0,'UI not laid out '..id)
 pointer(r.x+r.w/2,r.y+r.h/2);app.view.Update()
end
require('v035.lab35.FullSceneHost').Install({resourcePrefix='v035-full',manifestPath='manifest.json',flipV=true,maxLoadingSeconds=900,
 deferLoadingViewport=true,loadingMaxSteps=64,loadingBudgetMs=50,cloudNoLut=true,cloudHdr=true,
 onReady=function(scene,cam,value,camNode)
  app=value;camera=cam;node=camNode;ready=true
  report.runtimeMouseLeft=MOUSEB_LEFT;report.coordinates='UI layout pixels, scaled by UI.GetScale for event dispatch';report.uiScale=UI.GetScale()
  require('v035.lab35.HarborLighting').Apply(scene)
  baseline=app.bundle.session.state.GetSnapshot();writes=app.bundle.storage.WriteCount()
 end})
local start=Start
function Start() start();SubscribeToEvent('EndRendering','CloudInteractionFrame') end
local function step()
 if phase=='hints' then
  click('toggleHomeHints');assert(app.controller.HintsVisible());report.hintsEnabled=true;phase='hints_capture';return
 end
 if phase=='hints_capture' then
  if not capture('01-home-hints') then return end
  phase='entry';return
 end
 if phase=='entry' then
  local id=ids[index];local anchor
  for _,a in ipairs(app.imported.prepared.anchors) do if a.id==id then anchor=a end end
  assert(anchor,'missing anchor')
  local rect=app.view.home.root:GetAbsoluteLayout()
  local p=assert(require('v035.lab35.NativeGeometry').Project(camera,node,anchor.position,rect),'anchor off screen '..id)
  local ray=camera:GetScreenRay((p.x-rect.x)/rect.w,(p.y-rect.y)/rect.h)
  local picked=app.picker.Pick({ray.origin.x,ray.origin.y,ray.origin.z},{ray.direction.x,ray.direction.y,ray.direction.z})
  assert(picked==id,'native pick '..id..' returned '..tostring(picked))
  local surface=assert(app.view.home.root:FindById('v035PickSurface'))
  pointer(p.x,p.y)
  app.view.Update()
  local target=require('v035.lab35.Ids')[id].target
  local expected=target=='paper' and 'letters' or target
  assert(app.view.scene==expected or app.view.panel==expected,'route mismatch '..id)
  report.entries[#report.entries+1]={id=id,target=target,picked=picked,scene=app.view.scene,panel=app.view.panel,screen={p.x,p.y}}
  phase='entry_capture';return
 end
 if phase=='entry_capture' then
  if not capture(string.format('entry-%02d',index)) then return end
  if app.view.panel then click('closePanel') end
  if app.view.scene~='home' then click('returnHome') end
  phase='entry_return';return
 end
 if phase=='entry_return' then
  if app.view.scene~='home' then return end
  app.view.Update();assert(not app.view.panel)
  index=index+1;phase=index<=#ids and 'entry' or 'business';return
 end
 if phase=='business' then
  assert(require('v035.core.StateUtil').Equal(baseline,app.bundle.session.state.GetSnapshot()),'navigation changed business state')
  assert(writes==app.bundle.storage.WriteCount(),'navigation wrote memory storage')
  report.navigationStateUnchanged=true;report.beforeBusiness=app.controller.Hud()
  click('nextDay');assert(app.view.panel=='day');phase='day_confirm';return
 end
 if phase=='day_confirm' then
  local button=assert(app.view.root:FindById('confirmNextDay'));local stale=button.props.onClick
  click('confirmNextDay');local after=app.controller.Hud();assert(after.day==report.beforeBusiness.day+1)
  stale(button,{});assert(app.controller.Hud().day==after.day,'stale confirmation advanced a second day')
  report.endDay={before=report.beforeBusiness.day,after=after.day,duplicateBlocked=true}
  assert(app.controller.Activate('home.merchantShip','shop-purchase-test',false));app.view.Update();phase='buy';return
 end
 if phase=='buy' then
  local shop=app.bundle.session.queries.GetShopView();assert(shop.ok)
  local item=assert(shop.value.items[1]);local before=app.controller.Hud().currency
  click('buy_'..item.ingredientId);local after=app.controller.Hud().currency
  assert(after==before-item.price,'actual Buy button did not update currency')
  report.currency={before=before,after=after,ingredient=item.ingredientId,price=item.price}
  phase='shop_close';return
 end
 if phase=='shop_close' then
  click('closePanel');assert(app.controller.Activate('home.net','receive-test',false));app.view.Update()
  assert(app.view.scene=='seaside');phase='receive';return
 end
 if phase=='receive' then
  local available=app.bundle.session.queries.GetSalvageView();assert(available.ok and available.value.enabled and #available.value.availableLetterIds>0)
  click('startSalvage');local id=app.view.salvage.letterInstanceId;assert(id,'actual StartSalvage UI did not receive a letter')
  report.receive={ok=true,letterInstanceId=id,availableLetterId=available.value.availableLetterIds[1]}
  assert(app.bundle.session.state.GetSnapshot().live.letters.byId[id],'received letter absent from real state')
  phase='receive_capture';return
 end
 if phase=='receive_capture' then
  if not capture('seaside-received') then return end
  if app.view.salvage.active then click('skipSalvage')
  elseif app.view.panel~='reader' then click('readCapturedLetter') end
  app.view.Update();assert(app.view.panel=='reader','received letter reader not opened');phase='reader';return
 end
 if phase=='reader' then
  if not capture('received-letter-reader') then return end
  if app.view.panel then click('closePanel') end
  click('returnHome');phase='final_return';return
 end
 if phase=='final_return' then
  if app.view.scene~='home' then return end
  app.view.Update();report.returnHome=true
  report.finalHud=app.controller.Hud();report.memoryWrites=app.bundle.storage.WriteCount()
  for _,e in ipairs(app.bundle.storage.Audit()) do assert(e.path:find('d3_lab_v035',1,true),'nonisolated storage path') end
  phase='final';return
 end
 if phase=='final' then if not capture('final-hud-after-test') then return end;finish(true) end
end
function CloudInteractionFrame()
 if not ready then return end;frame=frame+1
 if frame>600 then finish(false,'bounded UI verification timeout');return end
 if frame<25 or frame%4~=1 then return end
 local prior=phase;local ok,err=pcall(step);if prior~=phase then print('[CLOUD UI PHASE] '..prior..' -> '..phase) end;if not ok then finish(false,tostring(err)) end
end
