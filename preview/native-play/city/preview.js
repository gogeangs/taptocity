(function(){'use strict';
const KEY='taptocity-city-preview-v1',C=window.TTCCity,$=id=>document.getElementById(id);
const fresh=()=>({seed:20261117,m:{wood:500,scrap:500,food:20},city:C.create(20261117)});
let state,broken=false;
try{const raw=localStorage.getItem(KEY);state=raw?JSON.parse(raw):fresh();if(!state.m||!Object.values(state.m).every(v=>Number.isFinite(v)&&v>=0)||!C.validate(state.city))throw Error('invalid');}catch(e){state=fresh();broken=true;}
function notify(message){$('status').textContent=message;}
function summary(){$('opened').textContent=state.city.opened+'칸';$('buildings').textContent=state.city.buildings.length+'채';}
function persist(next){localStorage.setItem(KEY,JSON.stringify(next));}
const view=window.TTCCityView({state:()=>state,notify,closed:summary,act:a=>{const result=C.transact(state,a,persist,{cap:10000,baseBeds:0,usedBeds:0});if(result.ok)summary();return result;}});
$('play').onclick=()=>{if(broken){notify('저장 데이터를 읽지 못했습니다. 새로 시작 버튼으로 초기화한 뒤 열어 주세요.');return;}view.open();};
$('supply').onclick=()=>{if(broken){notify('저장 데이터를 먼저 확인해 주세요.');return;}const next={...state,m:{...state.m,wood:500,scrap:500}};try{persist(next);state=next;notify('테스트 자재를 목재·고철 각 500개로 채웠습니다.');}catch(e){notify('저장하지 못했습니다. 기존 자재를 유지합니다.');}};
$('reset').onclick=()=>{if(!window.confirm('이 테스트 도시의 개척과 건물을 지우고 새로 시작할까요? 기존 본편 저장에는 영향이 없습니다.'))return;const next=fresh();try{persist(next);state=next;broken=false;summary();notify('새 테스트 도시를 준비했습니다.');}catch(e){notify('저장하지 못해 초기화를 취소했습니다.');}};
summary();if(broken)notify('이 브라우저의 테스트 저장 데이터를 읽지 못했습니다.');else notify('준비되었습니다. 도시 지도 열기를 눌러 주세요.');
})();
