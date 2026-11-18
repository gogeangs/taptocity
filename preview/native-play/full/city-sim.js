/* Playable city progression. Mutations commit only after persistence succeeds. */
(function(root,factory){if(typeof module==='object'&&module.exports)module.exports=factory(require('./city-core.js'));else root.TTCCitySim=factory(root.TTCCity);})(typeof globalThis!=='undefined'?globalThis:this,function(C){
'use strict';
const goals=[
 {id:'home',title:'첫 보금자리',hint:'주거를 한 채 지으세요',test:s=>s.city.buildings.some(b=>b.type==='home'),reward:{wood:15,scrap:10}},
 {id:'farm',title:'먹거리를 가꾸는 마을',hint:'36칸을 개척하고 농장을 지으세요',test:s=>s.city.buildings.some(b=>b.type==='farm'),reward:{wood:25,scrap:20}},
 {id:'workshop',title:'스스로 자라는 도시',hint:'60칸을 개척하고 작업장을 지으세요',test:s=>s.city.buildings.some(b=>b.type==='workshop'),reward:{wood:35,scrap:35}},
 {id:'tower',title:'밤을 지키는 불빛',hint:'90칸을 개척하고 감시탑을 지으세요',test:s=>s.city.buildings.some(b=>b.type==='tower'),reward:{wood:45,scrap:40}},
 {id:'grow',title:'우리의 터전',hint:'주거를 3단계로 키우세요',test:s=>s.city.buildings.some(b=>b.type==='home'&&b.level===3),reward:{wood:50,scrap:50}},
 {id:'east',title:'다음 도시로',hint:'중심 거점의 동쪽 끝을 개척해 옆 구역에 닿으세요',test:s=>s.city.regions['1,0'].revealed.some(Boolean),reward:{wood:60,scrap:60}}
];
function ensure(s){C.ensure(s);if(!s.cityPlay)s.cityPlay={version:1,seconds:0,pop:0,claimed:[],ash:[],fraction:{},arrive:0};const p=s.cityPlay;if(p.version!==1||!Number.isFinite(p.seconds)||p.seconds<0||!Number.isInteger(p.pop)||p.pop<0||!Array.isArray(p.claimed)||!p.claimed.every(x=>goals.some(g=>g.id===x))||new Set(p.claimed).size!==p.claimed.length||!Array.isArray(p.ash)||p.ash.some(x=>!s.city.buildings.some(b=>b.id===x))||!p.fraction||!Number.isFinite(p.arrive))throw Error('도시 진행 기록을 확인할 수 없어요');return p;}
const cap=s=>150+50*(s.cityPlay?.claimed.length||0);
const night=s=>(s.cityPlay.seconds%240)>=180;
const goal=s=>goals.find(g=>!s.cityPlay.claimed.includes(g.id));
function income(s){const p=ensure(s),out={wood:0,scrap:0,food:0};for(const b of s.city.buildings){if(p.ash.includes(b.id))continue;if(b.type==='farm')out.food+=b.level*2;if(b.type==='workshop'){out.wood+=b.level;out.scrap+=b.level;}}return out;}
function protectedBuilding(s,b){return s.city.buildings.some(t=>t.type==='tower'&&t.region===b.region&&Math.max(Math.abs(t.x-b.x),Math.abs(t.y-b.y))<=4);}
function apply(s,a){const p=ensure(s),fail=message=>({ok:false,message});
 if(a.kind==='tick'){
  if(!Number.isFinite(a.dt)||a.dt<=0||a.dt>60)return fail('시간 범위 오류');
  const before=Math.floor((p.seconds+60)/240);p.seconds+=a.dt;
  if(Math.floor((p.seconds+60)/240)>before){p.ash=s.city.buildings.filter(b=>b.type!=='tower'&&!protectedBuilding(s,b)).slice(0,2).map(b=>b.id);}
  const prod=income(s);for(const k of ['wood','scrap','food']){p.fraction[k]=(p.fraction[k]||0)+prod[k]*a.dt/60;const n=Math.floor(p.fraction[k]);p.fraction[k]-=n;s.m[k]=(s.m[k]||0)+Math.min(n,Math.max(0,cap(s)-(s.m[k]||0)));}
  p.arrive+=a.dt;const beds=C.bonuses(s.city).beds;if(p.arrive>=30){p.arrive%=30;if(p.pop<beds)p.pop++;}
  return{ok:true,message:''};
 }
 if(a.kind==='claim'){const g=goal(s);if(!g||!g.test(s))return fail('목표를 먼저 완료해 주세요');p.claimed.push(g.id);for(const[k,v]of Object.entries(g.reward))s.m[k]=(s.m[k]||0)+Math.min(v,Math.max(0,cap(s)-(s.m[k]||0)));return{ok:true,message:g.title+' · 보상을 받았어요'};}
 if(a.kind==='clean'){if(!p.ash.includes(a.id))return fail('재가 덮이지 않은 건물이에요');p.ash=p.ash.filter(id=>id!==a.id);return{ok:true,message:'재를 걷어 생산을 다시 시작했어요'};}
 if(a.kind==='supply'){s.m.wood=s.m.scrap=cap(s);return{ok:true,message:'테스트용 목재·고철을 보충했어요'};}
 const r=C.act(s,a,{cap:cap(s),usedBeds:p.pop,baseBeds:0});if(r.ok&&a.kind==='demolish')p.ash=p.ash.filter(id=>id!==a.id);return r;
}
function run(s,a,persist){try{const draft=JSON.parse(JSON.stringify(s));const r=apply(draft,a);if(!r.ok)return r;if(!C.validate(draft.city))return{ok:false,message:'도시 검증에 실패했어요'};ensure(draft);draft.t=Date.now();persist(draft);s.city=draft.city;s.cityPlay=draft.cityPlay;s.m=draft.m;s.t=draft.t;return r;}catch(e){return{ok:false,message:'저장할 수 없어 변경을 취소했어요. '+e.message};}}
return{ensure,cap,night,goal,goals,income,run,protectedBuilding};
});
