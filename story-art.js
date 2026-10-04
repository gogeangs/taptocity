// Story illustrations for the main scenario: every chapter intro/outro, the tutorial and the ending
// show one panel from three 3x3 atlases (assets/illustrated/story-1..3.webp).
// The scene is picked from the talk's lines, so no story call site has to change.
// Until an atlas has loaded (or if it is missing), talks render exactly as before.
(function(){
// Turn on once story-1..3.webp are in assets/illustrated (until then no requests are made, so no 404s).
const ENABLED=true;
const base='assets/illustrated/',files=['story-1.webp','story-2.webp','story-3.webp'],img={};
let pending=null;
if(ENABLED)for(const f of files){const i=new Image();i.decoding='async';i.onload=()=>{const p=pending;if(p&&document.querySelector('#modal .page.talk')===p.page)after(p.talk,p.STEPS,p.TUT);};img[f]=i;i.src=base+f+'?v=1';}
const ok=f=>{const i=img[f];return!!(i&&i.complete&&i.naturalWidth>0);};
// panel numbers: 0-8 in story-1, 9-17 in story-2, 18-26 in story-3 (reading order, 3 columns)
const CAP=['그날 밤 03:02, 정전된 거리','무너진 집','03:11, 텐트 안의 라디오','03:14, 발전소의 섬광','재가 내린 지 마흔세 날','랜턴 빛에 녹는 재','구름 속의 손전등 신호','붉게 물든 하늘','새벽의 잡음',
 '랜턴 피버','셋이 된 식탁','컨테이너 쉘터','창고 구석의 라디오','은호가 찾아오다','다시 불이 켜진 건물','맨홀 아래로','젖은 작업 일지','가장 먼 불빛',
 '재혁의 고백','망루에서 본 굴뚝','대형 재폭풍','수첩의 마지막 장','무전실의 방송','답하는 불빛','미영이 오다','랜턴의 일련번호','등불 탑 점화'];
// step index → [intro panel, outro panel]
const STEPART=[[4,5],[1,1],[4,4],[4,4],[6,6],[6,6],[6,6],[7,7],[7,7],[7,8],[7,7],[9,9],[10,10],[10,10],[10,10],[10,10],[11,11],[12,12],[12,13],[13,13],
 [14,14],[14,14],[15,15],[15,15],[15,16],[17,17],[18,18],[19,19],[20,20],[20,20],[22,22],[23,23],[23,24],[23,23],[23,23],[23,23],[25,25],[26,26]];
const LINE={},TALK={};let doneS=0,doneT=0;
function index(STEPS,TUT){
  if(STEPS&&!doneS){doneS=1;STEPS.forEach((s,i)=>{const a=STEPART[i];if(!a)return;for(const l of s.intro||[])TALK[l[1]]=TALK[l[1]]??a[0];for(const l of s.outro||[])TALK[l[1]]=TALK[l[1]]??a[1];});}
  if(TUT&&!doneT){doneT=1;TUT.forEach((T,i)=>{for(const l of T.say||[])TALK[l[1]]=[0,1,2,3][i];});}
  Object.assign(TALK,{'라디오에서는 심야 방송이 흐르고 있었다. 누군가 신청한 옛 노래.':2,'재는 밤새 그치지 않았다.':3,'그날 밤에도 심야 방송이 흘렀다.':22});
  // single lines that deserve their own picture inside a longer talk
  Object.assign(LINE,{'03:11. 노래가 뚝 끊겼다.':2,'번쩍. 발전소 쪽 하늘이 하얗게 타올랐다.':3,
    '잠들기 전 사건 수첩을 펼쳤다. 마지막 장에 내 글씨로 적혀 있었다. “다음은 탑.”':21,'언제 썼는지, 기억나지 않는다.':21});
}
function panelSvg(n){const f=files[Math.floor(n/9)];if(!ok(f))return'';const i=img[f],c=n%9,w=i.naturalWidth/3,h=i.naturalHeight/3,x=(c%3)*w,y=Math.floor(c/3)*h,e=2;
  return`<div class="story-art"><svg viewBox="${x+e} ${y+e} ${w-2*e} ${h-2*e}" preserveAspectRatio="xMidYMid slice" role="img" aria-label="${CAP[n]}"><image href="${base}${f}?v=1" width="${i.naturalWidth}" height="${i.naturalHeight}"/></svg></div>`;}
function artFor(talk){if(!talk||!talk.lines)return null;const t=talk.lines[talk.k]&&talk.lines[talk.k][1];if(t!=null&&LINE[t]!=null)return LINE[t];
  if(talk.art==null){talk.art=-1;for(const l of talk.lines){if(TALK[l[1]]!=null){talk.art=TALK[l[1]];break;}}}return talk.art>=0?talk.art:null;}
// called by the game's renderTalk right after the talk page is on screen
function after(talk,STEPS,TUT){try{pending=null;if(!doneS||(TUT&&!doneT))index(STEPS,TUT);const n=artFor(talk);if(n==null)return;
  const pg=document.querySelector('#modal .page.talk');if(!pg||pg.querySelector('.story-art'))return;const art=panelSvg(n);if(!art){pending={talk,STEPS,TUT,page:pg};return;}const old=pg.querySelector('.story-scene');if(old)old.remove();pg.classList.add('has-story-art');pg.insertAdjacentHTML('afterbegin',art);}catch(e){}}
window.TTCStory={after,panelSvg,CAP,STEPART};
})();
