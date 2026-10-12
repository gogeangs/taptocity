// 웹 버전에서 데이터 표와 비교 기준값을 뽑아 네이티브 코드로 옮긴다.
//   node native/tool/gen_data.cjs
// 결과: native/lib/data/web_data.g.dart (표), native/test/fixtures/web_core.json (테스트 기준값)
const fs = require('node:fs');
const path = require('node:path');
const load = require('./web_harness.cjs');

const web = load();
const ev = web.ev;
const out = path.join(__dirname, '..');

// ---------- 데이터 표 ----------
const T = {
  W: ev('W'), H: ev('H'), TW: ev('TW'), TH: ev('TH'),
  mats: ev('MATS.map(m=>({k:m.k,n:m.n,c:m.c,tier:m.tier||0,s2:m.s2,src:m.src}))'),
  sites: ev('Object.fromEntries(Object.entries(SITES).map(([k,s])=>[k,{n:s.n,drops:s.drops||null,c:s.c,hp:s.hp,regen:s.regen}]))'),
  landmarks: ev(`(()=>{const r=S&&S.region;return LMS.map(l=>({key:l.key,d:l.d,drops:l.drops,cost:l.cost,desc:l.desc}));})()`),
  landmarkText: ev(`(()=>{S={region:null};const o={home:LMS.map(l=>[l.name,l.ruin,l.done])};for(const r of Object.keys(LM_REG)){S={region:r};o[r]=LMS.map(l=>[l.name,l.ruin,l.done]);}S=undefined;return o;})()`),
  traceItem: ev('Object.assign({},TRACE_ITEM)'),
  shelter: ev('SHELTER'), slots: ev('SLOTS'), cap: ev('CAP'),
  shupBase: ev('SHUP_BASE.map((c,i)=>({cost:c,need:SHUP[i].need}))'),
  slotOff: ev('SLOT_OFF'),
  mods: ev('Object.fromEntries(Object.entries(MODS).map(([k,m])=>[k,{n:m.n,req:m.req,h:m.h,cost:m.cost,fx:[0,1,2].map(l=>m.fx(l))}]))'),
  modOrder: ev('MOD_ORDER'),
  walls: ev('WALLS'),
  // 작업대 단계(1~3)마다 재료가 달라지는 가공법은 단계별로 펼쳐 둔다
  recipes: ev(`RECIPES.map(r=>({out:r.out,n:r.n||1,lv:r.lv||0,wb:r.wb||0,nm:r.nm||null,d:r.d||null,inp:[1,2,3].map(l=>{S={mods:{0:{id:1,l:l-1}}};const v=r.inp();S=undefined;return v;})}))`),
  say: ev('SAY'),
  diary: ev('DIARY'),
  surv: ev(`SURV.map(s=>{
    // 특기 문구 틀: 효과 값을 표식 숫자로 넣어 돌린 뒤, 나온 숫자를 {키:방식} 자리표로 바꾼다
    const keys=Object.keys(s.eff||{});let tpl='';
    if(s.trait){const A={},B={};keys.forEach((k,i)=>{A[k]=(9100+i*7)/100;B[k]=9100+i*7;});
      let t1=s.trait(A),t2=s.trait(B);
      keys.forEach((k,i)=>{const n=9100+i*7;t1=t1.split(String(n)).join('{'+k+':pc}');});
      keys.forEach((k,i)=>{const n=9100+i*7;if(t1.includes('{'+k+':pc}'))return;if(t2.includes(String(n)+'.0')){const at=t2.indexOf(String(n)+'.0');const j=t1.indexOf(String((n/100).toFixed(1)));if(j>=0)t1=t1.slice(0,j)+'{'+k+':f1}'+t1.slice(j+String((n/100).toFixed(1)).length);}
        else if(t2.includes(String(n))){const j=t1.indexOf(String(Math.round(n/100)));if(j>=0)t1=t1.slice(0,j)+'{'+k+':r}'+t1.slice(j+String(Math.round(n/100)).length);}});
      tpl=t1;}
    return {id:s.id,name:s.name,age:s.age||0,job:s.job,src:s.src,d:s.d||0,region:s.region||null,hidden:!!s.hidden,alias:s.alias||null,hint:s.hint||null,
      hope:s.hope||0,need:s.need==null?null:s.need,look:s.look||null,match:s.match||[],eff:s.eff||{},grade:s.grade==null?0:s.grade,story:s.story||[],trait:tpl};})`),
  rescue: ev('Object.fromEntries(Object.entries(RESCUE).map(([k,r])=>[k,{need:r.need,why:r.why}]))'),
  bonds: ev('BONDS.map(b=>({ids:b.ids,name:b.name,txt:b.txt,eff:b.eff,d:b.d}))'),
  trust: ev('TRUST'),
  grades: ev('GR.map(g=>({n:g.n||null,m:g.m,cd:g.cd,w:g.w,c:g.c||null}))'),
  beds: ev('BEDS'),
  duty: ev('Object.fromEntries(Object.entries(DUTY).map(([k,d])=>[k,{n:d.n,v:d.v,ic:d.ic,d:d.d}]))'),
  skills: ev('SKILLS.map((k,id)=>({n:k.n,cd:k.cd,d:k.d,res:(()=>{const r=id>=RES0?RESIDENTS[id-RES0]:null,k=r&&r.skill;return k?{k:k.k||null,give:k.give||null,heal:!!k.heal,clear:k.clear||0,hope:!!k.hope,name:r.name}:null;})()}))'),
  skillCat: ev('SURV.map(s=>{const r=s.id>=RES0?RESIDENTS[s.id-RES0]:null;if(SKILL_CAT[s.id])return SKILL_CAT[s.id];const k=r&&r.skill&&r.skill.k;return k==="farm"?"food":k||"all";})'),
  gear: ev('Object.fromEntries(Object.entries(GEAR).map(([k,G])=>[k,{n:G.n,slot:G.slot,g:G.g,ic:G.ic||null,eff:G.eff,fit:G.fit||[],cost:G.cost||null,wb:G.wb||0,d:G.d||"",sig:!!G.sig,line:!!G.line,ug:!!G.ug}]))'),
  gearCell: ev(`(()=>{const o={};['lever','hammer','welder','binoc','axe','toolbox','shovel','wrench','light','saw','medkit','steth','hoe','ladle','tape2','rope2','meter','mic','rope3','loupe','mpick'].forEach((k,i)=>o[k]=['tools',i]);['coverall','mask','gloves','firesuit','coat','armor','boots','raincoat','helmet','apron','parka','drvglove','herbbag','wmask','mhelm'].forEach((k,i)=>o[k]=['wear',i]);['photo','coin','harmonica','seeds','watch','brooch','tape','bell','compass','notebook','ring','bag','umbrella','sketch','vane','ckey','feather','mlamp'].forEach((k,i)=>o[k]=['keep',i]);for(const k in LNI)o[k]=['line',LNI[k]];return o;})()`),
  gup: ev('GUP'),
  small: ev('Object.fromEntries(Object.entries(SMALL).map(([k,v])=>[k,v]))'),
  pairs: ev('PAIRS'),
  nightLine: ev('NIGHTLINE'),
  events: ev('EVENTS.map(e=>({who:e.who,t:e.t,x:e.x,dog:!!e.ok,a:{l:e.a.l,cost:e.a.cost||null,fx:e.a.fx,r:e.a.r},b:{l:e.b.l,cost:e.b.cost||null,fx:e.b.fx,r:e.b.r}}))'),
  wx: ev('WX'),
  role: ev('ROLE'),
};

const dartStr = s => "'" + String(s).replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$').replace(/\n/g, '\\n') + "'";
function dart(v) {
  if (v === null || v === undefined) return 'null';
  if (typeof v === 'string') return dartStr(v);
  if (typeof v === 'number') return Number.isInteger(v) ? String(v) : String(v);
  if (typeof v === 'boolean') return String(v);
  if (Array.isArray(v)) return '[' + v.map(dart).join(', ') + ']';
  return '{' + Object.entries(v).map(([k, x]) => dartStr(k) + ': ' + dart(x)).join(', ') + '}';
}
let src = '// 자동 생성 — native/tool/gen_data.cjs 가 웹 버전(index.html)에서 뽑은 값이에요. 직접 고치지 마세요.\n// ignore_for_file: type=lint\n\n';
for (const [k, v] of Object.entries(T)) src += `const ${k} = ${dart(v)};\n\n`;
fs.mkdirSync(path.join(out, 'lib/data'), { recursive: true });
fs.writeFileSync(path.join(out, 'lib/data/web_data.g.dart'), src);

// ---------- 테스트 기준값 ----------
// 같은 시드로 웹이 만든 지도와 각종 계산 결과. Dart 쪽 테스트가 똑같이 나오는지 확인한다.
const maps = [];
for (const seed of [1, 42, 284711989, 777777777, 123456789]) {
  const m = ev(`(()=>{const {ter,diaryAt}=genMap(${seed});S={seed:${seed},ter,diaryAt,rev:new Array(N).fill(0),hp:new Array(N).fill(-1),m:{},found:[],sv:{},site:{},camp:{},gen:0};
    for(let y=CY-2;y<=CY+2;y++)for(let x=CX-2;x<=CX+2;x++){const i=y*W+x;if(S.ter[i]===T.WATER||isSlot(i))S.ter[i]=T.ASH;}
    for(let y=CY-1;y<=CY+1;y++)for(let x=CX-1;x<=CX+1;x++)S.rev[y*W+x]=1;
    [[3,0,T.RUIN],[-1,-3,T.CAR],[-3,2,T.RUIN],[2,3,T.CRATE]].forEach(([dx,dy,t])=>{const i=(CY+dy)*W+CX+dx;S.ter[i]=t;});
    const missing=[0,1,2,3,4,5,6].filter(k=>!Object.values(S.diaryAt).includes(k)).length;
    placeSignals();sprinkle();
    const r={seed:${seed},missingDiaries:missing,genTer:genMap(${seed}).ter,ter:S.ter.slice(),diaryAt:S.diaryAt,sig:S.sig,trace:S.trace,lm:S.lm,
      maxHp:[0,21,57,820,C0+5,C0-W*7,1599].map(i=>maxHp(i))};
    S=undefined;return r;})()`);
  maps.push(m);
}
const rng = ev('(()=>{const r=mulberry(12345),a=[];for(let i=0;i<20;i++)a.push(r());const n=noise(mulberry(9),6),b=[];for(const [x,y] of [[0,0],[3,7],[17,22],[39,39],[25.5,1]])b.push(n(x,y));return {mulberry:a,noise:b};})()');
// 계산 공식: 상태 몇 가지를 놓고 웹이 낸 값
const calc = ev(`(()=>{const res=[];
  const base=()=>({seed:1,ter:new Array(N).fill(0),rev:new Array(N).fill(1),hp:new Array(N).fill(0),diaryAt:{},m:{wood:500,scrap:500,cloth:300,parts:200,fuel:100,food:300,plate:80,rope:40,wire:10,med:5,batt:2},got:{},frac:{},
    lv:1,mods:{},walls:0,site:{},tapLv:0,splashLv:0,droneLv:0,found:[],sv:{},asg:{},ash:{},camp:{},inv:[],lm:{},sig:{},trace:{},gen:0,hopeB:0});
  const cases=[
    {name:'start'},
    {name:'lv2', lv:2, mods:{0:{id:1,l:0},1:{id:2,l:1},2:{id:9,l:0}}},
    {name:'lv3', lv:3, tapLv:4, splashLv:2, droneLv:1, mods:{0:{id:1,l:1},1:{id:2,l:2},2:{id:9,l:2},3:{id:3,l:1},4:{id:4,l:0},5:{id:8,l:1},6:{id:5,l:0}}},
    {name:'lv4gen1', lv:4, gen:1, tapLv:9, mods:{0:{id:1,l:2},1:{id:2,l:2},2:{id:9,l:1},3:{id:9,l:0},4:{id:4,l:2},5:{id:8,l:2},6:{id:5,l:2},7:{id:6,l:1},8:{id:7,l:0}}, half:true},
    {name:'survivors', lv:3, tapLv:3, mods:{0:{id:1,l:1},1:{id:2,l:2},2:{id:9,l:1},3:{id:3,l:0},4:{id:4,l:1},5:{id:6,l:1}}, sv:{0:{xp:200,at:-1},1:{xp:45,at:-1},3:{xp:900,at:-1,g:1,st:3},4:{xp:10,at:-1},5:{xp:400,at:-1,st:5},6:{xp:0,at:-1}}, asgAt:{0:0,1:4,2:1,3:5,4:6}},
    {name:'lv5', lv:5, tapLv:15, splashLv:5, droneLv:8, mods:{0:{id:1,l:2},1:{id:2,l:2},2:{id:2,l:1},3:{id:9,l:2},4:{id:4,l:2},5:{id:8,l:2},6:{id:5,l:1},7:{id:6,l:2},8:{id:7,l:2},9:{id:3,l:2}}},
  ];
  for(const c of cases){S=Object.assign(base(),c);delete S.name;
    if(c.asgAt){delete S.asgAt;for(const [k,id] of Object.entries(c.asgAt)){const t=slotTile(+k);S.asg[t]=id;S.sv[id].at=t;}}
    recalc();
    const sites={};for(const k of ['house','car','store','bunker','rubble']){sites[k]=[0,5,12.5].map(d=>siteHp({k,d}));}
    res.push({name:c.name,state:{lv:S.lv,gen:S.gen,tapLv:S.tapLv,splashLv:S.splashLv,droneLv:S.droneLv,mods:S.mods,half:!!S.half},
      sv:S.sv,asg:S.asg,E:D.E,trait:Object.keys(S.sv).map(id=>[+id,SURV[id].trait(effOf(+id))]),asgMult:Object.keys(S.asg).map(t=>[+t,asgMult(+t)]),
      prod:D.prod,cap:D.cap,hope:D.hope,eat:D.eat,fuelUse:D.fuelUse,tapAdd:D.tapAdd,tapPow:tapPow(),droneDmg:droneDmg(),
      siteHp:sites,
      modBuild:Object.fromEntries(MOD_ORDER.map(id=>[id,modBuildCost(id)])),
      modUp:Object.fromEntries(MOD_ORDER.map(id=>[id,[1,2].map(l=>modCost(id,l))])),
      shup:S.lv<5?scaleCost(SHUP[S.lv-1].cost,costMult()):null,
      walls:WALLS.map(w=>scaleCost(w.cost,costMult())),
      upg:Object.fromEntries(['tap','splash','drone'].map(k=>[k,UPG[k].cost()])),
      upgWb:Object.fromEntries(['tap','splash','drone'].map(k=>[k,UPG[k].wb()])),
      capOf:Object.fromEntries(MATS.map(m=>[m.k,capOf(m.k)]))});}
  S=undefined;return res;})()`);
fs.mkdirSync(path.join(out, 'test/fixtures'), { recursive: true });
fs.writeFileSync(path.join(out, 'test/fixtures/web_core.json'), JSON.stringify({ rng, maps, calc }));
console.log('ok', Object.keys(T).length, 'tables,', maps.length, 'maps,', calc.length, 'calc cases');
process.exit(0);
