// Build a file:// runnable integration test using the actual game closure and DOM.
// Usage: node tests/make-city-browser-test.cjs <output.html> <relative-asset-base>
const fs=require('node:fs'),path=require('node:path');
const out=process.argv[2];if(!out)throw Error('Output HTML path required');
let html=fs.readFileSync(path.join(__dirname,'../index.html'),'utf8');
const marker="if(window.claude&&window.claude.hot&&window.claude.hot.ready)window.claude.hot.ready(start);else start(window.claude&&window.claude.hot&&window.claude.hot.data||{});";
if(!html.includes(marker))throw Error('Game bootstrap changed');
const suite=String.raw`
const results=[];const check=(v,msg)=>{if(!v)throw Error(msg||'Assertion failed');};
const test=(name,fn)=>{try{fn();results.push('PASS '+name);}catch(e){results.push('FAIL '+name+': '+e.message);}};
fresh();S.m.wood=S.m.scrap=200;S.mi=0;recalc();
const initial=JSON.stringify(S);const oldSaved=localStorage.getItem(KEY);
const click=id=>document.getElementById(id).click();
test('shelter opens integrated persistent city',()=>{openSheet('shelter');shTab='build';renderSheet();document.querySelector('[data-act="cityopen"]').click();check(document.getElementById('cityDialog').open);check(S.city.regions['0,0'].revealed.length===625);});
const choose=(x,y)=>{const cv=document.getElementById('cityCanvas'),r=cv.getBoundingClientRect(),z=parseFloat(cv.style.width)/25;const opts={clientX:r.left+(x+.5)*z,clientY:r.top+(y+.5)*z,pointerId:1,pointerType:'touch',bubbles:true};cv.dispatchEvent(new PointerEvent('pointerdown',opts));cv.dispatchEvent(new PointerEvent('pointerup',opts));};
test('preview cancel does not spend resources',()=>{document.querySelector('[data-type="home"]').click();choose(10,10);check(!document.getElementById('cityConfirm').disabled);click('cityCancel');check(S.m.wood===200&&S.city.buildings.length===0);});
test('actual build UI saves resources and updates beds',()=>{document.querySelector('[data-type="home"]').click();choose(10,10);click('cityConfirm');check(S.city.buildings.length===1);check(S.m.wood===180&&S.m.scrap===190);check(bedsMax()===BEDS[S.lv-1]+2);check(JSON.parse(localStorage.getItem(KEY)).city.buildings.length===1);});
test('collision preview disables confirm',()=>{document.querySelector('[data-type="home"]').click();choose(10,10);check(document.getElementById('cityConfirm').disabled);click('cityCancel');});
test('move and rotate UI retains identity and resource balance',()=>{choose(10,10);[...document.querySelectorAll('#citySelection button')].find(b=>b.textContent==='이동').click();click('cityRotate');choose(13,13);click('cityConfirm');check(S.city.buildings[0].id===1&&S.city.buildings[0].x===13&&S.city.buildings[0].rot===1);check(S.m.wood===180);});
test('exploration UI clears a frontier permanently',()=>{click('cityExplore');choose(15,12);choose(15,12);check(S.city.regions['0,0'].revealed[315]===1);check(S.city.opened===26);});
test('close and reopen restores map controls',()=>{document.getElementById('cityDialog').close();});
// close event is queued by the browser; continue in another turn.
setTimeout(()=>{
test('reopen has no stale selected building or draft',()=>{cityView.open();check(document.getElementById('cityDialog').open);check(document.getElementById('cityConfirm').hidden);check(document.getElementById('cityInspect').getAttribute('aria-pressed')==='true');});
test('save load roundtrip retains city and survivors',()=>{const saved=JSON.parse(localStorage.getItem(KEY)),city=JSON.stringify(saved.city);check(load(saved));recalc();check(JSON.stringify(S.city)===city);check(validImport(S));});
test('import rejects malformed city',()=>{const bad=JSON.parse(JSON.stringify(S));bad.city.buildings[0].x=25;check(!validImport(bad));});
test('legacy import still accepted',()=>{const old=JSON.parse(initial);delete old.city;check(validImport(old));});
test('old town migration explicitly retains the same city',()=>{const before=S.city;const savedFn=openTalk;openTalk=()=>{};try{S.tlog=[];S.lv=5;S.tower=5;migrate();check(S.city===before);check(TTCCity.validate(S.city));}finally{openTalk=savedFn;}});
const dialog=document.getElementById('cityDialog');if(dialog)dialog.close();
if(oldSaved===null)localStorage.removeItem(KEY);else localStorage.setItem(KEY,oldSaved);
const report=document.createElement('pre');report.id='cityTestReport';report.style='position:fixed;inset:0;z-index:2147483647;background:#17212b;color:#fff;padding:24px;margin:0;overflow:auto;font:16px/1.8 monospace;white-space:pre-wrap';report.textContent='CITY BROWSER TESTS\n'+results.join('\n')+'\n'+results.filter(x=>x.startsWith('PASS')).length+'/'+results.length+' passed';document.body.appendChild(report);document.title=results.some(x=>x.startsWith('FAIL'))?'CITY TEST FAILED':'CITY TEST PASSED';
},50);
`;
html=html.replace(marker,suite).replace('<head>','<head>\n<base href="'+(process.argv[3]||'../')+'">');
html=html.replace(/<script\b[^>]*src="cloud(?:-config)?\.js[^\"]*"[^>]*><\/script>/g,'').replace(/<script>([\s\S]*?)<\/script>/g,(tag,body)=>body.includes('ttc_cloud_pending')||body.includes("if('serviceWorker' in navigator)")?'':tag);
fs.mkdirSync(path.dirname(path.resolve(out)),{recursive:true});fs.writeFileSync(out,html);console.log(out);
