/* Persistent city rules. No DOM, timers or storage; shared by browser and Node tests. */
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.TTCCity=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
'use strict';
const SIZE=25, COUNT=SIZE*SIZE, VERSION=1;
// Phase-one tuning, not final economy values. Unlocks never regress after demolition.
const TYPES=Object.freeze({
 home:{name:'주거',w:2,h:2,unlock:0,cost:{wood:20,scrap:10},effect:'침상 +2 / 단계'},
 farm:{name:'농장',w:2,h:2,unlock:36,cost:{wood:15,scrap:5},effect:'식량 +2 / 분 / 단계'},
 workshop:{name:'작업장',w:2,h:2,unlock:60,cost:{wood:10,scrap:20},effect:'목재·고철 +1 / 분 / 단계'},
 tower:{name:'감시탑',w:1,h:2,unlock:90,cost:{wood:15,scrap:15},effect:'주변 4칸 개척 타격량 +1 / 단계'}
});
const has=(o,k)=>Object.prototype.hasOwnProperty.call(o,k);
const integer=(n,min,max)=>Number.isInteger(n)&&n>=min&&n<=max;
const point=(x,y)=>integer(x,0,24)&&integer(y,0,24);
const index=(x,y)=>y*SIZE+x;
const clone=o=>JSON.parse(JSON.stringify(o));
function terrain(seed,region,i){const x=i%SIZE,y=Math.floor(i/SIZE);if(y===12||x===12||Math.max(Math.abs(x-12),Math.abs(y-12))<=3)return 0;let n=(seed^Math.imul(i+1,374761393)^Math.imul(region+1,668265263))>>>0;n=Math.imul(n^(n>>>13),1274126177)>>>0;return n%23===0?1:0;}
function create(seed){seed=(seed||0)>>>0;const regions={};for(let r=0;r<2;r++){const id=r?'1,0':'0,0';regions[id]={x:r,y:0,terrain:Array.from({length:COUNT},(_,i)=>terrain(seed,r,i)),revealed:Array(COUNT).fill(0),hp:Array(COUNT).fill(0)};}const c={version:VERSION,seed,active:'0,0',regions,buildings:[],nextId:1,opened:25};for(let y=10;y<=14;y++)for(let x=10;x<=14;x++)c.regions['0,0'].revealed[index(x,y)]=1;return c;}
function cells(b){const t=TYPES[b.type];if(!t)return[];const w=b.rot?t.h:t.w,h=b.rot?t.w:t.h;const out=[];for(let y=b.y;y<b.y+h;y++)for(let x=b.x;x<b.x+w;x++)out.push([x,y]);return out;}
function at(c,region,x,y,except){return c.buildings.find(b=>b.id!==except&&b.region===region&&cells(b).some(p=>p[0]===x&&p[1]===y));}
function placement(c,b,except){if(!has(TYPES,b.type)||!has(c.regions,b.region)||![0,1].includes(b.rot))return'건물이나 구역을 확인해 주세요';const r=c.regions[b.region];for(const [x,y]of cells(b)){if(!point(x,y))return'지도 밖에는 지을 수 없어요';if(b.region==='0,0'&&x===12&&y===12)return'중심 등불 자리는 비워 두세요';const i=index(x,y);if(!r.revealed[i])return'먼저 모든 바닥 칸을 개척해 주세요';if(r.terrain[i]===1)return'물 위에는 지을 수 없어요';if(at(c,b.region,x,y,except))return'다른 건물과 겹쳐요';}return'';}
function validate(c){try{if(!c||c.version!==VERSION||!integer(c.seed,0,4294967295)||!integer(c.nextId,1,1000000)||!integer(c.opened,25,1250)||!has(c.regions,c.active)||Object.keys(c.regions).length!==2||!Array.isArray(c.buildings)||c.buildings.length>1250)return false;let n=0;for(const [id,x]of [['0,0',0],['1,0',1]]){const r=c.regions[id];if(!r||r.x!==x||r.y!==0)return false;for(const k of ['terrain','revealed','hp'])if(!Array.isArray(r[k])||r[k].length!==COUNT)return false;for(let i=0;i<COUNT;i++){if(![0,1].includes(r.terrain[i])||![0,1].includes(r.revealed[i])||!integer(r.hp[i],0,6)||r.revealed[i]&&r.hp[i]!==0)return false;n+=r.revealed[i];}}if(n!==c.opened||!c.regions['0,0'].revealed[index(12,12)])return false;const ids=new Set();for(const b of c.buildings){if(!integer(b.id,1,c.nextId-1)||ids.has(b.id)||!integer(b.level,1,3)||!point(b.x,b.y)||!has(TYPES,b.type)||c.opened<TYPES[b.type].unlock||placement(c,b,b.id))return false;ids.add(b.id);}return true;}catch(_){return false;}}
function ensure(s){if(s.city==null)s.city=create(s.seed);if(!validate(s.city))throw Error('도시 저장 데이터가 올바르지 않아요');return s.city;}
function neighbor(c,region,x,y){let r=c.regions[region],gx=r.x*SIZE+x,gy=r.y*SIZE+y;return Object.values(c.regions).some(q=>{const xx=gx-q.x*SIZE,yy=gy-q.y*SIZE;return point(xx,yy)&&q.revealed[index(xx,yy)]===1;});}
function frontier(c,region,x,y){return [[-1,0],[1,0],[0,-1],[0,1]].some(([dx,dy])=>neighbor(c,region,x+dx,y+dy));}
function risk(region,x,y){return region==='1,0'?2:Math.max(Math.abs(x-12),Math.abs(y-12))>8?2:Math.max(Math.abs(x-12),Math.abs(y-12))>4?1:0;}
function bonuses(c){const out={beds:0,food:0,wood:0,scrap:0};if(!c)return out;for(const b of c.buildings){if(b.type==='home')out.beds+=2*b.level;if(b.type==='farm')out.food+=2*b.level;if(b.type==='workshop'){out.wood+=b.level;out.scrap+=b.level;}}return out;}
function cost(type,level=1){const t=TYPES[type];return Object.fromEntries(Object.entries(t.cost).map(([k,v])=>[k,v*level]));}
function pay(m,costs){if(Object.entries(costs).some(([k,v])=>!Number.isFinite(m[k]||0)||(m[k]||0)<v))return false;for(const [k,v]of Object.entries(costs))m[k]-=v;return true;}
// Mutate a draft only; the caller commits it together with resources after successful persistence.
function act(s,a,context={}){const c=ensure(s),r=c.regions[a.region];const fail=message=>({ok:false,message});
 if(a.kind==='region'){if(!r)return fail('아직 연결되지 않은 구역이에요');if(!r.revealed.some(Boolean))return fail('동쪽 경계에서 한 칸을 개척하면 연결돼요');c.active=a.region;return{ok:true,message:'구역을 이동했어요'};}
 if(a.kind==='explore'){if(!r||!point(a.x,a.y))return fail('지도 안의 칸을 골라 주세요');const i=index(a.x,a.y);if(r.revealed[i])return fail('이미 개척한 땅이에요');if(!frontier(c,a.region,a.x,a.y))return fail('밝혀진 땅에 붙은 칸부터 개척해 주세요');const danger=risk(a.region,a.x,a.y),max=2+danger*2;const guard=c.buildings.filter(b=>b.type==='tower'&&b.region===a.region&&Math.max(Math.abs(b.x-a.x),Math.abs(b.y-a.y))<=4).reduce((n,b)=>Math.max(n,b.level),0);r.hp[i]=(r.hp[i]||max)-(1+guard);if(r.hp[i]>0)return{ok:true,message:`재를 걷는 중 · ${r.hp[i]}번 더 두드려요`};r.hp[i]=0;r.revealed[i]=1;c.opened++;const rewards=r.terrain[i]?{}:{wood:2,scrap:1};for(const[k,v]of Object.entries(rewards))s.m[k]=(s.m[k]||0)+Math.min(v,Math.max(0,(context.cap??Number.MAX_SAFE_INTEGER)-(s.m[k]||0)));return{ok:true,message:r.terrain[i]?'물길을 발견했어요':'땅을 개척했어요 · 목재 +2 · 고철 +1'};}
 if(a.kind==='build'){if(!has(TYPES,a.type))return fail('건물을 골라 주세요');const t=TYPES[a.type];if(c.opened<t.unlock)return fail(`${t.unlock}칸 개척 후 열려요`);const b={id:c.nextId,type:a.type,region:a.region,x:a.x,y:a.y,rot:a.rot||0,level:1};if(!point(b.x,b.y))return fail('지도 안의 칸을 골라 주세요');const why=placement(c,b);if(why)return fail(why);if(!pay(s.m,cost(a.type)))return fail('목재 또는 고철이 부족해요');c.nextId++;c.buildings.push(b);return{ok:true,message:`${t.name} 건설 완료`};}
 const b=c.buildings.find(b=>b.id===a.id);if(!b)return fail('건물을 먼저 선택해 주세요');
 if(a.kind==='move'){const next={...b,region:a.region,x:a.x,y:a.y,rot:a.rot??b.rot};if(!point(next.x,next.y))return fail('지도 안의 칸을 골라 주세요');const why=placement(c,next,b.id);if(why)return fail(why);Object.assign(b,next);return{ok:true,message:'건물을 옮겼어요'};}
 if(a.kind==='upgrade'){if(b.level>=3)return fail('최대 3단계예요');if(!pay(s.m,cost(b.type,b.level+1)))return fail('목재 또는 고철이 부족해요');b.level++;return{ok:true,message:'건물이 한 단계 성장했어요'};}
 if(a.kind==='demolish'){if(!a.confirm)return fail('철거를 한 번 더 확인해 주세요');if(b.type==='home'&&(context.usedBeds||0)>(context.baseBeds||0)+bonuses(c).beds-2*b.level)return fail('살고 있는 생존자의 침상이 부족해져요');c.buildings=c.buildings.filter(q=>q.id!==b.id);return{ok:true,message:'철거했어요 · 자재는 반환되지 않아요'};}
 return fail('지원하지 않는 작업이에요');
}
function transact(s,a,persist,context){const draft={...s,m:{...s.m},city:s.city?clone(s.city):create(s.seed)};const result=act(draft,a,context);if(!result.ok)return result;if(!validate(draft.city))return{ok:false,message:'도시 데이터 확인에 실패했어요'};try{persist(draft);}catch(_){return{ok:false,message:'저장 공간이 부족하거나 저장할 수 없어요. 변경을 취소했어요.'};}s.city=draft.city;s.m=draft.m;return result;}
return{SIZE,COUNT,VERSION,TYPES,create,validate,ensure,cells,at,placement,frontier,risk,bonuses,cost,act,transact};
});
