import subprocess,time,json,os
from playwright.sync_api import sync_playwright
os.chdir(os.path.dirname(os.path.abspath(__file__)))
srv=subprocess.Popen(['python3','-m','http.server','8813','-d','dist'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(1)
try:
 with sync_playwright() as p:
  b=p.chromium.launch();c=b.new_context(viewport={'width':390,'height':844},device_scale_factor=2,is_mobile=True,has_touch=True)
  s=json.load(open('mid.json'));s['t']=time.time()*1000;s['pfAsk']=1
  c.add_init_script("localStorage.setItem('taptocity-shelter-v1',%s);localStorage.setItem('ttc_tut','1');"%json.dumps(json.dumps(s)))
  pg=c.new_page();errs=[];pg.on('pageerror',lambda e:errs.append(str(e)));pg.goto('http://localhost:8813/_t.html');pg.wait_for_timeout(3500)
  E=lambda x:pg.evaluate('s=>window.__ev(s)',x)
  E("talk=null;mq.length=0;closeModal();closeSheet()")
  # 수상한 밤 직전으로
  E("S.clock=Math.floor(S.clock/CYCLE)*CYCLE+ODD_AT-6;oddPlan={k:'knock',done:0};oddNightSeen=S.nightCount||0;wasNight=true")
  pg.wait_for_timeout(1500)
  print('dread',E("DRD"),E("$('stage').className"),E("$('clockTxt').textContent"))
  pg.screenshot(path='aud/dread1.png')
  pg.wait_for_timeout(6000)
  print('after odd',E("oddPlan&&oddPlan.done"),E("DRD"),E("$('stage').className"))
  for k in ['light','steps','dog','lamp','breath','mud']:
    E(f"runPresence(PRS_T.find(x=>x[0]==='{k}'))");pg.wait_for_timeout(300)
  pg.screenshot(path='aud/dread2.png')
  # 기척 예약 경로
  E("oddPlan=null;prsNight=-1;S.clock=Math.floor(S.clock/CYCLE)*CYCLE+DAY+2;Math.random=()=>.1")
  pg.wait_for_timeout(1200);print('PRS',E("JSON.stringify(PRS)"))
  print('ERRS',errs)
finally: srv.kill()
