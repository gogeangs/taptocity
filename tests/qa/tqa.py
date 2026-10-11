# 전 화면 훑기: 저장본 × 동네 × 시트/탭/모달 → 깨진 글자·가로 넘침·콘솔 오류
import subprocess,time,os,json,sys,re
from playwright.sync_api import sync_playwright
os.chdir(os.path.dirname(os.path.abspath(__file__)))
PORT=sys.argv[1] if len(sys.argv)>1 else '8801'
W=int(sys.argv[2]) if len(sys.argv)>2 else 390
UA=sys.argv[3] if len(sys.argv)>3 else None
srv=subprocess.Popen(['python3','-m','http.server',PORT,'-d','dist'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(1)
BAD=re.compile(r'undefined|NaN|\[object|\bnull\b|Infinity|\$\{')
issues=[]
def note(where,what):
  issues.append((where,what));print('!!',where,'|',what[:220],flush=True)
try:
 with sync_playwright() as p:
  b=p.chromium.launch()
  for save in ['early.json','mid.json','late.json']:
   for reg in ['home','desert','factory','snow']:
    if save=='early.json' and reg!='home':continue
    kw=dict(viewport={'width':W,'height':844},device_scale_factor=1,is_mobile=True,has_touch=True)
    if UA:kw['user_agent']=UA
    c=b.new_context(**kw)
    s=json.load(open(save));s['t']=time.time()*1000;s['pfAsk']=1
    c.add_init_script("localStorage.setItem('taptocity-shelter-v1',%s);localStorage.setItem('ttc_tut','1');"%json.dumps(json.dumps(s)))
    pg=c.new_page();errs=[]
    pg.on('pageerror',lambda e:errs.append('pageerror: '+str(e)))
    pg.on('console',lambda m:(m.type=='error' and 'net::' not in m.text and 'gstatic' not in m.text and 'Failed to load resource' not in m.text) and errs.append('console: '+m.text))
    pg.goto(f'http://localhost:{PORT}/_t.html');pg.wait_for_timeout(2200)
    E=lambda x:pg.evaluate('s=>window.__ev(s)',x)
    tag=f'{save[:-5]}/{reg}'
    if reg!='home':
      E(f"talk=null;mq.length=0;closeModal();S.region='{reg}';S.gen=Math.max(1,S.gen||0);recalc()")
    E("for(const i in S.lm)if(LMS[S.lm[i].k].key==='station')S.lm[i].ok=true;recalc()")
    def scan(where):
      r=pg.evaluate("""()=>{const vis=e=>{const s=getComputedStyle(e);return s.display!=='none'&&s.visibility!=='hidden'&&e.offsetParent!==null};
        const txt=[...document.querySelectorAll('#app *,#modal *')].filter(e=>e.childNodes.length&&[...e.childNodes].some(n=>n.nodeType===3&&n.textContent.trim())&&vis(e)).map(e=>[...e.childNodes].filter(n=>n.nodeType===3).map(n=>n.textContent).join(''));
        const over=document.documentElement.scrollWidth>innerWidth+1;
        const wide=[...document.querySelectorAll('#sheet.open #shBody *, #modal:not([hidden]) .page *')].filter(e=>{if(e.closest('svg'))return false;const r=e.getBoundingClientRect();if(!(r.width>0&&r.right>innerWidth+2&&getComputedStyle(e).position!=='fixed'))return false;for(let a=e.parentElement;a;a=a.parentElement){const cs=getComputedStyle(a);if(/hidden|auto|scroll|clip/.test(cs.overflowX)&&a.getBoundingClientRect().right<=innerWidth+2)return false;}return true}).slice(0,3).map(e=>(e.className||e.tagName)+':'+Math.round(e.getBoundingClientRect().right));
        const imgs=[...document.querySelectorAll('img')].filter(i=>vis(i)&&i.complete&&i.naturalWidth===0&&i.src).map(i=>i.src.split('/').pop()).slice(0,3);
        return {txt,over,wide,imgs}}""")
      for t in r['txt']:
        if BAD.search(t):note(f'{tag} {where}','글자: '+t.strip())
      if r['over']:note(f'{tag} {where}','페이지 가로 넘침')
      if r['wide']:note(f'{tag} {where}','칸 넘침: '+', '.join(r['wide']))
      if r['imgs']:note(f'{tag} {where}','그림 안 뜸: '+', '.join(r['imgs']))
      while errs:note(f'{tag} {where}',errs.pop(0))
    clr="talk=null;mq.length=0;closeModal();closeRing&&closeRing()"
    E(clr);pg.wait_for_timeout(300);scan('main')
    sheets=['surv','gear','party','exp','shelter','radio','diary','pets','profile','settings','assign']
    for sh in sheets:
      try:E(clr+f";openSheet('{sh}')");pg.wait_for_timeout(250);scan('sheet:'+sh)
      except Exception as ex:note(f'{tag} sheet:{sh}','예외 '+str(ex)[:150])
      if sh=='shelter':
        for seg in ['build','craft','research','store','deco']:
          try:E(f"shTab='{seg}';renderSheet()");pg.wait_for_timeout(150);scan('shelter:'+seg)
          except Exception as ex:note(f'{tag} shelter:{seg}','예외 '+str(ex)[:150])
      if sh=='diary':
        for dt in ['story','scene','case','towns','relic','ach','guide']:
          try:E(f"diaryTab='{dt}';renderSheet()");pg.wait_for_timeout(150);scan('diary:'+dt)
          except Exception as ex:note(f'{tag} diary:{dt}','예외 '+str(ex)[:150])
      if sh=='profile':
        try:E("pfTab='edit';renderSheet()");pg.wait_for_timeout(150);scan('profile:edit');E("pfTab='me'")
        except Exception as ex:note(f'{tag} profile:edit','예외 '+str(ex)[:150])
    E("closeSheet()")
    # 모달들
    ids=E("Object.keys(S.sv).map(Number).slice(0,40)")
    for id in ids:
      try:E(clr+f";openSurv({id},true)");pg.wait_for_timeout(120);scan(f'surv#{id}')
      except Exception as ex:note(f'{tag} surv#{id}','예외 '+str(ex)[:150])
    pets=E("Object.keys(pets())")
    for k in pets:
      try:E(clr+f";openPet('{k}')");pg.wait_for_timeout(120);scan(f'pet:{k}')
      except Exception as ex:note(f'{tag} pet:{k}','예외 '+str(ex)[:150])
    for name,code in [('migrate','openMigrate()'),('ugprep','openUGPrep()'),('lnprep','lnPrep.team=[];openLnPrep()'),('controls','openControls&&openControls()'),('town0','openTown(0)')]:
      try:E(clr+';'+code);pg.wait_for_timeout(200);scan('modal:'+name)
      except Exception as ex:note(f'{tag} modal:{name}','예외 '+str(ex)[:150])
    # 노선 한 판 (카드/싸움/역)
    try:
      E(clr+";lnPrep.team=lnFree().slice(0,2);openLnPrep();lnStart()");pg.wait_for_timeout(200);scan('line:pick')
      E("lnPick(LN.cards.findIndex(c=>c.c==='foe')>=0?LN.cards.findIndex(c=>c.c==='foe'):0)");pg.wait_for_timeout(300);scan('line:after1')
      E("LN&&(LN.step=8,LN.phase='pick',lnDeal(),lnRender())");E("LN&&lnNext()");pg.wait_for_timeout(400);scan('line:boss')
      E("LN&&lnEnd(true)");pg.wait_for_timeout(300);scan('line:end')
    except Exception as ex:note(f'{tag} line','예외 '+str(ex)[:150])
    # 링 메뉴: 여러 칸
    try:
      tiles=E("(()=>{const out=[];const seen=new Set();for(let i=0;i<N;i++){if(!S.rev[i])continue;const k=S.lm[i]?'lm':modAtTile(i)?'mod':S.site[i]?'site':S.camp&&S.camp[i]?'camp':null;if(k&&!seen.has(k+(S.lm[i]?S.lm[i].k:''))){seen.add(k+(S.lm[i]?S.lm[i].k:''));out.push(i);}}return out.slice(0,12)})()")
      for i in tiles:
        E(clr+f";openRing({i})");pg.wait_for_timeout(120);scan(f'ring@{i}')
      E("closeRing()")
    except Exception as ex:note(f'{tag} ring','예외 '+str(ex)[:150])
    c.close()
  print('ISSUES',len(issues))
  json.dump(issues,open(f'qa_issues_{W}.json','w'),ensure_ascii=False,indent=0)
finally: srv.kill()
