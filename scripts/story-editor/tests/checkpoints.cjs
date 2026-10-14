const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
(async()=>{
 const source=fs.readFileSync(path.join(__dirname,'../web/routes.js'),'utf8');
 const api=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
 assert.equal(typeof api.walkState,'function','需要重建选择与丢弃记录');
 const project={nodes:[{id:'c',kind:'choice',options:'A · 少年：作证\nB · 商人：关门',unselected:'A · 证词缺失\nB · 仓库没有额外保护',wishAId:'test-a',wishBId:'test-b'},{id:'a'},{id:'b'}],edges:[{id:'a-edge',from:'c',to:'a',wish:'A'},{id:'b-edge',from:'c',to:'b',wish:'B'}]};
 const a=api.walkState(project,['c','a'],['a-edge']);
 assert.deepEqual(a.selected,['test-a']);assert.deepEqual(a.discarded,['test-b']);
 assert.deepEqual(a.checkpoints,[{index:0,nodeId:'c',chosen:'A',discarded:'B'}]);
 const before=api.walkState(project,['c'],[]);assert.deepEqual(before.selected,[]);assert.deepEqual(before.discarded,[]);
 const b=api.walkState(project,['c','b'],['b-edge']);assert.deepEqual(b.selected,['test-b']);assert.deepEqual(b.discarded,['test-a']);
 const saved={version:1,revision:'v1',trail:['c','a'],edges:['a-edge'],branches:[]};
 assert.equal(api.validWalk(project,saved,'v1'),true);
 assert.equal(api.validWalk(project,saved,'v2'),false,'改图后旧存档不能继续');
 assert.equal(api.validWalk(project,{...saved,edges:['missing']},'v1'),false);
 assert.equal(api.validWalk(project,{...saved,trail:['c','b']},'v1'),false);
 console.log('PASS 互斥记录、回到选择前、换路不合并、存档版本与实际边校验');
})().catch(e=>{console.error(e);process.exitCode=1;});
