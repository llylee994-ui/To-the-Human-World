const fs=require('node:fs');
const assert=require('node:assert/strict');
(async()=>{
 const source=fs.readFileSync(require('node:path').join(__dirname,'../web/routes.js'),'utf8');
 const {routeLayout,relatedRoute,sceneEdges}=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
 const project={layout:'route',nodes:[
  {id:'start',kind:'root',round:0,step:0,parentId:null},
  {id:'a',kind:'choice',round:1,step:0,parentId:'start'},
  {id:'b',kind:'result',round:1,step:1,parentId:'start'},
  {id:'c',kind:'result',round:1,step:1,parentId:'start'},
  {id:'d',kind:'choice',round:2,step:0,parentId:'start'},
  {id:'e',kind:'choice',round:2,step:0,parentId:'start'},
  {id:'finish',kind:'ending',round:4,step:0,parentId:'start'}
 ],edges:[['start','a'],['a','b'],['a','c'],['b','d'],['c','e'],['d','finish'],['e','finish']].map(([from,to],i)=>({id:'e'+i,from,to,label:from+'>'+to}))};
 const pos=routeLayout(project,false).positions;
 assert.ok(pos.get('a').y<pos.get('b').y && pos.get('b').y<pos.get('d').y);
 assert.equal(pos.get('b').y,pos.get('c').y);
 assert.notEqual(pos.get('d').x,pos.get('e').x);
 const related=relatedRoute(project,'d');
 assert.deepEqual([...related].sort(),['a','b','d','finish','start']);
 const compact=sceneEdges(project);
 assert.ok(compact.some(e=>e.from==='a'&&e.to==='d'&&e.label.includes('a>b')));
 assert.ok(!compact.some(e=>e.from==='a'&&e.to==='finish'));
 assert.ok(!routeLayout(project,true).positions.has('b'));
 const partial=routeLayout(project,false,1);
 assert.ok(partial.positions.has('b')&&partial.positions.has('c'));
 assert.ok(partial.edges.some(e=>e.from==='b'&&e.to==='d'));
 const eventProject={...project,timelineMode:'events',stageLabels:{1:'调查选择 · 非固定日历',4:'剧情结果 · 到达即揭晓'}};
 const events=routeLayout(eventProject,true);
 assert.equal(events.bands.find(b=>b.round===1).label,'调查选择 · 非固定日历');
 assert.equal(events.bands.find(b=>b.round===4).label,'剧情结果 · 到达即揭晓');
 console.log('PASS 实际边布局、轮次分层、相关路线和结果折叠');
})().catch(e=>{console.error(e);process.exitCode=1;});
