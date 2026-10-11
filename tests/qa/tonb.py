import subprocess,time,json,os
from playwright.sync_api import sync_playwright
os.chdir(os.path.dirname(os.path.abspath(__file__)))
srv=subprocess.Popen(['python3','-m','http.server','8812','-d','dist'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(1)
try:
 with sync_playwright() as p:
  b=p.chromium.launch();c=b.new_context(viewport={'width':390,'height':844},device_scale_factor=2,is_mobile=True,has_touch=True)
  pg=c.new_page();errs=[];pg.on('pageerror',lambda e:errs.append(str(e)));pg.goto('http://localhost:8812/_t.html');pg.wait_for_timeout(3000)
  E=lambda x:pg.evaluate('s=>window.__ev(s)',x)
  print('tut running',E("!!S.tut"))
  # 튜토리얼을 끝까지 넘긴 것으로 처리
  E("talk=null;mq.length=0;closeModal();tutEnd=1");pg.wait_for_timeout(2500)
  print('onb',E("S.onb"),'card',E("!modal.hidden&&!!modal.querySelector('.onb')"),'storyI',E("S.storyI"))
  pg.screenshot(path='aud/onb1.png')
  E("modal.querySelector('[data-act=onbtour]').click()");pg.wait_for_timeout(600)
  for i in range(5):
    pg.screenshot(path=f'aud/onb_t{i}.png')
    print('tour',i,E("$('coach')&&$('coach').querySelector('.cbub b').textContent"))
    E("$('coach')&&$('coach').querySelector('.cnext').click()");pg.wait_for_timeout(500)
  print('after tour onb',E("S.onb"),'coach',E("!!$('coach')"))
  pg.wait_for_timeout(2500)
  print('story intro shown',E("!!talk||(!modal.hidden&&modal.innerText.slice(0,60))"),'storyI',E("S.storyI"))
  pg.screenshot(path='aud/onb_after.png')
  # 새로고침 중간 재개 확인
  E("S.onb=1;save()");pg.reload();pg.wait_for_timeout(4500)
  print('resume card',E("!modal.hidden&&!!modal.querySelector('.onb')"))
  print('ERRS',errs)
finally: srv.kill()
