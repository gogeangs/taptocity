import subprocess,time,json,os
from playwright.sync_api import sync_playwright
os.chdir(os.path.dirname(os.path.abspath(__file__)))
srv=subprocess.Popen(['python3','-m','http.server','8825','-d','dist'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(1)
try:
 with sync_playwright() as p:
  b=p.chromium.launch();c=b.new_context(viewport={'width':390,'height':844},device_scale_factor=2,is_mobile=True,has_touch=True)
  s=json.load(open('late.json'));s['t']=time.time()*1000;s['pfAsk']=1
  c.add_init_script("localStorage.setItem('taptocity-shelter-v1',%s);localStorage.setItem('ttc_tut','1');"%json.dumps(json.dumps(s)))
  pg=c.new_page();errs=[];pg.on('pageerror',lambda e:errs.append(str(e)));pg.goto('http://localhost:8825/_t.html');pg.wait_for_timeout(3500)
  E=lambda x:pg.evaluate('s=>window.__ev(s)',x)
  E("talk=null;mq.length=0;closeModal();for(const i in S.lm)if(LMS[S.lm[i].k].key==='station')S.lm[i].ok=true;recalc()")
  E("openLnPrep()");pg.wait_for_timeout(500)
  print('rec',E("JSON.stringify(lnRecommend(lnFree()))"))
  pg.screenshot(path='ux/lnrec1.png')
  pg.click('[data-act=lnrec]');pg.wait_for_timeout(300)
  print('team',E("JSON.stringify(lnPrep.team)"),'go enabled',E("!modal.querySelector('[data-act=lngo]').disabled"))
  pg.screenshot(path='ux/lnrec2.png')
  print('ERRS',errs)
finally: srv.kill()
