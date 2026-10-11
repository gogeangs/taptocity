import subprocess,time,json,os
from playwright.sync_api import sync_playwright
os.chdir(os.path.dirname(os.path.abspath(__file__)))
srv=subprocess.Popen(['python3','-m','http.server','8817','-d','dist'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(1)
try:
 with sync_playwright() as p:
  b=p.chromium.launch();c=b.new_context(viewport={'width':360,'height':740},device_scale_factor=2,is_mobile=True,has_touch=True)
  s=json.load(open('mid.json'));s['t']=time.time()*1000;s['pfAsk']=1
  c.add_init_script("localStorage.setItem('taptocity-shelter-v1',%s);localStorage.setItem('ttc_tut','1');"%json.dumps(json.dumps(s)))
  pg=c.new_page();errs=[];pg.on('pageerror',lambda e:errs.append(str(e)));pg.goto('http://localhost:8817/_t.html');pg.wait_for_timeout(3500)
  E=lambda x:pg.evaluate('s=>window.__ev(s)',x)
  print('load KB',E("Math.round(performance.getEntriesByType('resource').reduce((a,r)=>a+(r.decodedBodySize||0),0)/1024)"),E("performance.getEntriesByType('resource').sort((a,b)=>b.decodedBodySize-a.decodedBodySize).slice(0,6).map(r=>r.name.split('/').pop()+':'+Math.round(r.decodedBodySize/1024)).join(', ')"))
  E("talk=null;mq.length=0;closeModal();openSheet('settings')");pg.wait_for_timeout(300)
  before=E("SET.vib");pg.locator('.setrow .t',has_text='진동').click();pg.wait_for_timeout(200);print('row toggle',before,'->',E("SET.vib"))
  pg.locator('.setrow .t',has_text='진동').click()
  E("closeSheet()");pg.wait_for_timeout(200)
  pg.locator('nav.tabs .tab').nth(0).click();pg.wait_for_timeout(300);print('sheet open',E("sheetTab"))
  pg.go_back();pg.wait_for_timeout(400);print('after back',E("sheetTab"),pg.url[-12:])
  pg.locator('nav.tabs .tab').nth(1).click();pg.wait_for_timeout(300)
  pg.mouse.click(180,40);pg.wait_for_timeout(300);print('tap HUD while sheet open ->',E("sheetTab"))
  print('ERRS',errs)
finally: srv.kill()
