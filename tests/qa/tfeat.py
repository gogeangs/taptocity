import subprocess,time,json,os
from playwright.sync_api import sync_playwright
os.chdir(os.path.dirname(os.path.abspath(__file__)))
srv=subprocess.Popen(['python3','-m','http.server','8807','-d','dist'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(1)
try:
 with sync_playwright() as p:
  b=p.chromium.launch();c=b.new_context(viewport={'width':390,'height':844},device_scale_factor=2,is_mobile=True,has_touch=True)
  s=json.load(open('late.json'));s['t']=time.time()*1000;s['pfAsk']=1
  c.add_init_script("localStorage.setItem('taptocity-shelter-v1',%s);localStorage.setItem('ttc_tut','1');"%json.dumps(json.dumps(s)))
  pg=c.new_page();errs=[];pg.on('pageerror',lambda e:errs.append(str(e)));pg.goto('http://localhost:8807/_t.html');pg.wait_for_timeout(2500)
  E=lambda x:pg.evaluate('s=>window.__ev(s)',x)
  E("talk=null;mq.length=0;closeModal();for(const i in S.lm)if(LMS[S.lm[i].k].key==='station')S.lm[i].ok=true;S.region='snow';S.gen=2;S.warm=50;recalc()")
  keys=E("Object.keys(FEAT_GUIDE)")
  for k in keys:
    E(f"talk=null;mq.length=0;closeModal();closeSheet();openFeatCard('{k}',true)");pg.wait_for_timeout(250)
    txt=E("modal.innerText.replace(/\\n+/g,' / ').slice(0,90)")
    if k in('line','bag','fire','radio'):pg.screenshot(path=f'aud/fc_{k}.png')
    has=E("!!modal.querySelector('[data-act=fcgo]')")
    if has:
      E(f"modal.querySelector('[data-act=fcgo]').click()");pg.wait_for_timeout(900)
      hl=E("(()=>{const e=document.querySelector('.fchl');return e?(e.getAttribute('data-act')||e.id||e.className).slice(0,40):null})()")
    else: hl='(no go)'
    print(f'{k:8} hl={hl} | {txt}')
    if k=='line':pg.screenshot(path='aud/fc_line_go.png')
  E("talk=null;mq.length=0;closeModal();openSheet('diary');diaryTab='guide';renderSheet()");pg.wait_for_timeout(400);pg.screenshot(path='aud/fc_guide.png')
  print('guide items',E("document.querySelectorAll('.fcitem').length"))
  E("document.querySelector('.fcitem').click()");pg.wait_for_timeout(300);print('reopen',E("!modal.hidden&&!!modal.querySelector('.featcard')"))
  # tickFeat auto open: new feature flag
  E("closeModal();closeSheet();S.feat.line=0;delete S.feat.line;S.featQ=[];S.featAt=0;S.playT=999;tickFeat()");pg.wait_for_timeout(300)
  print('auto card',E("!modal.hidden&&!!modal.querySelector('.featcard')&&modal.innerText.includes('끊긴 노선')"))
  print('ERRS',errs)
finally: srv.kill()
