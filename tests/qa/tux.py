import subprocess,time,json,os,sys
from playwright.sync_api import sync_playwright
os.chdir(os.path.dirname(os.path.abspath(__file__)))
W=int(sys.argv[1]) if len(sys.argv)>1 else 360;H=int(sys.argv[2]) if len(sys.argv)>2 else 740
srv=subprocess.Popen(['python3','-m','http.server','8815','-d','dist'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(1)
MEAS="""()=>{const vis=e=>{const s=getComputedStyle(e);const r=e.getBoundingClientRect();return s.display!=='none'&&s.visibility!=='hidden'&&+s.opacity>0.05&&r.width>0&&r.height>0&&r.bottom>0&&r.top<innerHeight&&r.right>0&&r.left<innerWidth};
 const nm=e=>(e.id?'#'+e.id:'')+(typeof e.className==='string'&&e.className?'.'+e.className.trim().split(/\\s+/).slice(0,2).join('.'):'')||e.tagName;
 const lab=e=>(e.getAttribute('aria-label')||e.textContent||'').trim().slice(0,16);
 const small=[...document.querySelectorAll('button,[data-act],a,input,select,.tab,[role=button]')].filter(vis).filter(e=>{const r=e.getBoundingClientRect();return r.width<32||r.height<32}).map(e=>{const r=e.getBoundingClientRect();return nm(e)+' '+Math.round(r.width)+'x'+Math.round(r.height)+' '+lab(e)});
 const lum=c=>{const m=c.match(/[\\d.]+/g);if(!m)return null;const[a,b,d]=m.slice(0,3).map(x=>{x/=255;return x<=.03928?x/12.92:Math.pow((x+.055)/1.055,2.4)});return{L:.2126*a+.7152*b+.0722*d,al:m[3]==null?1:+m[3]}};
 const bgOf=e=>{for(let a=e;a;a=a.parentElement){const c=getComputedStyle(a).backgroundColor;const l=lum(c);if(l&&l.al>.6)return l.L;if(getComputedStyle(a).backgroundImage!=='none')return null;}return null};
 const tiny=[],lowc=[];const seen=new Set();
 for(const e of document.querySelectorAll('body *')){if(!vis(e))continue;if(![...e.childNodes].some(n=>n.nodeType===3&&n.textContent.trim().length>1))continue;const cs=getComputedStyle(e),fs=parseFloat(cs.fontSize);const k=nm(e);
   if(fs<11&&!seen.has('t'+k)){seen.add('t'+k);tiny.push(k+' '+fs+'px '+e.textContent.trim().slice(0,14));}
   const fg=lum(cs.color),bg=bgOf(e);if(fg&&bg!=null){const L1=Math.max(fg.L,bg),L2=Math.min(fg.L,bg),cr=(L1+.05)/(L2+.05)*(fg.al<1?fg.al:1);if(cr<3&&!seen.has('c'+k)){seen.add('c'+k);lowc.push(k+' '+cr.toFixed(1)+' '+e.textContent.trim().slice(0,14));}}}
 return {small:[...new Set(small)].slice(0,12),tiny:tiny.slice(0,12),lowc:lowc.slice(0,12)}}"""
out={}
try:
 with sync_playwright() as p:
  b=p.chromium.launch();c=b.new_context(viewport={'width':W,'height':H},device_scale_factor=2,is_mobile=True,has_touch=True)
  s=json.load(open('mid.json'));s['t']=time.time()*1000;s['pfAsk']=1
  c.add_init_script("localStorage.setItem('taptocity-shelter-v1',%s);localStorage.setItem('ttc_tut','1');"%json.dumps(json.dumps(s)))
  pg=c.new_page();errs=[];pg.on('pageerror',lambda e:errs.append(str(e)));pg.goto('http://localhost:8815/_t.html');pg.wait_for_timeout(3500)
  E=lambda x:pg.evaluate('s=>window.__ev(s)',x)
  clr="talk=null;mq.length=0;closeModal();closeSheet();$('toasts').innerHTML='';NQ.length=0;NCUR=null"
  def shot(name):
    pg.wait_for_timeout(400);pg.screenshot(path=f'ux/{W}_{name}.png');out[name]=pg.evaluate(MEAS)
  E(clr);shot('main')
  E("openRing&&openRing(C0)");shot('ring');E("closeRing()")
  for sh in ['surv','exp','radio','diary','settings','gear']:
    E(clr+f";openSheet('{sh}')");shot(sh)
  for seg in ['build','craft','research','deco']:
    E(clr+f";goShelter('{seg}')");shot('shelter_'+seg)
  E(clr+";openSheet('diary');diaryTab='guide';renderSheet()");shot('diary_guide')
  E(clr+";openSheet('surv')");
  E("const b=document.querySelector('#shBody [data-act=sv],#shBody .svrow,#shBody [data-id]');b&&b.click()");shot('surv_detail')
  json.dump(out,open(f'ux/meas_{W}.json','w'),ensure_ascii=False,indent=1)
  print('ERRS',errs)
finally: srv.kill()
