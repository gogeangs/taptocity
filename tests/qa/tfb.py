import subprocess,time,json,os,sys
from playwright.sync_api import sync_playwright
os.chdir(os.path.dirname(os.path.abspath(__file__)))
srv=subprocess.Popen(['python3','-m','http.server','8819','-d','dist'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(1)
try:
 with sync_playwright() as p:
  b=p.chromium.launch()
  for save in ['early.json','mid.json']:
   c=b.new_context(viewport={'width':360,'height':740},device_scale_factor=2,is_mobile=True,has_touch=True)
   s=json.load(open(save));s['t']=time.time()*1000;s['pfAsk']=1
   c.add_init_script("localStorage.setItem('taptocity-shelter-v1',%s);localStorage.setItem('ttc_tut','1');"%json.dumps(json.dumps(s)))
   pg=c.new_page();errs=[];pg.on('pageerror',lambda e:errs.append(str(e)));pg.goto('http://localhost:8819/_t.html');pg.wait_for_timeout(5000)
   E=lambda x:pg.evaluate('s=>window.__ev(s)',x)
   kb=E("Math.round(performance.getEntriesByType('resource').filter(r=>/illustrated/.test(r.name)).reduce((a,r)=>a+(r.decodedBodySize||0),0)/1024)")
   print(save,'images KB at start',kb,E("performance.getEntriesByType('resource').filter(r=>/illustrated/.test(r.name)).map(r=>r.name.split('/').pop()).join(',')"))
   E("talk=null;mq.length=0;closeModal()");pg.wait_for_timeout(800);pg.screenshot(path=f'ux/lazy_{save[:-5]}.png')
   if save=='mid.json':
     for sh in ['surv','exp','gear','radio']:
       E(f"openSheet('{sh}')");pg.wait_for_timeout(900)
     E("closeSheet()")
     print('after sheets KB',E("Math.round(performance.getEntriesByType('resource').filter(r=>/illustrated/.test(r.name)).reduce((a,r)=>a+(r.decodedBodySize||0),0)/1024)"))
     E("openSheet('gear')");pg.wait_for_timeout(1200);pg.screenshot(path='ux/lazy_gear.png')
     # feedback
     E("closeSheet();openSheet('settings')");pg.wait_for_timeout(400);pg.screenshot(path='ux/fb_settings.png')
     pg.click('[data-act=fbopen]');pg.wait_for_timeout(400)
     pg.click('[data-act=fbcat][data-arg=bug]');pg.fill('#fbText','라디오 탭에서 가끔 버튼이 안 눌려요');pg.wait_for_timeout(200)
     pg.screenshot(path='ux/fb_form.png')
     pg.click('[data-act=fbsend]');pg.wait_for_timeout(800)
     print('queue',E("localStorage.getItem('ttc_fb_q')")[:300])
     pg.screenshot(path='ux/fb_done.png')
   print('ERRS',errs)
finally: srv.kill()
