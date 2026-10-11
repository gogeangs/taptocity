import subprocess,time,json
from playwright.sync_api import sync_playwright
srv=subprocess.Popen(['python3','-m','http.server','8803','-d','dist'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(1)
try:
 with sync_playwright() as p:
  b=p.chromium.launch();pg=b.new_page();errs=[];pg.on('pageerror',lambda e:errs.append(str(e)));pg.goto('http://localhost:8803/_t.html');pg.wait_for_timeout(3000)
  r=pg.evaluate(r'''()=>window.__ev(`(()=>{const P=[];
  // 장비
  for(const [k,G] of Object.entries(GEAR)){if(!GIC[G.ic])P.push('장비 아이콘 없음 '+k+':'+G.ic);for(const e in G.eff)if(!EFFN[e])P.push('장비 효과 이름 없음 '+k+':'+e);if(!SLOTN[G.slot])P.push('장비 칸 '+k);if(!GR[G.g])P.push('장비 등급 '+k);for(const f of (G.fit||[]))if(!SURV[f])P.push('잘 맞는 사람 없음 '+k+':'+f);if(G.cost)for(const m in G.cost)if(!MN[m])P.push('장비 재료 '+k+':'+m);}
  // 생존자
  SURV.forEach((s,k)=>{if(!s.name)P.push('이름 없음 '+k);if(!ROLE[k])P.push('역할 없음 '+k+' '+s.name);if(!s.hidden&&!TRACE_ITEM[k])P.push('흔적 없음 '+k);try{const h=portrait(s);if(!h||/undefined/.test(h))P.push('초상 이상 '+s.name)}catch(e){P.push('초상 예외 '+s.name)}});
  // 퀘스트 장비
  for(const id in QUESTS){const Q=QUESTS[id];if(Q.gear&&!GEAR[Q.gear])P.push('퀘스트 장비 없음 '+id+':'+Q.gear)}
  // 자원 키
  for(const k of Object.keys(MN)){if(!(k in RIC))P.push('자원 그림 없음 '+k)}
  // 모듈 비용 재료
  for(const id in MODS){for(let l=0;l<3;l++){try{const c=modCost(+id,l);for(const m in c)if(!MN[m])P.push('모듈 재료 '+id+':'+m)}catch(e){}}}
  for(const u of SHUP)for(const m in u.cost)if(!MN[m])P.push('증축 재료 '+m);
  // 노선
  for(const [r,T] of Object.entries(LN_TOWN)){for(const t of T.items){if(!GEAR[t])P.push('노선 물건 '+t);if(!(t in LNI))P.push('노선 그림 '+t)}for(const m of T.loot)if(!MN[m])P.push('노선 자원 '+r+':'+m)}
  // 펫
  for(const k in PETS){const Q=PETS[k];if(Q.pair!=null&&!SURV[Q.pair])P.push('펫 짝 '+k)}
  // 랜드마크
  for(const l of LMS)for(const m in l.cost)if(!MN[m])P.push('랜드마크 재료 '+l.key);
  return JSON.stringify({problems:P,counts:{gear:Object.keys(GEAR).length,surv:SURV.length,res:Object.keys(MN).length,pets:Object.keys(PETS).length}})})()`)''')
  print(r);print('errs',errs)
finally: srv.kill()
