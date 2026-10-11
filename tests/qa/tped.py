import subprocess,time,json,os
from playwright.sync_api import sync_playwright
os.chdir(os.path.dirname(os.path.abspath(__file__)))
srv=subprocess.Popen(['python3','-m','http.server','8822','-d','dist'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(1)
try:
 with sync_playwright() as p:
  b=p.chromium.launch();c=b.new_context(viewport={'width':390,'height':844},device_scale_factor=2,is_mobile=True,has_touch=True)
  s=json.load(open('mid.json'));s['t']=time.time()*1000;s['pfAsk']=1
  c.add_init_script("localStorage.setItem('taptocity-shelter-v1',%s);localStorage.setItem('ttc_tut','1');"%json.dumps(json.dumps(s)))
  pg=c.new_page();errs=[];pg.on('pageerror',lambda e:errs.append(str(e)));pg.goto('http://localhost:8822/_t.html');pg.wait_for_timeout(3500)
  E=lambda x:pg.evaluate('s=>window.__ev(s)',x)
  E("talk=null;mq.length=0;closeModal();S.clock=Math.floor(S.clock/CYCLE)*CYCLE+5")
  print(E("(()=>{const P=pedState();if(P.here==null){if(typeof pedArrive==='function')pedArrive();else{P.here=S.day||0;P.visits=(P.visits||0)+1;P.stock=P.stock||[];}}return pedState().here})()"))
  E("openPed()");pg.wait_for_timeout(400);pg.screenshot(path='ux/ped1.png')
  pg.click('[data-act=pedclose]');pg.wait_for_timeout(300);print('after close here',E("pedState().here!=null"))
  E("openPed()");pg.wait_for_timeout(300);pg.click('[data-act=pedbye]');pg.wait_for_timeout(500)
  print('after bye here',E("pedState().here!=null"),E("[...document.querySelectorAll('#toasts .tt')].map(t=>t.textContent).join('|')"))
  print('ERRS',errs)
finally: srv.kill()
