# 빨리 감기 자동 플레이: 새 게임(첫 동네) + 늦은 저장본으로 동네 4곳. 두드리기·대화 넘기기·임무 받기·증축/짓기·밤 넘기기를 반복하며 오류와 깨진 글자 수집
import subprocess,time,os,json,sys,re
from playwright.sync_api import sync_playwright
os.chdir(os.path.dirname(os.path.abspath(__file__)))
srv=subprocess.Popen(['python3','-m','http.server','8805','-d','dist'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(1)
BAD=re.compile(r'undefined|NaN|\[object|Infinity|\$\{')
out=[]
STEP="""(()=>{const r={};try{
 for(let k=0;k<12;k++)digAim();
 if(!modal.hidden){const bs=[...modal.querySelectorAll('button:not([disabled])')];const pick=bs.find(b=>/다음|확인|받기|닫기|좋아|계속|시작|고르기|데려가기|입양/.test(b.textContent))||bs[bs.length-1];if(pick)pick.click();else closeModal();}
 const cl=document.getElementById('claim');if(cl&&!cl.hidden)cl.click();
 if(S.lv<5&&canPay(scaleCost(SHUP[S.lv-1].cost,costMult()))&&modCount()>=SHUP[S.lv-1].need){try{upShelter&&upShelter()}catch(e){}}
 const fs=freeSlot();if(fs>=0){for(const id of MOD_ORDER){if(!hasMod(id)&&S.lv>=MODS[id].req&&canPay(modCost(id,0))){try{buildMod(id)}catch(e){r.bm=String(e)}break;}}}
 S.clock=(S.clock+0.6)%24;
 for(const t of document.querySelectorAll('.toast,.tt,#toasts *'))r.t=(r.t||'')+t.textContent+'|';
}catch(e){r.err=String(e).slice(0,200)}return JSON.stringify(r)})()"""
try:
 with sync_playwright() as p:
  b=p.chromium.launch()
  runs=[('new','home',None)]+[('late',rg,'late.json') for rg in ['home','desert','factory','snow']]
  for name,reg,save in runs:
    c=b.new_context(viewport={'width':390,'height':844},is_mobile=True,has_touch=True)
    if save:
      s=json.load(open(save));s['t']=time.time()*1000;s['pfAsk']=1
      c.add_init_script("localStorage.setItem('taptocity-shelter-v1',%s);localStorage.setItem('ttc_tut','1');"%json.dumps(json.dumps(s)))
    pg=c.new_page();errs=[]
    pg.on('pageerror',lambda e:errs.append(str(e)[:300]))
    pg.goto('http://localhost:8805/_t.html');pg.wait_for_timeout(2500)
    E=lambda x:pg.evaluate('s=>window.__ev(s)',x)
    if reg!='home':E(f"talk=null;mq.length=0;closeModal();S.region='{reg}';S.gen=Math.max(1,S.gen||0);recalc()")
    has=E("[typeof upShelter,typeof buildMod,typeof digAim].join()")
    seen=set();lv0=E("S.lv");sv0=E("Object.keys(S.sv).length")
    for i in range(240):
      r=json.loads(E(STEP))
      if r.get('err'):errs.append('step: '+r['err'])
      if r.get('bm'):errs.append('build: '+r['bm'])
      t=r.get('t','')
      if t and BAD.search(t) and t not in seen:seen.add(t);errs.append('글자: '+t[:200])
      pg.wait_for_timeout(120)
    info=E("JSON.stringify({lv:S.lv,day:S.day,sv:Object.keys(S.sv).length,mi:S.mi,mods:modCount(),rev:S.rev.filter(x=>x).length})")
    print(f'== {name}/{reg} fns[{has}] lv {lv0}->',info,flush=True)
    for e in dict.fromkeys(errs):print('   !!',e)
    c.close()
finally: srv.kill()
