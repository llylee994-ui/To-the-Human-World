import {StoryMap,labels} from './map.js';
import {walkState,validWalk,stageLabel} from './routes.js';
const $=id=>document.getElementById(id),clone=x=>structuredClone(x);
let project,revision,token,selected=null,dirty=false,busy=false,blocked=false,generation=0,timer,undo=[],redo=[],lastTyping='',lastTyped=0,editingEdge=null,viewRoot=null,trail=[];
const map=new StoryMap($('canvas'),{select:selectNode,fold:id=>change(p=>{const n=p.nodes.find(n=>n.id===id);n.collapsed=!n.collapsed;}),drag:(id,dx,dy)=>change(p=>Object.assign(p.nodes.find(n=>n.id===id),{dx,dy}))});
let walkEdges=[],walkBranches=[],walkStale=false;
const walkKey='human-world-story-walk:'+location.pathname;
function persistWalk(nextTrail=trail,nextEdges=walkEdges){
 if(dirty||busy||blocked||walkStale){toast('故事图未保存或版本已变，请处理后重新开始试走');return false;}
 try{localStorage.setItem(walkKey,JSON.stringify({version:1,revision,trail:nextTrail,edges:nextEdges,branches:walkBranches,updatedAt:new Date().toISOString()}));return true;}
 catch{toast('试走自动存档失败，进度未推进；请检查浏览器存储空间');return false;}
}
function restoreWalk(){
 try{const saved=JSON.parse(localStorage.getItem(walkKey)||'null');if(!saved)return;
  if(!validWalk(project,saved,revision)){walkStale=true;toast('故事图版本已变化，旧试走记录保留；重新开始后才能沿新图试走');return;}
  trail=saved.trail;walkEdges=saved.edges;walkBranches=Array.isArray(saved.branches)?saved.branches.slice(-100):[];if(trail.length)selected=trail.at(-1);
 }catch{walkStale=true;toast('旧试走记录无法读取，请重新开始');}
}
function rewindWalk(index){
 const previous=walkBranches;
 walkBranches=[...walkBranches,{trail:clone(trail),edges:clone(walkEdges),updatedAt:new Date().toISOString()}].slice(-100);
 const next=trail.slice(0,index+1),edges=walkEdges.slice(0,index);
 if(!persistWalk(next,edges)){walkBranches=previous;return;}
 trail=next;walkEdges=edges;selectNode(trail.at(-1));
}
function followEdge(edge){
 if(walkStale)return toast('故事图版本已变化，请重新开始试走');
 if(trail.length&&trail.at(-1)!==selected)return toast('请从试走当前节点继续，或点击“从此处试走”建立新的起点');
 const base=trail.length?trail:[selected],next=[...base,edge.to],edges=[...walkEdges,edge.id];
 if(!persistWalk(next,edges))return;trail=next;walkEdges=edges;selectNode(edge.to);
}
function renderWalk(){
 const state=walkState(project,trail,walkEdges),list=$('walk-checkpoints');list.replaceChildren(new Option('选择前检查点',''));
 for(const c of state.checkpoints){const n=project.nodes.find(n=>n.id===c.nodeId);list.add(new Option(`${project.timelineMode==='events'?n.routeCode||n.id:'第'+n.round+'轮'} · ${n.title}（实现${c.chosen} / 丢弃${c.discarded}）`,String(c.index)));}
 $('walk-restore').disabled=!state.checkpoints.length||walkStale;
 const history=$('walk-history');history.replaceChildren(new Option('历史试走路线',''));
 walkBranches.forEach((branch,i)=>{if(validWalk(project,{version:1,revision,...branch},revision))history.add(new Option(`${i+1} · ${project.nodes.find(n=>n.id===branch.trail.at(-1))?.title||'起点'} · ${branch.trail.length}节点`,String(i)));});
 $('walk-open').disabled=!history.options.length||history.options.length===1||walkStale;
 $('walk-decisions').textContent=walkStale?'旧存档与当前图版本不同，记录仍保留。':state.checkpoints.length?`本路线：实现 ${state.selected.length} 份 / 丢回海里 ${state.discarded.length} 份 · 每步自动存档 · 历史路线 ${walkBranches.length} 条`:'两瓶互斥：一瓶实现，另一瓶丢回海里，不再重现。';
}
Object.entries(labels).forEach(([value,text])=>$('f-kind').add(new Option(text,value)));
function toast(text){$('toast').textContent=text;$('toast').classList.add('visible');setTimeout(()=>$('toast').classList.remove('visible'),2500);}
function status(text){$('save-status').textContent=text;}
function report(text,conflict=false){$('conflict').hidden=false;$('error-message').textContent=text;$('retry-save').hidden=conflict;status(conflict?'版本冲突 · 草稿已保留':'尚未保存');}
async function request(method='GET',body){const response=await fetch('/api/project',{method,headers:method==='POST'?{'Content-Type':'application/json','X-Editor-Token':token}:{},body:body?JSON.stringify(body):undefined});const data=await response.json();if(!response.ok){const e=new Error(data.error||'请求失败');e.code=response.status;throw e;}return data;}
function download(data,name){const url=URL.createObjectURL(new Blob([JSON.stringify(data,null,2)+'\n'],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),2000);}
function queueSave(){clearTimeout(timer);if(!blocked){status('未保存 · 正在等待写入');timer=setTimeout(save,650);}}
async function save(){if(!dirty||blocked||busy)return;busy=true;status('正在保存');const sentGeneration=generation;try{const result=await request('POST',{project:clone(project),revision});revision=result.revision;if(trail.length||walkBranches.length)walkStale=true;if(sentGeneration===generation){dirty=false;status('已保存');$('conflict').hidden=true;}else queueSave();}catch(e){blocked=e.code===409||!e.code;report(e.message,e.code===409);}finally{busy=false;if(dirty&&!blocked&&sentGeneration!==generation)queueSave();}}
function change(operation,typingKey=''){
 if(!project)return;
 const now=Date.now();if(!typingKey||typingKey!==lastTyping||now-lastTyped>900){undo.push(clone(project));if(undo.length>100)undo.shift();}lastTyping=typingKey;lastTyped=now;redo=[];
 operation(project);generation++;dirty=true;render(false);queueSave();
}
function childrenOf(id){return project.nodes.filter(n=>n.parentId===id);}
function descendants(id){const ids=new Set([id]);let changed=true;while(changed){changed=false;for(const n of project.nodes){if(ids.has(n.parentId)&&!ids.has(n.id)){ids.add(n.id);changed=true;}}}return ids;}
function visible(id){const by=new Map(project.nodes.map(n=>[n.id,n]));let n=by.get(id);while(n?.parentId){n=by.get(n.parentId);if(n)n.collapsed=false;}}
function selectNode(id){if(project.layout!=='route'&&viewRoot&&!descendants(viewRoot).has(id))viewRoot=null;selected=id;editingEdge=null;visible(id);const n=project.nodes.find(n=>n.id===id);if(project.layout==='route'&&['result','followup'].includes(n.kind))$('detail-results').checked=true;document.body.classList.remove('nav-open');document.body.classList.add('inspector-open');render(true);map.focus(id);}
function render(inspector=false){if(!project)return;if(viewRoot&&!project.nodes.some(n=>n.id===viewRoot))viewRoot=null;document.body.classList.toggle('route-mode',project.layout==='route');map.render(project,selected,$('show-links').checked,viewRoot,!$('detail-results').checked,trail);renderNav();renderWalk();$('project-count').textContent=project.nodes.length+' 个节点 · '+project.edges.length+' 条剧情连接';$('undo').disabled=!undo.length;$('redo').disabled=!redo.length;$('view-branch').disabled=!selected;$('walk-back').disabled=trail.length<2;$('walk-end').disabled=!trail.length;$('walk-status').textContent=trail.length?'已走 '+trail.length+' 个节点 · '+project.nodes.find(n=>n.id===trail.at(-1))?.title:'点击节点，在右侧选择一条后续 · 条件由作者核对';if(inspector)renderInspector();const n=project.nodes.find(n=>n.id===selected);$('selection-path').textContent=n?[labels[n.kind],n.title].join(' / '):'选择一个节点开始编辑';}
function renderNav(){
 const list=$('chapter-list');list.replaceChildren();
 if(project.layout==='route'){
  const rounds=[...new Set(project.nodes.map(n=>n.round))].sort((a,b)=>a-b);
  for(const round of rounds){const section=document.createElement('div');section.className='chapter';const heading=document.createElement('h3');heading.textContent=round===0?'开端':round>18?'身份结局':`第 ${round} 轮 · 主线`;heading.className='round-heading';section.append(heading);
   if(project.timelineMode==='events')heading.textContent=stageLabel(project,round);
   for(const n of project.nodes.filter(n=>n.round===round&&!['result','followup'].includes(n.kind))){const b=document.createElement('button');b.className='day-nav'+(selected===n.id?' selected':'');b.dataset.nav=n.id;b.textContent=(project.timelineMode==='events'&&n.routeCode?n.routeCode+' · ':'')+n.title;b.addEventListener('click',()=>selectNode(n.id));section.append(b);}list.append(section);
  }$('schedule-note').textContent=project.timelineMode==='events'?'事件先后编排；剧情结局到达即揭晓。船期、票期与经济日历另行校准。':'当前暂排18轮主线、36个交替日。票期、经济与考核另行调整。';
  const rhythm=document.querySelector('.rhythm p');rhythm.textContent=project.timelineMode==='events'?'主线有即时事件时与普通订单交替；等船可继续普通订单。剧情结束后，剩余普通订单按顺序连续完成，再判身份。':'第 1 天：普通愿望\n第 2 天：主线瓶子\n之后逐日交替';
  document.querySelector('.header-note').firstChild.textContent=project.timelineMode==='events'?'唯一归案路线 · 案件结束后连续普通订单':'普通愿望与主线 · 隔日交替';
  document.querySelector('.side-heading h2').textContent=project.timelineMode==='events'?'事件编排':'主线轮次';
  document.querySelector('.intro').textContent=project.timelineMode==='events'?'沿箭头读事件先后；同一场可由不同轮次到达。点击场景查看完整梗概。':'向下读时间，沿箭头看路线。点击某一轮，定位到具体场景。';
  document.querySelector('.mobile-controls span').textContent=project.timelineMode==='events'?'案件结束后连续普通订单':'普通与主线隔日交替';
  document.querySelector('label:has(#f-round)').firstChild.textContent=project.timelineMode==='events'?'编排层（非日期）':'主线轮次';
  renderSearch();return;
 }
 for(const act of project.nodes.filter(n=>n.kind==='act')){const section=document.createElement('div');section.className='chapter';const b=document.createElement('button');b.className='chapter-title';b.textContent=act.title;b.addEventListener('click',()=>selectNode(act.id));section.append(b);
  for(const n of childrenOf(act.id).filter(n=>n.day||n.kind==='merge')){const button=document.createElement('button');button.className='day-nav'+(n.kind==='ordinary'?' ordinary':'')+(selected===n.id?' selected':'');button.dataset.nav=n.id;const day=document.createElement('span');day.textContent=n.day?'D'+String(n.day).padStart(2,'0'):'◆';button.append(day,document.createTextNode(n.title));button.addEventListener('click',()=>selectNode(n.id));section.append(button);}list.append(section);
 }renderSearch();
}
function renderSearch(){const q=$('search').value.trim().toLowerCase();const results=$('search-results');results.replaceChildren();if(!q)return;for(const n of project.nodes.filter(n=>[n.id,n.title,n.summary].join(' ').toLowerCase().includes(q)).slice(0,25)){const b=document.createElement('button');b.textContent=n.title;b.addEventListener('click',()=>selectNode(n.id));results.append(b);}}
function renderInspector(){
 const n=project.nodes.find(n=>n.id===selected);$('empty-inspector').hidden=!!n;$('node-editor').hidden=!n;$('node-id').textContent=n?.id||'—';if(!n)return;
 $('f-templateId').replaceChildren(new Option('独立场景 / 不共用模板',''));for(const t of project.templates||[])$('f-templateId').add(new Option(t.title,t.id));
 if(n.status&&![...$('f-status').options].some(o=>o.value===n.status))$('f-status').add(new Option(n.status,n.status));
 for(const key of ['title','kind','summary','conditions','effects','notes','status','day','round','step','templateId','context','options','unselected'])$('f-'+key).value=n[key]??(key==='status'?'讨论草案':'');
 $('template-preview').textContent=(project.templates||[]).find(t=>t.id===n.templateId)?.summary||'本节点独立编写。模板提供共用结构，前情和梗概保存本路线的具体内容。';
 const excluded=descendants(n.id);$('f-parent').replaceChildren();$('edge-target').replaceChildren();
 for(const other of project.nodes){if(!excluded.has(other.id))$('f-parent').add(new Option(other.title,other.id));if(other.id!==n.id)$('edge-target').add(new Option(other.title,other.id));}
 if(!n.parentId){$('f-parent').add(new Option('故事根节点',''));$('f-parent').value='';$('f-parent').disabled=true;$('f-kind').disabled=true;}else{$('f-parent').value=n.parentId;$('f-parent').disabled=false;$('f-kind').disabled=false;}
 $('toggle-node').textContent=n.collapsed?'展开':'收起';$('toggle-node').disabled=!childrenOf(n.id).length;$('toggle-node').hidden=project.layout==='route';$('delete-node').disabled=!n.parentId;$('duplicate-node').disabled=!n.parentId;
 $('edge-label').value='';$('edge-condition').value='';$('add-edge').textContent='＋ 连接后续';renderEdges();
}
function renderEdges(){
 const list=$('edge-list');list.replaceChildren();const headings=new Set();
 for(const e of project.edges.filter(e=>e.from===selected||e.to===selected)){const row=document.createElement('div');row.className='edge-row';const outgoing=e.from===selected;if(outgoing&&e.wish&&!headings.has(e.wish)){const heading=document.createElement('h4');heading.className='wish-heading';heading.textContent='实现'+e.wish+' · 未选'+(e.wish==='A'?'B':'A')+'装瓶丢回海里';list.append(heading);headings.add(e.wish);}const target=project.nodes.find(n=>n.id===(outgoing?e.to:e.from));const b=document.createElement('button');b.textContent=(outgoing?'→ ':'← ')+target.title;b.addEventListener('click',()=>selectNode(target.id));const del=document.createElement('button');del.className='remove-edge';del.textContent='×';del.title='删除这条连接';del.addEventListener('click',()=>{change(p=>{p.edges=p.edges.filter(x=>x.id!==e.id);});renderEdges();});const p=document.createElement('p');p.textContent=(e.wish?'实现 '+e.wish+' / 丢弃 '+(e.wish==='A'?'B':'A')+' · ':'')+e.label+(e.condition?' · '+e.condition:'');row.append(del,b,p);if(outgoing){const edit=document.createElement('button');edit.textContent='编辑连线';edit.addEventListener('click',()=>{editingEdge=e.id;$('edge-target').value=e.to;$('edge-label').value=e.label||'';$('edge-condition').value=e.condition||'';$('add-edge').textContent='保存连线修改';});row.append(edit);if(project.layout==='route'){const walk=document.createElement('button');walk.className='walk-edge';walk.dataset.edge=e.id;walk.textContent='沿此路试走';walk.addEventListener('click',()=>followEdge(e));row.append(walk);}}list.append(row);}
}
for(const key of ['title','kind','summary','conditions','effects','notes','status','day','parent','round','step','templateId','context','options','unselected'])$('f-'+key).addEventListener('input',()=>{
 const id=selected;if(!id)return;let value=$('f-'+key).value;if(['day','round','step'].includes(key))value=value===''?null:Number(value);
 change(p=>{p.nodes.find(n=>n.id===id)[key==='parent'?'parentId':key]=value;},id+':'+key);
 if(key==='parent')visible(id);
 if(key==='templateId')$('template-preview').textContent=(project.templates||[]).find(t=>t.id===value)?.summary||'本节点独立编写。';
});
function newId(){return 'node_'+crypto.randomUUID().replaceAll('-','').slice(0,16);}
function validateImport(value){
 const require=(ok,message)=>{if(!ok)throw new Error(message);};
 require(value&&value.format==='human-world-story'&&value.version===1&&Array.isArray(value.nodes)&&Array.isArray(value.edges),'不是支持的故事图JSON');
 require(value.nodes.length>0&&value.nodes.length<=2500&&value.edges.length<=6000,'节点或连接数量超出限制');
 require(typeof value.title==='string'&&value.title.length>0&&value.title.length<=300,'项目名称无效');
 const by=new Map();
 for(const n of value.nodes){
  require(n&&typeof n.id==='string'&&/^[A-Za-z0-9_-]{1,100}$/.test(n.id)&&!by.has(n.id),'节点ID无效或重复');
  require(Object.hasOwn(labels,n.kind)&&typeof n.title==='string'&&n.title.length>0&&n.title.length<=300,'节点类型或标题无效');
  for(const key of ['summary','conditions','effects','notes','status','context','options','unselected','wishAId','wishBId','templateId'])require(n[key]===undefined||typeof n[key]==='string'&&n[key].length<=60000,'节点文字格式无效');
  for(const key of ['dx','dy'])require(n[key]===undefined||typeof n[key]==='number'&&Number.isFinite(n[key])&&Math.abs(n[key])<=100000,'节点位置无效');
  require(n.day==null||Number.isInteger(n.day)&&n.day>0&&n.day<=9999,'节点日期无效');
  if(n.day!=null&&['ordinary','main','choice'].includes(n.kind))require(n.day%2===(n.kind==='ordinary'?1:0),'普通愿望放奇数日，主线放偶数日');
  by.set(n.id,n);
 }
 const roots=value.nodes.filter(n=>n.parentId==null);require(roots.length===1&&roots[0].kind==='root','须保留一个故事根节点');
 const templateIds=new Set();require(value.templates===undefined||Array.isArray(value.templates)&&value.templates.length<=200,'模板库格式无效');for(const t of value.templates||[]){require(t&&typeof t.id==='string'&&/^[A-Za-z0-9_-]{1,100}$/.test(t.id)&&!templateIds.has(t.id)&&typeof t.title==='string'&&t.title.length>0&&t.title.length<=300&&typeof t.summary==='string'&&t.summary.length>0&&t.summary.length<=60000,'模板格式无效');templateIds.add(t.id);}for(const n of value.nodes){require(!n.templateId||templateIds.has(n.templateId),'场景模板不存在');if(value.layout==='route')require(Number.isInteger(n.round)&&n.round>=0&&n.round<=999&&Number.isInteger(n.step)&&n.step>=0&&n.step<=99,'轮次或轮内步骤无效');}
 for(const node of value.nodes){let n=node;const seen=new Set();while(n.parentId!=null){require(!seen.has(n.id)&&by.has(n.parentId),'父级不存在或形成循环');seen.add(n.id);n=by.get(n.parentId);}}
 const ids=new Set();for(const e of value.edges){require(e&&typeof e.id==='string'&&!ids.has(e.id)&&by.has(e.from)&&by.has(e.to)&&e.from!==e.to,'连接端点不存在或ID重复');ids.add(e.id);for(const key of ['label','condition','kind'])require(e[key]===undefined||typeof e[key]==='string'&&e[key].length<=2000,'连接文字无效');require(e.wish===undefined||['A','B'].includes(e.wish),'出口选瓶只能是A或B');if(value.layout==='route'){const a=by.get(e.from),b=by.get(e.to);require(a.round*100+a.step<b.round*100+b.step,'后续必须向后推进');}}
}
$('add-child').addEventListener('click',()=>{const id=newId();change(p=>{const from=p.nodes.find(n=>n.id===selected),route=p.layout==='route';p.nodes.push({id,parentId:route?p.nodes.find(n=>n.kind==='root').id:selected,kind:'result',title:'新节点',summary:'',conditions:'',effects:'',notes:'',status:'讨论草案',dx:0,dy:0,...(route?{round:from.round,step:from.step+1,context:'',options:'',templateId:''}:{})});if(route)p.edges.push({id:newId(),from:selected,to:id,label:'新增后续',condition:'',kind:'next'});from.collapsed=false;});selectNode(id);});
$('duplicate-node').addEventListener('click',()=>{const ids=descendants(selected),mapping=new Map([...ids].map(id=>[id,newId()]));const next=mapping.get(selected);change(p=>{const originals=p.nodes.filter(n=>ids.has(n.id));for(const original of originals){const n=clone(original);n.id=mapping.get(original.id);n.parentId=mapping.get(original.parentId)||original.parentId;n.title=original.id===selected?original.title+' · 副本':original.title;p.nodes.push(n);}for(const original of [...p.edges].filter(e=>ids.has(e.from))){p.edges.push({...clone(original),id:newId(),from:mapping.get(original.from),to:mapping.get(original.to)||original.to});}});selectNode(next);});
$('delete-node').addEventListener('click',()=>{const ids=descendants(selected);if(!confirm('删除此节点及其 '+(ids.size-1)+' 个子节点？相关连接也会删除，可以撤销。'))return;const parent=project.nodes.find(n=>n.id===selected).parentId;change(p=>{p.nodes=p.nodes.filter(n=>!ids.has(n.id));p.edges=p.edges.filter(e=>!ids.has(e.from)&&!ids.has(e.to));});selectNode(parent);});
$('toggle-node').addEventListener('click',()=>{change(p=>{const n=p.nodes.find(n=>n.id===selected);n.collapsed=!n.collapsed;});$('toggle-node').textContent=project.nodes.find(n=>n.id===selected).collapsed?'展开':'收起';});
$('add-edge').addEventListener('click',()=>{const to=$('edge-target').value;if(!to)return;if(project.layout==='route'){const a=project.nodes.find(n=>n.id===selected),b=project.nodes.find(n=>n.id===to);if(a.round*100+a.step>=b.round*100+b.step)return toast('后续须向后推进，请选择后面的轮次或步骤');}const info={from:selected,to,label:$('edge-label').value||'后续',condition:$('edge-condition').value,kind:'merge'};change(p=>{if(editingEdge){Object.assign(p.edges.find(e=>e.id===editingEdge),info);}else p.edges.push({id:newId(),...info});});editingEdge=null;$('add-edge').textContent='＋ 连接后续';renderEdges();toast('后续连接已添加');});
function restore(direction){if(blocked)return toast('先处理版本冲突，再撤销');const src=direction==='undo'?undo:redo,dst=direction==='undo'?redo:undo;if(!src.length)return;dst.push(clone(project));project=src.pop();if(!project.nodes.some(n=>n.id===selected))selected=null;generation++;dirty=true;lastTyping='';render(true);queueSave();}
$('undo').addEventListener('click',()=>restore('undo'));$('redo').addEventListener('click',()=>restore('redo'));
window.addEventListener('keydown',e=>{const typing=e.target.matches('input,textarea,select');if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='s'){e.preventDefault();clearTimeout(timer);save();}if(!typing&&(e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='z'){e.preventDefault();restore(e.shiftKey?'redo':'undo');}});
$('search').addEventListener('input',renderSearch);
$('toggle-nav').addEventListener('click',()=>{document.body.classList.remove('inspector-open');document.body.classList.toggle('nav-open');});
$('toggle-inspector').addEventListener('click',()=>{document.body.classList.remove('nav-open');document.body.classList.toggle('inspector-open');});
$('close-inspector').addEventListener('click',()=>{document.body.classList.remove('inspector-open');if(selected)map.focus(selected);});
window.addEventListener('resize',()=>project?.layout==='route'?map.focus(selected||project.nodes.find(n=>n.kind==='root').id):map.fit());
$('zoom-in').addEventListener('click',()=>map.zoom(1.2));$('zoom-out').addEventListener('click',()=>map.zoom(1/1.2));$('overview').addEventListener('click',()=>{viewRoot=null;render(false);map.fit();});$('show-links').addEventListener('change',()=>render(false));
$('start-view').addEventListener('click',()=>{viewRoot=null;selectNode(project.nodes.find(n=>n.kind==='root').id);});
$('detail-results').addEventListener('change',()=>{render(false);if(map.positions.has(selected))map.focus(selected);});
$('walk-start').addEventListener('click',()=>{
 if(dirty||busy||blocked)return toast('请等待故事图保存后开始');
 const wasStale=walkStale,oldBranches=walkBranches;
 try{const previous=localStorage.getItem(walkKey);if(previous&&walkStale)localStorage.setItem(walkKey+':previous',previous);}catch{return toast('存档备份失败，无法开始新的试走');}
 if(walkStale)walkBranches=[];
 else if(trail.length)walkBranches=[...walkBranches,{trail:clone(trail),edges:clone(walkEdges),updatedAt:new Date().toISOString()}].slice(-100);
 walkStale=false;
 const next=[selected||project.nodes.find(n=>n.kind==='root').id];
 if(!persistWalk(next,[])){walkStale=wasStale;walkBranches=oldBranches;return;}trail=next;walkEdges=[];selectNode(next[0]);
});
$('walk-open').addEventListener('click',()=>{
 const index=$('walk-history').value;if(index==='')return;
 const branch=walkBranches[Number(index)];if(!validWalk(project,{version:1,revision,...branch},revision))return toast('历史路线与当前图不匹配');
 const oldBranches=walkBranches;walkBranches=[...walkBranches,{trail:clone(trail),edges:clone(walkEdges),updatedAt:new Date().toISOString()}].slice(-100);
 if(!persistWalk(branch.trail,branch.edges)){walkBranches=oldBranches;return;}trail=clone(branch.trail);walkEdges=clone(branch.edges);selectNode(trail.at(-1));
});
$('walk-restore').addEventListener('click',()=>{const index=$('walk-checkpoints').value;if(index!=='')rewindWalk(Number(index));});
$('walk-export').addEventListener('click',()=>{try{const saved=JSON.parse(localStorage.getItem(walkKey)||'null');if(saved)download(saved,'寄往人间-试走存档.json');else toast('尚无试走存档');}catch{toast('存档无法读取');}});
$('walk-back').addEventListener('click',()=>{if(trail.length>1)rewindWalk(trail.length-2);});
$('walk-end').addEventListener('click',()=>{trail=[];walkEdges=[];render(false);});
$('view-branch').addEventListener('click',()=>{if(!selected)return;viewRoot=selected;project.nodes.find(n=>n.id===selected).collapsed=false;render(true);if(project.layout==='route')map.focus(selected);else map.fit();});
$('collapse-all').addEventListener('click',()=>{change(p=>{p.nodes.filter(n=>n.kind==='act').forEach(n=>n.collapsed=true);});map.fit();});
$('expand-level').addEventListener('click',()=>{const visibleIds=new Set(map.positions.keys());change(p=>{p.nodes.filter(n=>visibleIds.has(n.id)).forEach(n=>n.collapsed=false);});map.fit();});
$('download-draft').addEventListener('click',()=>download(project,'寄往人间-未保存草稿.json'));
$('export').addEventListener('click',()=>{download(project,'寄往人间-主线故事图.json');if(dirty)toast('已导出当前草稿，含尚未保存的修改');});
$('retry-save').addEventListener('click',()=>{blocked=false;save();});
async function loadLatest(){const data=await request();project=data.project;revision=data.revision;token=data.token;dirty=false;blocked=false;busy=false;undo=[];redo=[];trail=[];walkEdges=[];walkBranches=[];walkStale=false;restoreWalk();clearTimeout(timer);lastTyping='';$('conflict').hidden=true;status('已保存');if(!project.nodes.some(n=>n.id===selected))selected=null;render(true);}
$('reload-latest').addEventListener('click',async()=>{try{await loadLatest();toast('已载入最新版本');}catch(e){report(e.message);}});
$('import-file').addEventListener('change',async e=>{const file=e.target.files[0];if(!file)return;try{if(file.size>12*1024*1024)throw new Error('文件超过12MB');const value=JSON.parse(await file.text());validateImport(value);if(!confirm('用导入的故事图替换当前图？保存前的版本会自动备份，也可撤销。'))return;selected=null;viewRoot=null;trail=[];change(p=>{Object.keys(p).forEach(k=>delete p[k]);Object.assign(p,value);});render(true);map.fit();}catch(error){toast(error.message);}finally{e.target.value='';}});
window.addEventListener('beforeunload',e=>{if(dirty||busy){e.preventDefault();e.returnValue='';}});
setInterval(async()=>{if(!project||busy||blocked)return;try{const data=await request();if(data.revision!==revision){if(dirty){blocked=true;clearTimeout(timer);report('其他窗口或Codex已修改，当前草稿保留在此窗口。',true);}else{project=data.project;revision=data.revision;token=data.token;undo=[];redo=[];walkStale=true;if(!project.nodes.some(n=>n.id===selected))selected=null;render(true);status('已保存');toast('已同步其他窗口的修改');}}}catch(e){if(!blocked){blocked=true;report('连接中断，草稿保留。请恢复服务后重试保存或载入最新版本。');}}},1800);
try{await loadLatest();if(project.layout==='route')map.focus(selected||project.nodes.find(n=>n.kind==='root').id);else map.fit();}catch(e){report('载入失败：'+e.message);}
