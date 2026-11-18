/* One map for clearing ash, free construction and a growing settlement. */
(function(){'use strict';
window.TTCCityWorld=function(B){
 const C=TTCCity,M=TTCCitySim,cv=B.canvas,stage=B.stage,g=cv.getContext('2d'),s=()=>B.state(),c=()=>s().city,p=()=>s().cityPlay;
 M.ensure(s());let region=c().active,mode='explore',type='home',rot=0,selected=null,target=null,remove=false,zoom=1.25,ox=0,oy=0,w=0,h=0,tick=0,paint=0,lastUI='',paused=false,notice='재를 두드려 땅을 밝히고, 같은 땅에 건물을 지어 보세요.',flash=null;
 document.body.classList.add('cityWorld');
 const ui=document.createElement('section');ui.id='worldUI';ui.setAttribute('aria-label','도시 개척과 건설');ui.innerHTML=`
 <div class="worldTop"><div class="worldTitle"><b id="worldName"></b><span id="worldWeather"></span></div><div id="worldStats"></div><div class="worldGoal"><div><b id="worldGoalTitle"></b><small id="worldGoalHint"></small></div><button id="worldClaim">보상 받기</button></div></div>
 <div class="worldCamera"><button id="worldOut" aria-label="지도 축소">−</button><button id="worldIn" aria-label="지도 확대">＋</button><button id="worldCenter">중심</button><button id="worldRegion">동쪽 →</button></div>
 <div class="worldBottom"><div id="worldNotice" role="status"></div><div id="worldSelection"></div><div id="worldCatalog" hidden></div><div id="worldActions"></div><nav><button id="worldExplore">개척</button><button id="worldBuild">건설</button><button id="worldInspect">살펴보기</button><button id="worldHelp">도움말</button></nav></div>
 <dialog id="worldHelpDialog"><h2>재 속에서, 우리의 도시로</h2><p>① 밝은 땅 가장자리의 재를 두드리세요. 개척한 땅은 영구적으로 남고 자재를 얻습니다.</p><p>② 건설에서 건물을 골라 같은 지도에 배치하세요. 초록색이면 확정할 수 있습니다. 끌어서 지도를 옮기고 ＋/−로 확대하세요.</p><p>③ 집을 지으면 주민이 찾아옵니다. 농장과 작업장은 자원을 생산하고, 강화하면 모습도 달라집니다.</p><p>④ 3분마다 밤이 찾아옵니다. 재에 덮인 건물을 눌러 청소하세요. 감시탑은 주변 건물을 보호합니다. 개척한 땅과 건물은 사라지지 않습니다.</p><p>⑤ 목표 6개를 따라 주거 3단계와 동쪽 구역까지 도달하면 1차 테스트를 끝까지 체험한 것입니다.</p><small>이 테스트는 본편 기록과 별도로 저장됩니다. 주민은 이 도시의 인구이며 본편 이야기 인물의 영입과는 별개입니다. 방향키·Enter로도 지도를 조작할 수 있습니다.</small><button id="worldHelpClose">도시로 돌아가기</button></dialog>`;
 stage.appendChild(ui);const el=id=>ui.querySelector('#'+id);
 const persist=d=>B.persist(d);
 function act(a){const r=M.run(s(),a,persist);if(a.kind!=='tick'||!r.ok){notice=r.message;flash={x:target?.x??12,y:target?.y??12,t:performance.now(),ok:r.ok};}if(r.ok){B.changed();lastUI='';}else if(a.kind==='tick')paused=true;renderUI();return r;}
 function resetMode(m){mode=m;target=null;selected=null;remove=false;notice=m==='explore'?'밝은 땅과 맞닿은 재를 두드려 주세요.':m==='catalog'?'지을 건물을 골라 주세요.':'건물을 누르면 강화·이동·철거할 수 있어요.';renderUI();}
 function center(){ox=0;oy=0;target=null;renderUI();}
 el('worldExplore').onclick=()=>resetMode('explore');el('worldBuild').onclick=()=>resetMode('catalog');el('worldInspect').onclick=()=>resetMode('inspect');
 el('worldCenter').onclick=center;el('worldOut').onclick=()=>zoom=Math.max(.55,zoom/1.2);el('worldIn').onclick=()=>zoom=Math.min(2.5,zoom*1.2);
 el('worldRegion').onclick=()=>{region=region==='0,0'?'1,0':'0,0';if(c().regions[region].revealed.some(Boolean))act({kind:'region',region});resetMode('explore');center();};
 el('worldClaim').onclick=()=>act({kind:'claim'});
 el('worldHelp').onclick=()=>el('worldHelpDialog').showModal();el('worldHelpClose').onclick=()=>el('worldHelpDialog').close();
 el('worldCatalog').onclick=e=>{const b=e.target.closest('[data-type]');if(!b||b.disabled)return;type=b.dataset.type;mode='build';rot=0;target=null;selected=null;notice='지을 위치를 누른 뒤 건설 확정을 눌러 주세요.';renderUI();};
 el('worldActions').onclick=e=>{const b=e.target.closest('[data-action]');if(!b)return;const a=b.dataset.action,q=c().buildings.find(x=>x.id===selected);
  if(a==='cancel')resetMode('inspect');
  if(a==='rotate'){rot=1-rot;renderUI();}
  if(a==='confirm'&&target){const r=act({kind:mode,region,...target,rot,type,id:selected});if(r.ok){selected=C.at(c(),region,target.x,target.y)?.id;mode='inspect';renderUI();}}
  if(a==='move'&&q){mode='move';type=q.type;rot=q.rot;target={x:q.x,y:q.y};renderUI();}
  if(a==='upgrade')act({kind:'upgrade',id:selected});
  if(a==='clean')act({kind:'clean',id:selected});
  if(a==='demolish'){if(!remove){remove=true;notice='철거하면 자재는 돌아오지 않아요. 한 번 더 눌러 확정하세요.';renderUI();}else if(act({kind:'demolish',id:selected,confirm:true}).ok){selected=null;remove=false;renderUI();}}
 };
 function pick(x,y){if(x<0||y<0||x>=25||y>=25)return;target={x,y};remove=false;const b=C.at(c(),region,x,y);
  if(mode==='explore'){if(b){mode='inspect';selected=b.id;}else if(!c().regions[region].revealed[y*25+x]){act({kind:'explore',region,x,y});}else notice=x===12&&y===12&&region==='0,0'?'중심 등불 · 이곳에서 도시가 시작됐어요':'개척한 땅이에요. 건설 메뉴에서 건물을 골라 보세요.';}
  else if(mode==='inspect'||mode==='catalog'){selected=b?.id||null;mode='inspect';}
  renderUI();
 }
 function xy(x,y){return[(x-y)*32,(x+y)*16];}
 function camera(){const mid=region==='1,0'&&!c().regions[region].revealed.some(Boolean)?xy(.5,12.5):xy(12.5,12.5);return[w/2-mid[0]*zoom+ox,h*.43-mid[1]*zoom+oy];}
 function screenPick(px,py){const [cx,cy]=camera(),a=(px-cx)/zoom/32,b=(py-cy)/zoom/16;pick(Math.floor((a+b)/2),Math.floor((b-a)/2));}
 const pts=new Map();let down=null,pinch=0,oldZoom=zoom,multi=false;
 for(const ev of ['pointerdown','pointermove','pointerup','pointercancel','wheel'])cv.addEventListener(ev,e=>{
  e.stopImmediatePropagation();e.preventDefault();const r=cv.getBoundingClientRect(),x=e.clientX-r.left,y=e.clientY-r.top;
  if(ev==='wheel'){zoom=Math.min(2.5,Math.max(.55,zoom*Math.exp(-e.deltaY*.001)));return;}
  if(ev==='pointerdown'){cv.focus();cv.setPointerCapture(e.pointerId);pts.set(e.pointerId,{x,y});if(pts.size===1){down={x,y,ox,oy};multi=false;}else{multi=true;const a=[...pts.values()];pinch=Math.hypot(a[0].x-a[1].x,a[0].y-a[1].y);oldZoom=zoom;}return;}
  if(ev==='pointermove'&&pts.has(e.pointerId)){pts.set(e.pointerId,{x,y});if(pts.size>1){const a=[...pts.values()];if(pinch>0)zoom=Math.min(2.5,Math.max(.55,oldZoom*Math.hypot(a[0].x-a[1].x,a[0].y-a[1].y)/pinch));}else if(down&&!multi){ox=down.ox+x-down.x;oy=down.oy+y-down.y;}return;}
  if(ev==='pointerup'&&down&&!multi&&Math.hypot(x-down.x,y-down.y)<8)screenPick(x,y);
  if(ev==='pointerup'||ev==='pointercancel'){pts.delete(e.pointerId);if(!pts.size){down=null;multi=false;}}
 },{capture:true,passive:false});
 cv.tabIndex=0;cv.setAttribute('aria-label','영구 도시 지도. 방향키로 칸 선택, Enter로 개척 또는 배치.');
 cv.addEventListener('keydown',e=>{const dirs={ArrowLeft:[-1,0],ArrowRight:[1,0],ArrowUp:[0,-1],ArrowDown:[0,1]};if(dirs[e.key]){e.preventDefault();e.stopImmediatePropagation();const d=dirs[e.key],a=target||{x:12,y:12};target={x:Math.max(0,Math.min(24,a.x+d[0])),y:Math.max(0,Math.min(24,a.y+d[1]))};const [tx,ty]=xy(target.x+.5,target.y+.5),[cx,cy]=camera();ox+=w/2-(tx*zoom+cx);oy+=h*.43-(ty*zoom+cy);renderUI();}else if(e.key==='Enter'){e.preventDefault();const a=target||{x:12,y:12};pick(a.x,a.y);}},true);
 function renderUI(){const q=c().buildings.find(x=>x.id===selected),goal=M.goal(s()),prod=M.income(s()),beds=C.bonuses(c()).beds;
  cv.setAttribute('aria-label','영구 도시 지도. 방향키로 칸 선택, Enter로 개척 또는 배치.');
  el('worldName').textContent=(region==='0,0'?'중심 거점':'동쪽 구역')+' · '+(c().buildings.length>=6?'작은 도시':c().buildings.length>=3?'살아나는 마을':c().buildings.length?'첫 정착지':'재 속의 등불');
  el('worldWeather').textContent=M.night(s())?'밤 · '+Math.ceil(240-p().seconds%240)+'초 뒤 새날':'낮 · '+Math.ceil(180-p().seconds%240)+'초 뒤 밤';
  el('worldStats').textContent=`개척 ${c().opened}/1,250 · 주민 ${p().pop}/${beds} · 식량 +${prod.food}/분 · 자재 +${prod.wood}/분`;
  el('worldGoalTitle').textContent=goal?`${p().claimed.length+1}/6 · ${goal.title}`:'1차 테스트 목표 달성';el('worldGoalHint').textContent=goal?goal.hint:'두 구역을 계속 넓히며 나만의 도시를 만들어 보세요.';
  el('worldClaim').hidden=!goal;el('worldClaim').disabled=!goal||!goal.test(s());el('worldRegion').textContent=region==='0,0'?'동쪽 →':'← 거점';
  el('worldNotice').textContent=notice;
  const placing=mode==='build'||mode==='move',ghost=placing&&target?{type,region,...target,rot}:null,why=ghost?C.placement(c(),ghost,mode==='move'?selected:undefined):'';
  el('worldSelection').textContent=placing?(target?`(${target.x+1}, ${target.y+1}) ${why||'배치 가능'}`:'밝은 땅을 골라 주세요'):q?`${C.TYPES[q.type].name} Lv.${q.level} · ${C.TYPES[q.type].effect}${p().ash.includes(q.id)?' · 재에 덮여 생산 중단':''}`:target?`선택 (${target.x+1}, ${target.y+1}) · ${['안전','주의','위험'][C.risk(region,target.x,target.y)]}`:'지도를 끌어 이동 · 두 손가락으로 확대';
  el('worldCatalog').hidden=mode!=='catalog';if(mode==='catalog'){const catalogHTML=Object.entries(C.TYPES).map(([k,t])=>`<button data-type="${k}" ${c().opened<t.unlock?'disabled':''}><b>${t.name}</b><small>${c().opened<t.unlock?t.unlock+'칸 개척 후 해금':`목재 ${t.cost.wood} · 고철 ${t.cost.scrap}`}</small></button>`).join('');if(el('worldCatalog')._markup!==catalogHTML){el('worldCatalog')._markup=catalogHTML;el('worldCatalog').innerHTML=catalogHTML;}}
  const btn=(a,t,disabled=false)=>`<button data-action="${a}" ${disabled?'disabled':''}>${t}</button>`;
  const actionsHTML=placing?btn('rotate','회전')+btn('confirm',mode==='move'?'이동 확정':'건설 확정',!ghost||!!why)+btn('cancel','취소'):q?(p().ash.includes(q.id)?btn('clean','재 걷어내기'):'')+btn('move','이동')+btn('upgrade',q.level<3?`강화 (${C.cost(q.type,q.level+1).wood}/${C.cost(q.type,q.level+1).scrap})`:'최대 단계',q.level>=3)+btn('demolish',remove?'철거 확정':'철거'):'';if(el('worldActions')._markup!==actionsHTML){el('worldActions')._markup=actionsHTML;el('worldActions').innerHTML=actionsHTML;}
  for(const [id,active]of [['worldExplore',mode==='explore'],['worldBuild',mode==='catalog'||placing],['worldInspect',mode==='inspect']])el(id).setAttribute('aria-pressed',active);
 }
 function diamond(x,y,fill,stroke){const [a,b]=xy(x,y);g.beginPath();g.moveTo(a,b);g.lineTo(a+32,b+16);g.lineTo(a,b+32);g.lineTo(a-32,b+16);g.closePath();g.fillStyle=fill;g.fill();if(stroke){g.strokeStyle=stroke;g.lineWidth=.7;g.stroke();}}
 function draw(now){w=stage.clientWidth;h=stage.clientHeight;const dpr=Math.min(devicePixelRatio||1,1.6);if(cv.width!==Math.round(w*dpr)||cv.height!==Math.round(h*dpr)){cv.width=Math.round(w*dpr);cv.height=Math.round(h*dpr);}g.setTransform(dpr,0,0,dpr,0,0);const bg=g.createLinearGradient(0,0,0,h);bg.addColorStop(0,'#192735');bg.addColorStop(1,'#303d40');g.fillStyle=bg;g.fillRect(0,0,w,h);const[cx,cy]=camera();g.translate(cx,cy);g.scale(zoom,zoom);
  const r=c().regions[region],isNight=M.night(s());
  for(let sum=0;sum<49;sum++)for(let x=0;x<25;x++){const y=sum-x;if(y<0||y>=25)continue;const [sx,sy]=xy(x,y);if(sx*zoom+cx<-120||sx*zoom+cx>w+120||sy*zoom+cy<-100||sy*zoom+cy>h+120)continue;const i=y*25+x,open=r.revealed[i],front=!open&&C.frontier(c(),region,x,y),n=(x*37+y*19)%7;
   diamond(x,y,open?(r.terrain[i]?'#365564':(x===12||y===12)?'#8a8b7d':['#727d72','#798477','#6d786e'][n%3]):front?'#4a5860':'#2c3a44',open?'#53635d':'#35444c');
   if(open&&!r.terrain[i]){g.fillStyle='rgba(205,203,166,.23)';g.fillRect(sx-8+n*2,sy+12,2,1);g.fillRect(sx+3,sy+22,3,1);}
   if(!open){for(let k=0;k<3;k++){g.fillStyle=front?'rgba(134,144,145,.24)':'rgba(62,77,87,.65)';g.beginPath();g.ellipse(sx+(k-1)*15,sy+14-k*3,23,12,0,0,7);g.fill();}if(front){g.fillStyle='#edcf91';g.font='12px system-ui';g.textAlign='center';g.fillText(r.hp[i]||'·',sx,sy+19);}}
  }
  const buildings=c().buildings.filter(b=>b.region===region).map(b=>({...b,depth:b.x+b.y+(b.rot?C.TYPES[b.type].h:C.TYPES[b.type].w)+(b.rot?C.TYPES[b.type].w:C.TYPES[b.type].h)}));if(region==='0,0')buildings.push({type:'center',x:12,y:12,level:1,depth:26});buildings.sort((a,b)=>a.depth-b.depth);
  for(const b of buildings){const t=C.TYPES[b.type],bw=t?(b.rot?t.h:t.w):1,bh=t?(b.rot?t.w:t.h):1,[x,y]=xy(b.x+bw/2,b.y+bh/2);if(b.id===selected)for(const[a,z]of C.cells(b))diamond(a,z,'rgba(232,195,114,.28)','#ffe1a0');
   g.fillStyle='rgba(9,17,22,.25)';g.beginPath();g.ellipse(x,y+3,32*bw*.65,13*bh*.65,0,0,7);g.fill();const P=(u,v,z)=>[x+(u-v)*32,y+(u+v-1)*16-(z||0)];B.art(g,P,b,now);
   if(isNight){const light=g.createRadialGradient(x,y-10,2,x,y-10,b.type==='tower'?58:30);light.addColorStop(0,'rgba(255,195,95,.3)');light.addColorStop(1,'rgba(255,195,95,0)');g.fillStyle=light;g.fillRect(x-60,y-70,120,120);}
   if(b.type!=='center'){g.fillStyle='#ecd4a1';g.font='bold 10px system-ui';g.textAlign='center';g.fillText('ⅠⅡⅢ'[b.level-1],x,y+14);if(p().ash.includes(b.id)){g.fillStyle='rgba(71,78,83,.65)';g.beginPath();g.ellipse(x,y-25,40,25,0,0,7);g.fill();g.fillStyle='#f3c27f';g.fillText('재 걷기',x,y-23);}}
  }
  const homes=buildings.filter(b=>b.type==='home');for(let i=0;i<Math.min(p().pop,16);i++){const b=homes[i%Math.max(1,homes.length)];if(!b)break;const phase=now/7000+i,dx=.3+(.5+.5*Math.sin(phase))*.5,dy=.3+(.5+.5*Math.cos(phase))*.5,[x,y]=xy(b.x+dx,b.y+dy);B.person(g,x,y,now,i);}
  const placing=mode==='build'||mode==='move';if(placing&&target){const b={type,region,...target,rot},why=C.placement(c(),b,mode==='move'?selected:undefined);for(const[x,y]of C.cells(b))diamond(x,y,why?'rgba(201,74,66,.55)':'rgba(137,204,146,.5)',why?'#ff9987':'#d1f1c2');}
  else if(target)diamond(target.x,target.y,'rgba(238,202,127,.12)','#ffe3a5');
  if(flash&&now-flash.t<600){const[x,y]=xy(flash.x+.5,flash.y+.5);g.strokeStyle=flash.ok?'#efd19b':'#d97e70';g.globalAlpha=1-(now-flash.t)/600;g.beginPath();g.ellipse(x,y,10+(now-flash.t)/20,5+(now-flash.t)/40,0,0,7);g.stroke();g.globalAlpha=1;}
  g.setTransform(dpr,0,0,dpr,0,0);if(isNight){g.fillStyle='rgba(13,20,35,.15)';g.fillRect(0,0,w,h);}
 }
 renderUI();
 return{tick(now,dt){tick+=dt;if(tick>=1&&!paused){act({kind:'tick',dt:Math.min(60,tick)});tick=0;}if(now-paint>40){draw(now);paint=now;}},supply:()=>act({kind:'supply'}),help:()=>el('worldHelpDialog').showModal(),build:()=>resetMode('catalog')};
};
})();
