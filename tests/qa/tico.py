import subprocess,time,json,os
from playwright.sync_api import sync_playwright
os.chdir(os.path.dirname(os.path.abspath(__file__)))
srv=subprocess.Popen(['python3','-m','http.server','8814','-d','dist'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(1)
try:
 with sync_playwright() as p:
  b=p.chromium.launch();c=b.new_context(viewport={'width':390,'height':844},device_scale_factor=2,is_mobile=True,has_touch=True)
  s=json.load(open('mid.json'));s['t']=time.time()*1000;s['pfAsk']=1
  c.add_init_script("localStorage.setItem('taptocity-shelter-v1',%s);localStorage.setItem('ttc_tut','1');"%json.dumps(json.dumps(s)))
  pg=c.new_page();errs=[];pg.on('pageerror',lambda e:errs.append(str(e)));pg.goto('http://localhost:8814/_t.html');pg.wait_for_timeout(3500)
  E=lambda x:pg.evaluate('s=>window.__ev(s)',x)
  E("talk=null;mq.length=0;closeModal();closeSheet();NQ.length=0")
  print(E("icoTxt('기계를 멈췄어요 · 고철 +34 · 건전지 +1 · 희망 +3 · 방화천 +1 · 체력 -2')"))
  E("toast('모래 속에 묻힌 물통과 연료 통! · '+lootTxt({fuel:12,food:5}))");pg.wait_for_timeout(300)
  pg.screenshot(path='aud/ico1.png')
  E("$('toasts').innerHTML='';NCUR=null;note({h:'나 · 30% 왔어요',t:'“쉘터에 새 기둥이 하나 더 섰다.”<br><small>작은 보상 · '+lootTxt({scrap:34,batt:1})+'</small>',kind:'story',ms:9000})");pg.wait_for_timeout(400)
  pg.screenshot(path='aud/ico2.png')
  E("$('toasts').innerHTML='';NQ.length=0;NCUR=null;note({h:'모닥불을 꺼뜨리지 마세요',t:'<small>위 띠의 모닥불을 눌러 장작을 넣어요</small>',fc:'fire',kind:'story',ms:9000})");pg.wait_for_timeout(400)
  pg.screenshot(path='aud/ico3.png')
  E("document.querySelector('#toasts .tt.fc').click()");pg.wait_for_timeout(500)
  print('card open',E("!modal.hidden&&!!modal.querySelector('.featcard')"))
  E("closeModal();S.onb=1;openOnboard()");pg.wait_for_timeout(500);pg.screenshot(path='aud/ico4.png')
  print('ERRS',errs)
finally: srv.kill()
