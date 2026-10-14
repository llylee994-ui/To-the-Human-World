// Route operations deliberately ignore the content-directory parentId.
export function stageLabel(project,round){
 if(project.timelineMode==='events')return project.stageLabels?.[round]||`事件编排层 ${round}（非固定日期）`;
 return round===0?'故事开端':round<=18?`第 ${round} 轮主线 · 暂排第 ${round*2} 天`:'结局';
}
export function walkState(project,trail,edges){
 const selected=[],discarded=[],checkpoints=[];
 for(let i=0;i<edges.length;i++){
  const edge=project.edges.find(e=>e.id===edges[i]),node=project.nodes.find(n=>n.id===trail[i]);
  if(node?.kind!=='choice'||!['A','B'].includes(edge?.wish))continue;
  const other=edge.wish==='A'?'B':'A';
  selected.push(node['wish'+edge.wish+'Id']||node.id+':'+edge.wish);
  discarded.push(node['wish'+other+'Id']||node.id+':'+other);
  checkpoints.push({index:i,nodeId:node.id,chosen:edge.wish,discarded:other});
 }
 return {selected,discarded,checkpoints};
}
export function validWalk(project,saved,revision){
 if(!saved||saved.version!==1||saved.revision!==revision||!Array.isArray(saved.trail)||!Array.isArray(saved.edges)||saved.trail.length>2500||saved.edges.length!==Math.max(0,saved.trail.length-1))return false;
 const ids=new Set(project.nodes.map(n=>n.id));
 return saved.trail.every(id=>ids.has(id))&&saved.edges.every((id,i)=>project.edges.some(e=>e.id===id&&e.from===saved.trail[i]&&e.to===saved.trail[i+1]));
}
export function relatedRoute(project,id){
 const found=new Set([id]);
 for(const direction of ['forward','backward']){
  const reached=new Set([id]),queue=[id];
  while(queue.length){const at=queue.shift();for(const e of project.edges){const from=direction==='forward'?e.from:e.to,to=direction==='forward'?e.to:e.from;if(from===at&&!reached.has(to)){reached.add(to);found.add(to);queue.push(to);}}}
 }
 return found;
}
export function sceneEdges(project,expandedRound=null){
 const hidden=new Set(project.nodes.filter(n=>['result','followup'].includes(n.kind)&&n.round!==expandedRound).map(n=>n.id));
 const outgoing=new Map();for(const e of project.edges){if(!outgoing.has(e.from))outgoing.set(e.from,[]);outgoing.get(e.from).push(e);}
 const result=[];
 for(const n of project.nodes){if(hidden.has(n.id))continue;const walk=(at,labels,conditions,path)=>{
  for(const e of outgoing.get(at)||[]){if(path.has(e.to))continue;const nextLabels=[...labels,e.label].filter(Boolean),nextConditions=[...conditions,e.condition].filter(Boolean);
   if(hidden.has(e.to))walk(e.to,nextLabels,nextConditions,new Set([...path,e.to]));
   else result.push({id:'compact_'+result.length,from:n.id,to:e.to,label:nextLabels.join(' → '),condition:nextConditions.join('；'),kind:e.kind});
  }
 };walk(n.id,[],[],new Set([n.id]));}
 return result;
}
export function routeLayout(project,compact=false,expandedRound=null){
 const limited=!compact&&expandedRound!==null;
 const nodes=project.nodes.filter(n=>n.kind!=='act'&&n.kind!=='ordinary'&&(!['result','followup'].includes(n.kind)||!compact&&(!limited||n.round===expandedRound)));
 const edges=compact||limited?sceneEdges(project,limited?expandedRound:null):project.edges;
 const groups=new Map();for(const n of nodes){const rank=(n.round||0)*100+(n.step||0);if(!groups.has(rank))groups.set(rank,[]);groups.get(rank).push(n);}
 const width=Math.max(900,...[...groups.values()].map(g=>g.length*380+240));
 const positions=new Map(),bands=[];let y=50,lastRound=-1;
 for(const [rank,group] of [...groups].sort((a,b)=>a[0]-b[0])){
  const round=Math.floor(rank/100);
  if(round!==lastRound){if(lastRound>=0)y+=85;bands.push({round,y:y-62,label:stageLabel(project,round)});lastRound=round;}
  const score=n=>{const parents=edges.filter(e=>e.to===n.id).map(e=>positions.get(e.from)?.x).filter(x=>x!==undefined);return parents.length?parents.reduce((a,b)=>a+b,0)/parents.length:width/2;};
  group.sort((a,b)=>score(a)-score(b));
  group.forEach((n,i)=>positions.set(n.id,{x:(width-group.length*380)/2+i*380+(n.dx||0),y:y+(n.dy||0)}));y+=265;
 }
 return {positions,bands,edges,width,height:y+70};
}
