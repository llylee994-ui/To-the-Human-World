import {routeLayout,relatedRoute} from './routes.js';
const labels={root:'故事',act:'章节',ordinary:'普通愿望',main:'主线场景',choice:'两封瓶子二选一',candidate:'候选愿望',result:'分支后续',followup:'后续来信',merge:'汇合',ending:'结局',note:'备注'};
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export {labels};
export class StoryMap{
 constructor(canvas,callbacks){this.canvas=canvas;this.world=document.querySelector('#world');this.cards=document.querySelector('#cards');this.svg=document.querySelector('#connections');this.cb=callbacks;this.z=.8;this.tx=30;this.ty=30;this.positions=new Map();this.install();}
 install(){
  this.canvas.addEventListener('wheel',e=>{e.preventDefault();const r=this.canvas.getBoundingClientRect();this.zoom(e.deltaY<0?1.12:1/1.12,e.clientX-r.left,e.clientY-r.top);},{passive:false});
  this.canvas.addEventListener('pointerdown',e=>{
   if(e.button!==0||e.target.closest('.fold'))return;
   const card=e.target.closest('.map-card');const start={x:e.clientX,y:e.clientY,tx:this.tx,ty:this.ty};let moved=false;
   const n=card?this.project.nodes.find(n=>n.id===card.dataset.id):null;const dx=n?.dx||0,dy=n?.dy||0;
   const move=ev=>{const x=ev.clientX-start.x,y=ev.clientY-start.y;if(Math.abs(x)+Math.abs(y)<5&&!moved)return;moved=true;if(n){const p=this.positions.get(n.id);card.style.left=(p.x+x/this.z)+'px';card.style.top=(p.y+y/this.z)+'px';}else{this.tx=start.tx+x;this.ty=start.ty+y;this.transform();}};
   const up=ev=>{window.removeEventListener('pointermove',move);window.removeEventListener('pointerup',up);if(n){if(moved)this.cb.drag(n.id,dx+(ev.clientX-start.x)/this.z,dy+(ev.clientY-start.y)/this.z);else this.cb.select(n.id);}this.canvas.style.cursor='';};
   window.addEventListener('pointermove',move);window.addEventListener('pointerup',up,{once:true});this.canvas.style.cursor=n?'grabbing':'move';
  });
 }
 render(project,selected,allLinks=false,viewRoot=null,compact=false,trail=[]){
  this.project=project;this.selected=selected;this.positions.clear();this.cards.replaceChildren();this.svg.replaceChildren();
  if(project.layout==='route')return this.renderRoute(project,selected,viewRoot,compact,trail);
  const nodes=new Map(project.nodes.map(n=>[n.id,n]));const children=new Map();project.nodes.forEach(n=>{if(!children.has(n.parentId))children.set(n.parentId,[]);children.get(n.parentId).push(n);});this.nodes=nodes;
  const heights=new Map();const height=n=>{const c=n.collapsed?[]:(children.get(n.id)||[]);const h=Math.max(144,c.reduce((a,b)=>a+height(b),0));heights.set(n.id,h);return h;};
  const root=nodes.get(viewRoot)||project.nodes.find(n=>!n.parentId);height(root);
  const place=(n,depth,top)=>{const p={x:40+depth*340+(n.dx||0),y:top+(heights.get(n.id)-118)/2+(n.dy||0)};this.positions.set(n.id,p);if(!n.collapsed){let t=top;for(const c of children.get(n.id)||[]){place(c,depth+1,t);t+=heights.get(c.id);}}};place(root,0,25);
  let maxX=600,maxY=400;for(const [id,p] of this.positions){const n=nodes.get(id);maxX=Math.max(maxX,p.x+320);maxY=Math.max(maxY,p.y+160);const card=document.createElement('div');card.className='map-card kind-'+n.kind+(selected===id?' selected':'');card.dataset.id=id;card.setAttribute('role','button');card.tabIndex=0;card.style.left=p.x+'px';card.style.top=p.y+'px';card.innerHTML=`<div class="card-top"><span>${esc(n.day?'第 '+n.day+' 天 · '+labels[n.kind]:labels[n.kind])}</span><span>${esc(n.status||'讨论草案')}</span></div><div class="card-title">${esc(n.title)}</div><div class="card-summary">${esc(n.summary)}</div>`;card.addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();this.cb.select(id);}});if(children.get(id)?.length){const b=document.createElement('button');b.className='fold';b.textContent=n.collapsed?'+':'−';b.title=n.collapsed?'展开子节点':'收起子节点';b.addEventListener('click',e=>{e.stopPropagation();this.cb.fold(id);});card.append(b);}this.cards.append(card);}
  this.svg.setAttribute('width',maxX);this.svg.setAttribute('height',maxY);this.bounds={w:maxX,h:maxY};
  for(const [id,p] of this.positions){const n=nodes.get(id);if(this.positions.has(n.parentId))this.line(n.parentId,id,'#bac9b4',false,'');}
  const representative=id=>{while(!this.positions.has(id)&&nodes.has(id)){id=nodes.get(id).parentId;}return id;};const drawn=new Set();
  for(const e of project.edges){if(!allLinks&&e.from!==selected&&e.to!==selected)continue;const from=representative(e.from),to=representative(e.to);if(!from||!to||from===to)continue;const key=from+':'+to;if(drawn.has(key))continue;drawn.add(key);this.line(from,to,e.kind==='merge'?'#a58daf':'#a6b1bc',true,e.label);}
  this.transform();
 }
 renderRoute(project,selected,viewRoot,compact,trail){
  const layout=routeLayout(project,compact,compact?null:project.nodes.find(n=>n.id===selected)?.round??0);this.positions=layout.positions;this.bounds={w:layout.width,h:layout.height};
  const active=trail.length?new Set(trail):(viewRoot?relatedRoute(project,viewRoot):null);
  this.svg.setAttribute('width',layout.width);this.svg.setAttribute('height',layout.height);
  const ns='http://www.w3.org/2000/svg',defs=document.createElementNS(ns,'defs');
  const marker=document.createElementNS(ns,'marker');marker.setAttribute('id','route-arrow');marker.setAttribute('viewBox','0 0 10 10');marker.setAttribute('refX','9');marker.setAttribute('refY','5');marker.setAttribute('markerWidth','6');marker.setAttribute('markerHeight','6');marker.setAttribute('orient','auto');
  const arrow=document.createElementNS(ns,'path');arrow.setAttribute('d','M 0 0 L 10 5 L 0 10 z');arrow.setAttribute('fill','#80968b');marker.append(arrow);defs.append(marker);this.svg.append(defs);
  for(const band of layout.bands){const div=document.createElement('div');div.className='round-band';div.style.top=band.y+'px';div.style.width=layout.width+'px';div.style.paddingLeft=Math.max(40,layout.width/2-280)+'px';div.innerHTML=`<strong>${esc(band.label)}</strong><span>${project.timelineMode==='events'?'沿箭头到达；层位不等于游戏日':band.round>0&&band.round<=18?'此前一天：普通愿望':''}</span>`;this.cards.append(div);}
  const by=new Map(project.nodes.map(n=>[n.id,n]));
  for(const [id,p] of this.positions){const n=by.get(id),card=document.createElement('div');card.className='map-card route-card kind-'+n.kind+(selected===id?' selected':'')+(active&&!active.has(id)?' dimmed':'');card.dataset.id=id;card.setAttribute('role','button');card.tabIndex=0;card.style.left=p.x+'px';card.style.top=p.y+'px';
   card.innerHTML=`<div class="card-top"><span>${esc((project.timelineMode==='events'?(n.routeCode||n.id)+' · ':n.round>0&&n.round<=18?'第'+n.round+'轮 · ':'')+labels[n.kind])}</span><span>${esc(n.status||'讨论草案')}</span></div><div class="card-title">${esc(n.title)}</div><div class="card-summary">${esc(n.summary)}</div><div class="card-options">${esc(n.options||n.effects||'')}</div>`;
   card.addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();this.cb.select(id);}});this.cards.append(card);
  }
  const groups=new Map();for(const e of layout.edges){if(!this.positions.has(e.from)||!this.positions.has(e.to))continue;const key=e.from+':'+e.to;if(!groups.has(key))groups.set(key,{...e,labels:[]});groups.get(key).labels.push(e.label);}
  for(const e of groups.values()){
   const a=this.positions.get(e.from),b=this.positions.get(e.to),g=document.createElementNS(ns,'g'),path=document.createElementNS(ns,'path');
   const lit=active?active.has(e.from)&&active.has(e.to):!selected||e.from===selected||e.to===selected,x=a.x+165,y=a.y+168,x2=b.x+165,y2=b.y;
   path.setAttribute('d',`M ${x} ${y} C ${x} ${y+45},${x2} ${y2-45},${x2} ${y2}`);path.setAttribute('fill','none');path.setAttribute('stroke',lit?'#80968b':'#cbd4cc');path.setAttribute('stroke-width',lit?'2':'1');path.setAttribute('marker-end','url(#route-arrow)');g.style.opacity=lit?'1':'.18';g.append(path);
   const t=document.createElementNS(ns,'text');t.setAttribute('x',x2);t.setAttribute('y',y2-14);t.setAttribute('text-anchor','middle');t.setAttribute('fill','#617c6d');t.setAttribute('font-size','11');t.setAttribute('paint-order','stroke');t.setAttribute('stroke','#f5f6ef');t.setAttribute('stroke-width','4');t.textContent=lit?(e.labels[0]?.slice(0,24)+(e.labels.length>1?' 等'+e.labels.length+'条':'')):'';const title=document.createElementNS(ns,'title');title.textContent=e.labels.join('\n')+(e.condition?'\n条件：'+e.condition:'');g.append(t,title);this.svg.append(g);
  }
  this.transform();
 }
 line(from,to,color,dashed,label){const a=this.positions.get(from),b=this.positions.get(to);if(!a||!b)return;const x=a.x+260,y=a.y+59,x2=b.x,y2=b.y+59;const ns='http://www.w3.org/2000/svg';const g=document.createElementNS(ns,'g');const p=document.createElementNS(ns,'path');const bend=Math.max(45,Math.abs(x2-x)*.5);p.setAttribute('d',`M ${x} ${y} C ${x+bend} ${y},${x2-bend} ${y2},${x2} ${y2}`);p.setAttribute('fill','none');p.setAttribute('stroke',color);p.setAttribute('stroke-width',dashed?'1.6':'1.3');if(dashed)p.setAttribute('stroke-dasharray','6 5');g.append(p);if(dashed){const t=document.createElementNS(ns,'text');t.setAttribute('x',(x+x2)/2);t.setAttribute('y',(y+y2)/2-8);t.setAttribute('fill',color);t.setAttribute('font-size','10');t.textContent=label.slice(0,18);g.append(t);}this.svg.append(g);}
 transform(){this.world.style.transform=`translate(${this.tx}px,${this.ty}px) scale(${this.z})`;document.querySelector('#zoom-value').textContent=Math.round(this.z*100)+'%';}
 zoom(factor,x=this.canvas.clientWidth/2,y=this.canvas.clientHeight/2){const z=Math.max(.12,Math.min(2.3,this.z*factor));this.tx=x-(x-this.tx)*z/this.z;this.ty=y-(y-this.ty)*z/this.z;this.z=z;this.transform();}
 fit(){if(!this.bounds)return;this.z=Math.max(.12,Math.min(1,(this.canvas.clientWidth-80)/this.bounds.w,(this.canvas.clientHeight-80)/this.bounds.h));this.tx=(this.canvas.clientWidth-this.bounds.w*this.z)/2;this.ty=(this.canvas.clientHeight-this.bounds.h*this.z)/2;this.transform();}
 focus(id){const p=this.positions.get(id);if(!p)return;this.z=Math.max(.7,Math.min(1.05,this.z));const route=this.project?.layout==='route';this.tx=this.canvas.clientWidth/2-(p.x+(route?165:130))*this.z;this.ty=this.canvas.clientHeight/2-(p.y+(route?84:59))*this.z;this.transform();}
}
