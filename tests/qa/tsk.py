import subprocess,time,json,os
from playwright.sync_api import sync_playwright
os.chdir(os.path.dirname(os.path.abspath(__file__)))
srv=subprocess.Popen(['python3','-m','http.server','8821','-d','dist'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(1)
try:
 with sync_playwright() as p:
  b=p.chromium.launch();c=b.new_context(viewport={'width':390,'height':844},device_scale_factor=2,is_mobile=True,has_touch=True)
  s=json.load(open('early.json'));s['t']=time.time()*1000;s['pfAsk']=1
  c.add_init_script("localStorage.setItem('taptocity-shelter-v1',%s);localStorage.setItem('ttc_tut','1');"%json.dumps(json.dumps(s)))
  pg=c.new_page();errs=[];pg.on('pageerror',lambda e:errs.append(str(e)));pg.goto('http://localhost:8821/_t.html');pg.wait_for_timeout(3500)
  E=lambda x:pg.evaluate('s=>window.__ev(s)',x)
  E("talk=null;mq.length=0;closeModal()")
  ys=[]
  for i in range(5):
    tab=['surv','exp','shelter','radio','diary'][i]
    # point the guide at each tab
    E(f"window.__ft=focusTarget;focusTarget=()=>({{el:document.querySelectorAll('nav.tabs .tab')[{i}],t:'여기'}});updateGuide()");pg.wait_for_timeout(400)
    ys.append(E("(()=>{const k=$('skills').getBoundingClientRect(),g=$('guide').getBoundingClientRect(),st=$('guide').querySelector('.gstem');return [Math.round(k.top),Math.round(g.top),Math.round(g.bottom),st?st.style.height:'-',Math.round(k.left),Math.round(k.right)]})()"))
    pg.screenshot(path=f'ux/sk{i}.png')
  print(ys)
  print('ERRS',errs)
finally: srv.kill()
