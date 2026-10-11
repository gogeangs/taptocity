import subprocess,time,json,os
from playwright.sync_api import sync_playwright
os.chdir(os.path.dirname(os.path.abspath(__file__)))
srv=subprocess.Popen(['python3','-m','http.server','8824','-d','dist'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(1)
try:
 with sync_playwright() as p:
  b=p.chromium.launch();c=b.new_context(viewport={'width':390,'height':844},device_scale_factor=2,is_mobile=True,has_touch=True)
  s=json.load(open('late.json'));s['t']=time.time()*1000;s['pfAsk']=1
  c.add_init_script("localStorage.setItem('taptocity-shelter-v1',%s);localStorage.setItem('ttc_tut','1');"%json.dumps(json.dumps(s)))
  pg=c.new_page();errs=[];pg.on('pageerror',lambda e:errs.append(str(e)));pg.goto('http://localhost:8824/_t.html');pg.wait_for_timeout(3500)
  E=lambda x:pg.evaluate('s=>window.__ev(s)',x)
  E("talk=null;mq.length=0;closeModal()")
  print('before last',E("S.ug.last"),'ck',E("JSON.stringify(S.ug.ck)"),'ugLast',E("ugLast()"))
  E("openUGPrep()");pg.wait_for_timeout(400)
  print(E("(modal.querySelector('.ugstart')||{}).innerText"))
  # pick a member and go
  E("ugPrep.team=[Object.keys(S.sv).map(Number).filter(id=>!busy(id))[0]];renderPrep()");pg.click('[data-act=ugo]');pg.wait_for_timeout(400)
  print('start floor',E("UG.floor"),E("UG.msg"))
  E("ugFloor();ugFloor()");print('deeper',E("UG.floor"),'last',E("S.ug.last"))
  E("ugEnd(true)");pg.wait_for_timeout(300);E("closeModal()")
  E("openUGPrep()");pg.wait_for_timeout(400);print(E("(modal.querySelector('.ugstart')||{}).innerText"))
  pg.screenshot(path='ux/ugprep.png')
  E("modal.querySelector('[data-act=ugs][data-arg=\"1\"]').click()");pg.wait_for_timeout(200);print('chosen',E("ugStartF()"))
  E("modal.querySelector('[data-act=ugs][data-arg=\"3\"]').click()");pg.wait_for_timeout(200);pg.click('[data-act=ugo]');pg.wait_for_timeout(400)
  print('resume floor',E("UG.floor"),E("UG.msg"))
  print('ERRS',errs)
finally: srv.kill()
