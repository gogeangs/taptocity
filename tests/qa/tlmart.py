import subprocess,time,json,os
from playwright.sync_api import sync_playwright
os.chdir(os.path.dirname(os.path.abspath(__file__)))
srv=subprocess.Popen(['python3','-m','http.server','8826','-d','dist'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(1)
try:
 with sync_playwright() as p:
  b=p.chromium.launch()
  for reg in ['desert','factory','snow']:
   c=b.new_context(viewport={'width':390,'height':844},device_scale_factor=2,is_mobile=True,has_touch=True)
   s=json.load(open('late.json'));s['t']=time.time()*1000;s['pfAsk']=1
   c.add_init_script("localStorage.setItem('taptocity-shelter-v1',%s);localStorage.setItem('ttc_tut','1');"%json.dumps(json.dumps(s)))
   pg=c.new_page();errs=[];pg.on('pageerror',lambda e:errs.append(str(e)));pg.goto('http://localhost:8826/_t.html');pg.wait_for_timeout(3000)
   E=lambda x:pg.evaluate('s=>window.__ev(s)',x)
   E(f"talk=null;mq.length=0;closeModal();S.region='{reg}';S.gen=Math.max(1,S.gen||0);recalc();for(const i in S.lm){{S.rev[i]=1;}}const ks=Object.keys(S.lm);ks.forEach((i,n)=>S.lm[i].ok=n%2==0);")
   E("talk=null;mq.length=0;closeModal()")
   pg.wait_for_timeout(1500)
   tiles=E("Object.keys(S.lm).map(Number)")
   print(reg,'lms',len(tiles),'art',E("TTCDesign.lmArtKey()"))
   for n,i in enumerate(tiles[:4]):
     E(f"talk=null;mq.length=0;closeModal();cam.z=2.2;const[x,y]=tileC({i},0);cam.x=x;cam.y=y-20");pg.wait_for_timeout(700)
     pg.screenshot(path=f'ux/lmart_{reg}_{n}.png',clip={'x':95,'y':250,'width':200,'height':260})
   print('ERRS',errs)
   c.close()
finally: srv.kill()
