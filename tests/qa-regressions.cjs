// Run: node --test tests/qa-regressions.cjs
// Exercise the actual inline game functions without a browser or external packages.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const html=fs.readFileSync(path.join(__dirname,'../index.html'),'utf8');
function fn(name){
  const start=html.indexOf('function '+name+'(');assert.ok(start>=0,name);
  const lines=html.slice(start).split('\n');let code='';
  for(const line of lines){code+=line+'\n';try{new vm.Script(code);return code;}catch(e){if(!(e instanceof SyntaxError))throw e;}}
  throw Error('Incomplete function '+name);
}
function fixture(){return {ter:[0,0,0,0],rev:[1,1,1,1],hp:[0,0,0,0],lv:1,seed:1,m:{wood:30},mods:{},sv:{0:{xp:40,at:-1},1:{xp:0,at:-1},2:{xp:0,at:-1}},asg:{},exp:{},ash:{},diaryAt:{},got:{},frac:{},cd:{},found:[],party:[],pets:{dog:{xp:0}},pf:{portrait:1,name:'QA'},inv:[],ug:{best:15,runs:0}};}
function context(){
  const c={S:fixture(),N:4,LVNAME:["텐트"],SHELTER:Array(5),MODS:[null,{id:1}],SURV:Array.from({length:18},(_,i)=>({name:'s'+i})),PETS:{dog:{}},EXPS:[{key:'mall',min:1,name:'mall'},{key:'road',min:1,name:'road'},{key:'apt',min:2,name:'apt'},{key:'plant',min:3,name:'plant'}],expNotified:{},messages:[],saved:[],Date,Set,Number,Object,JSON,
    recalc(){},closeModal(){},closeSheet(){},closeRing(){},centerCam(){},ensureAim(){},renderMission(){},renderSkills(){},fixDiaries(){},KEY:'test',fresh(){throw Error('unexpected fresh reset');},
    toast(m){c.messages.push(m);},note(m){c.messages.push(m);},save(){c.saved.push(JSON.parse(JSON.stringify(c.S)));},
    give(o){return o;},addGear(){},pets(){return c.S.pets;},petGain(k,n){c.S.pets[k].xp+=n;},lootTxt(o){return JSON.stringify(o);},GEAR:{lever:{n:'lever'}},
    setTimeout(f){c.timer=f;},sfx(){},buzz(){},renderUG(){},ugResolve(){},ugFront(){return true;},ugUse(){},
    atob:s=>Buffer.from(s,'base64').toString('binary'),escape,decodeURIComponent};
  vm.createContext(c);for(const name of ['validExpedition','invalidExpeditions','repairExpeditions','tickExp','validImport','load','applyCode','ugRewardUnits','ugEnd','ugTap'])vm.runInContext(fn(name),c);
  return c;
}
const exp=(team=[0])=>({team,end:Date.now()+60000,dur:60});
test('all inline scripts compile',()=>{for(const m of html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/g))if(m[1].trim())new vm.Script(m[1]);});
test('valid saves and legacy expedition without pet remain valid',()=>{const c=context();assert.equal(c.validImport(c.S),true);c.S.exp.mall=exp();assert.equal(c.validImport(c.S),true);c.S.exp.mall.pet='dog';assert.equal(c.validImport(c.S),true);});
for(const [name,change]of Object.entries({
  unknown:s=>s.exp.unknown=exp(),null:s=>s.exp.mall=null,missingTeam:s=>s.exp.mall={end:1,dur:60},
  missingSurvivor:s=>s.exp.mall=exp([17]),unknownSurvivor:s=>s.exp.mall=exp([99]),stringId:s=>s.exp.mall=exp(['0']),
  duplicateMember:s=>s.exp.mall=exp([0,0]),emptyTeam:s=>s.exp.mall=exp([]),tooMany:s=>s.exp.mall=exp([0,1,2,3]),
  shortTeam:s=>s.exp.plant=exp([0]),badEnd:s=>s.exp.mall={...exp(),end:'1'},zeroDuration:s=>s.exp.mall={...exp(),dur:0},
  missingDuration:s=>s.exp.mall={team:[0],end:1},unknownPet:s=>s.exp.mall={...exp(),pet:'missing'},
  unownedPet:s=>{s.pets={};s.exp.mall={...exp(),pet:'dog'};},duplicateAcross:s=>{s.exp.mall=exp();s.exp.road=exp();},
  sharedPet:s=>{s.exp.mall={...exp([0]),pet:'dog'};s.exp.road={...exp([1]),pet:'dog'};}
}))test('reject corrupt expedition: '+name,()=>{const c=context();change(c.S);assert.equal(c.validImport(c.S),false);});
test('rejected code keeps the previous state and does not save it',()=>{const c=context(),previous=c.S,bad=fixture();bad.exp.unknown=exp();c.applyCode('TTC1.'+Buffer.from(JSON.stringify(bad)).toString('base64'));assert.equal(c.S,previous);assert.equal(c.saved.length,0);assert.match(c.messages[0],/올바르지/);});
test('valid code restores expedition and resets arrival notifications',()=>{const c=context(),s=fixture();s.exp.mall=exp();c.expNotified.mall=1;c.applyCode('TTC1.'+Buffer.from(JSON.stringify(s)).toString('base64'));assert.equal(c.S.exp.mall.team[0],0);assert.equal(c.S.sv[0].away,'mall');assert.equal(c.expNotified.mall,undefined);assert.equal(c.saved.length,1);assert.equal(c.S.pf.portrait,1);});
test('old local corruption is repaired without losing progress',()=>{const c=context(),s=fixture();s.exp.mall=exp([1]);s.exp.unknown=exp([0]);s.sv[0].away='unknown';s.pets.dog.away='unknown';assert.equal(c.load(s),true);assert.equal(c.S,s);assert.equal(s.m.wood,30);assert.equal(s.exp.unknown,undefined);assert.ok(s.exp.mall);assert.equal(s.sv[0].away,false);assert.equal(s.pets.dog.away,false);assert.equal(s.sv[1].away,'mall');});
test('tick survives malformed entries and notifies a valid return once',()=>{const c=context();c.S.exp={unknown:exp(),road:null,mall:{...exp([1]),end:1}};c.tickExp();c.tickExp();assert.equal(c.messages.length,1);assert.match(c.messages[0],/돌아왔어요/);});
function run(c,floor,explored,pet='dog'){c.UG={floor,exploredFloors:explored,team:[0],pet,carry:{wood:8},gear:['lever'],hurt:[],cells:[],oil:8};}
for(const floor of [1,5,10,15])test('checkpoint '+floor+' immediate return grants no survivor or pet XP',()=>{const c=context();for(let i=0;i<3;i++){run(c,floor,[]);c.ugEnd(true);}assert.equal(c.S.sv[0].xp,40);assert.equal(c.S.pets.dog.xp,0);assert.match(c.messages.at(-1).t,/신뢰 \+0/);});
test('normal exploration rewards unique floors and persists pet XP',()=>{const c=context();run(c,16,[15,15,16]);c.ugEnd(true);assert.equal(c.S.sv[0].xp,70);assert.equal(c.S.pets.dog.xp,6);assert.equal(c.saved.at(-1).pets.dog.xp,6);assert.equal(c.saved.at(-1).pets.dog.away,false);c.ugEnd(true);assert.equal(c.S.sv[0].xp,70);});
test('oil exhaustion keeps half material loss and earned exploration XP',()=>{const c=context();run(c,15,[15]);c.ugEnd(false);assert.equal(c.S.sv[0].xp,55);assert.match(c.messages[0].t,/wood.*4/);assert.match(c.messages[0].t,/장비를 떨어/);});
test('partial hits and revisiting a cell do not award another floor',()=>{const c=context();run(c,15,[]);c.UG.cells=[{hp:3,rev:false,c:'empty'}];c.ugTap(0);c.ugTap(0);assert.equal(c.ugRewardUnits(c.UG),0);c.ugTap(0);assert.equal(c.ugRewardUnits(c.UG),1);c.ugTap(0);assert.equal(c.ugRewardUnits(c.UG),1);});

// deploy hygiene: every versioned local asset the page loads must be precached under the same URL
test('service worker shell lists the same versioned script/style URLs as index.html',()=>{const sw=fs.readFileSync(path.join(__dirname,'../sw.js'),'utf8');
  const page=[...html.matchAll(/(?:src|href)="([a-z-]+\.(?:js|css)\?v=[^"]+)"/g)].map(m=>m[1]);assert.ok(page.length>=5,'page assets found');
  for(const u of page)assert.ok(sw.includes("'./"+u+"'"),'sw.js SHELL is missing '+u);
  for(const u of [...sw.matchAll(/'\.\/([a-z-]+\.(?:js|css)\?v=[^']+)'/g)].map(m=>m[1]))assert.ok(page.includes(u),'sw.js precaches stale URL '+u);});
