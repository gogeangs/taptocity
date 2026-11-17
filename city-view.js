/* On-demand city map. Native scrolling handles touch pan; no continuous render loop. */
(function(){'use strict';
window.TTCCityView=function(bridge){
 const C=window.TTCCity,types=C.TYPES;let dialog,canvas,ctx,viewport,region='0,0',mode='inspect',type='home',rotation=0,selected=null,target=null,zoom=40,confirmDelete=false,focusBefore;
 const el=id=>dialog.querySelector('#'+id),state=()=>bridge.state(),city=()=>C.ensure(state());
 const message=t=>{el('cityMessage').textContent=t;};
 function action(a){const result=bridge.act(a);message(result.message);if(result.ok)confirmDelete=false;render();return result;}
 function open(){if(dialog){dialog.showModal();return;}mode='inspect';selected=null;target=null;rotation=0;confirmDelete=false;focusBefore=document.activeElement;try{region=city().active;}catch(e){bridge.notify(e.message);return;}
 dialog=document.createElement('dialog');dialog.id='cityDialog';dialog.setAttribute('aria-labelledby','cityTitle');dialog.innerHTML=`<header><div><small>개척한 땅은 그대로 남아요</small><h2 id="cityTitle">우리의 도시</h2></div><button id="cityClose" aria-label="도시 닫기">닫기</button></header><div id="citySummary"></div><nav aria-label="도시 구역"><button data-region="0,0">중심 거점 · 25×25</button><button data-region="1,0">동쪽 구역 · 25×25</button></nav><div class="cityTools"><button id="cityExplore">개척</button><button id="cityInspect">선택</button><button id="cityZoomOut" aria-label="지도 축소">−</button><button id="cityZoomIn" aria-label="지도 확대">＋</button><button id="cityCenter">중심으로</button></div><div id="cityViewport" tabindex="0" aria-label="도시 지도. 드래그 또는 스크롤로 이동, 방향키로 칸 선택, Enter로 선택 실행"><canvas id="cityCanvas" role="img" aria-label="25 곱하기 25 도시 지도"></canvas></div><div id="cityMessage" role="status" aria-live="polite">건물을 고르고 땅을 눌러 배치할 수 있어요.</div><div id="citySelection"></div><div id="cityCatalog"></div><footer><button id="cityRotate">회전</button><button id="cityConfirm">여기에 건설</button><button id="cityCancel">취소</button></footer>`;
 document.body.appendChild(dialog);canvas=el('cityCanvas');ctx=canvas.getContext('2d');viewport=el('cityViewport');
 dialog.addEventListener('close',()=>{dialog.remove();dialog=null;bridge.closed();focusBefore?.focus();});
 el('cityClose').onclick=()=>dialog.close();
 dialog.addEventListener('click',e=>{const b=e.target.closest('button');if(!b)return;
 if(b.dataset.region){region=b.dataset.region;target=null;selected=null;confirmDelete=false;if(city().regions[region].revealed.some(Boolean))action({kind:'region',region});else{message('동쪽 경계는 중심 거점의 오른쪽 끝에서 이어져요. 서쪽 끝 칸부터 개척해 주세요.');render();}center();}
 if(b.dataset.type){mode='build';type=b.dataset.type;rotation=0;target=null;confirmDelete=false;message('지도에서 건물의 왼쪽 위 칸을 골라 주세요.');render();}
 });
 el('cityExplore').onclick=()=>{mode='explore';target=null;message('밝혀진 땅 옆의 재를 두드려 개척해요.');render();};
 el('cityInspect').onclick=cancel;
 el('cityCancel').onclick=cancel;
 el('cityRotate').onclick=()=>{rotation=1-rotation;render();};
 el('cityConfirm').onclick=()=>{if(!target)return;const a={kind:mode,region,x:target.x,y:target.y,rot:rotation};if(mode==='build')a.type=type;else a.id=selected;const r=action(a);if(r.ok){mode='inspect';selected=C.at(city(),region,target.x,target.y)?.id;render();}};
 el('cityZoomIn').onclick=()=>scale(8);el('cityZoomOut').onclick=()=>scale(-8);el('cityCenter').onclick=center;
 let down=null;
 canvas.addEventListener('pointerdown',e=>{down={x:e.clientX,y:e.clientY,sx:viewport.scrollLeft,sy:viewport.scrollTop,id:e.pointerId};if(e.pointerType==='mouse')canvas.setPointerCapture(e.pointerId);});
 canvas.addEventListener('pointermove',e=>{if(down&&e.pointerType==='mouse'&&e.buttons){viewport.scrollLeft=down.sx+down.x-e.clientX;viewport.scrollTop=down.sy+down.y-e.clientY;}});
 canvas.addEventListener('pointercancel',()=>{down=null;});
 canvas.addEventListener('pointerup',e=>{if(!down||Math.hypot(e.clientX-down.x,e.clientY-down.y)>8){down=null;return;}down=null;const r=canvas.getBoundingClientRect();pick(Math.floor((e.clientX-r.left)/zoom),Math.floor((e.clientY-r.top)/zoom));});
 viewport.addEventListener('keydown',e=>{const steps={ArrowLeft:[-1,0],ArrowRight:[1,0],ArrowUp:[0,-1],ArrowDown:[0,1]};if(steps[e.key]){e.preventDefault();const d=steps[e.key],p=target||{x:12,y:12};target={x:Math.max(0,Math.min(24,p.x+d[0])),y:Math.max(0,Math.min(24,p.y+d[1]))};render();viewport.scrollLeft=Math.max(0,target.x*zoom-viewport.clientWidth/2);viewport.scrollTop=Math.max(0,target.y*zoom-viewport.clientHeight/2);}else if(e.key==='Enter'){e.preventDefault();const p=target||{x:12,y:12};pick(p.x,p.y);}});
 dialog.showModal();render();center();
 }
 function cancel(){mode='inspect';target=null;confirmDelete=false;message('건물을 누르면 이동·강화·철거할 수 있어요.');render();}
 function center(){const x=region==='1,0'&&!city().regions[region].revealed.some(Boolean)?0:12;viewport.scrollLeft=Math.max(0,(x+.5)*zoom-viewport.clientWidth/2);viewport.scrollTop=Math.max(0,12.5*zoom-viewport.clientHeight/2);}
 function scale(delta){const old=zoom,cx=(viewport.scrollLeft+viewport.clientWidth/2)/old,cy=(viewport.scrollTop+viewport.clientHeight/2)/old;zoom=Math.max(24,Math.min(64,zoom+delta));render();viewport.scrollLeft=cx*zoom-viewport.clientWidth/2;viewport.scrollTop=cy*zoom-viewport.clientHeight/2;}
 function pick(x,y){if(x<0||y<0||x>=25||y>=25)return;target={x,y};confirmDelete=false;if(mode==='explore'){action({kind:'explore',region,x,y});return;}if(mode==='inspect')selected=C.at(city(),region,x,y)?.id||null;render();}
 function render(){if(!dialog)return;const s=state(),c=city(),r=c.regions[region];
 el('citySummary').textContent=`개척 ${c.opened}/1,250칸 · 건물 ${c.buildings.length} · 목재 ${Math.floor(s.m.wood||0)} · 고철 ${Math.floor(s.m.scrap||0)}`;
 dialog.querySelectorAll('[data-region]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.region===region)));
 el('cityExplore').setAttribute('aria-pressed',String(mode==='explore'));el('cityInspect').setAttribute('aria-pressed',String(mode==='inspect'));
 el('cityCatalog').innerHTML=Object.entries(types).map(([k,t])=>`<button data-type="${k}" ${c.opened<t.unlock?'disabled':''} aria-pressed="${mode==='build'&&type===k}"><b>${t.name}</b><small>${t.w}×${t.h} · 목재 ${t.cost.wood} / 고철 ${t.cost.scrap}</small><small>${c.opened<t.unlock?t.unlock+'칸 개척 후 해금':t.effect}</small></button>`).join('');
 const placing=mode==='build'||mode==='move',b=c.buildings.find(b=>b.id===selected),ghost=placing&&target?{type:mode==='move'?b?.type:type,region,...target,rot:rotation}:null;
 const why=ghost?C.placement(c,ghost,mode==='move'?selected:undefined):'';
 el('cityRotate').hidden=!placing;el('cityConfirm').hidden=!placing;el('cityCancel').hidden=mode==='inspect';el('cityConfirm').disabled=!target||!!why;el('cityConfirm').textContent=mode==='move'?'이동 확정':'건설 확정';
 const selection=el('citySelection');selection.replaceChildren();
 if(placing){selection.textContent=target?`(${target.x+1}, ${target.y+1}) · ${why||'배치 가능 · 확정을 누르면 적용돼요'}`:'바닥을 골라 미리보기를 확인해 주세요.';}
 else if(b){selection.textContent=`${types[b.type].name} · ${b.level}단계 · ${types[b.type].effect} `;
 const button=(label,fn,disabled=false)=>{const q=document.createElement('button');q.textContent=label;q.onclick=fn;q.disabled=disabled;selection.appendChild(q);};
 button('이동',()=>{mode='move';rotation=b.rot;target={x:b.x,y:b.y};render();});
 const up=b.level<3?C.cost(b.type,b.level+1):null;
 button(up?`강화 · 목재 ${up.wood} / 고철 ${up.scrap}`:'최대 단계',()=>action({kind:'upgrade',id:b.id}),!up);
 button(confirmDelete?'철거 확정 · 반환 없음':'철거',()=>{if(!confirmDelete){confirmDelete=true;message('철거하면 자재는 돌아오지 않아요. 철거 확정을 눌러 주세요.');render();}else{const res=action({kind:'demolish',id:b.id,confirm:true});if(res.ok){selected=null;render();}}});
 }else selection.textContent=target?`(${target.x+1}, ${target.y+1}) · ${r.revealed[target.y*25+target.x]?'개척 완료':['안전','주의','위험'][C.risk(region,target.x,target.y)]}`:'지도를 밀어 이동하세요 · 방향키와 Enter도 사용할 수 있어요';
 const dpr=Math.min(window.devicePixelRatio||1,2),size=25*zoom;canvas.width=size*dpr;canvas.height=size*dpr;canvas.style.width=size+'px';canvas.style.height=size+'px';ctx.setTransform(dpr,0,0,dpr,0,0);
 for(let y=0;y<25;y++)for(let x=0;x<25;x++){const i=y*25+x,shown=r.revealed[i],front=!shown&&C.frontier(c,region,x,y);ctx.fillStyle=shown?(r.terrain[i]?'#334e61':'#68766b'):front?'#59616c':'#2c343f';ctx.fillRect(x*zoom,y*zoom,zoom-1,zoom-1);if(front){ctx.fillStyle='#e1c384';ctx.font=`${Math.round(zoom*.35)}px sans-serif`;ctx.textAlign='center';ctx.fillText(r.hp[i]||'·',(x+.5)*zoom,(y+.63)*zoom);}}
 if(region==='0,0'){ctx.fillStyle='#edc976';ctx.beginPath();ctx.arc(12.5*zoom,12.5*zoom,zoom*.3,0,Math.PI*2);ctx.fill();}
 const colors={home:'#bca682',farm:'#93b183',workshop:'#94a9b6',tower:'#c8b779'};
 for(const q of c.buildings.filter(b=>b.region===region)){const t=types[q.type],w=(q.rot?t.h:t.w)*zoom,h=(q.rot?t.w:t.h)*zoom;ctx.fillStyle=colors[q.type];ctx.fillRect(q.x*zoom+3,q.y*zoom+3,w-6,h-6);ctx.fillStyle='#202b33';ctx.font=`bold ${Math.max(11,zoom*.28)}px sans-serif`;ctx.textAlign='center';ctx.fillText(t.name,(q.x*zoom+w/2),q.y*zoom+h/2);ctx.font='11px sans-serif';ctx.fillText('Lv.'+q.level,q.x*zoom+w/2,q.y*zoom+h/2+15);if(q.id===selected){ctx.strokeStyle='#fff4cf';ctx.lineWidth=3;ctx.strokeRect(q.x*zoom+2,q.y*zoom+2,w-4,h-4);}}
 if(ghost){ctx.fillStyle=why?'rgba(235,93,93,.55)':'rgba(157,226,166,.55)';for(const[x,y]of C.cells(ghost))ctx.fillRect(x*zoom+1,y*zoom+1,zoom-2,zoom-2);}
 if(target){ctx.strokeStyle='#ffe3a5';ctx.lineWidth=2;ctx.strokeRect(target.x*zoom+1,target.y*zoom+1,zoom-2,zoom-2);}
 }
 return{open};
};
})();
