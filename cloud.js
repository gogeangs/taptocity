// 탭투시티 클라우드 저장 — Firebase(익명 로그인 → 구글 계정 연결) + Firestore
// 게임은 localStorage에 저장하고, 이 모듈이 그 저장본을 계정별 문서(saves/{uid})와 주고받아요.
const KEY='taptocity-shelter-v1',PEND='ttc_cloud_pending',V='10.12.2';
const CFG=window.TTC_FIREBASE;
const $=id=>document.getElementById(id);
const st={user:null,last:null,msg:'',busy:false,ok:!!CFG};
window.ttcCloud=st;
const sum=s=>{try{const o=JSON.parse(s);return{t:o.t||0,lv:o.lv||1,gen:o.gen||0,play:o.playT||0,name:(o.pf&&o.pf.name)||''};}catch(e){return{t:0,lv:1,gen:0,play:0,name:''};}};
const when=t=>{if(!t)return'';const d=new Date(t);return`${d.getMonth()+1}/${d.getDate()} ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`;};
function ui(){const box=$('ttcCloud');if(!box)return;const u=st.user;
  let h='';
  if(!st.ok)h=`<div class="d">클라우드 저장을 준비하고 있어요.</div>`;
  else if(!u)h=`<div class="d">연결하는 중…</div>`;
  else{const g=!u.isAnonymous,em=g&&(u.email||u.displayName)||'';
    h=`<div class="row setrow"><div><div class="t">${g?'구글 계정에 저장 중':'이 기기로 자동 저장 중'}</div><div class="d">${g?`${em} · 다른 기기에서 같은 계정으로 로그인하면 이어서 할 수 있어요`:'구글 계정을 연결하면 휴대폰을 바꿔도 진행이 이어져요'}${st.last?`<br>마지막 저장 ${when(st.last)}`:''}${st.msg?`<br><b>${st.msg}</b>`:''}</div></div></div>
      <div class="btns" style="gap:8px">${g?`<button class="buy ghost" data-cloud="now">지금 저장</button><button class="buy ghost" data-cloud="out">로그아웃</button>`:`<button class="buy" data-cloud="google">구글 계정 연결</button><button class="buy ghost" data-cloud="now">지금 저장</button>`}</div>`;}
  box.innerHTML=h;}
function inject(){const t=$('shTitle'),b=$('shBody');if(!t||!b||t.textContent!=='설정'||$('ttcCloud'))return;
  const s=document.createElement('div');s.innerHTML='<div class="sec">클라우드 저장</div><div id="ttcCloud"></div>';const first=b.querySelector('.sec');
  if(first)b.insertBefore(s,first);else b.appendChild(s);ui();}
new MutationObserver(inject).observe(document.documentElement,{childList:true,subtree:true});
function ask(title,body,yes,no){return new Promise(res=>{const d=document.createElement('div');d.id='ttcAsk';
  d.innerHTML=`<div class="bx"><b>${title}</b><p>${body}</p><div class="bt"><button class="n">${no}</button><button class="y">${yes}</button></div></div>`;
  document.body.appendChild(d);d.querySelector('.y').onclick=()=>{d.remove();res(true);};d.querySelector('.n').onclick=()=>{d.remove();res(false);};});}
const css=document.createElement('style');css.textContent=`#ttcAsk{position:fixed;inset:0;z-index:400;background:rgba(10,8,5,.7);display:grid;place-items:center;padding:16px}#ttcAsk .bx{background:#efe3c4;color:#3b2a1a;border-radius:16px;max-width:340px;width:100%;padding:18px 16px 14px;font:14.5px/1.55 "Gowun Dodum",system-ui,sans-serif;box-shadow:0 12px 30px rgba(0,0,0,.6)}#ttcAsk b{font:700 17px "Gowun Batang",serif}#ttcAsk p{margin:8px 0 14px}#ttcAsk .bt{display:flex;gap:8px}#ttcAsk button{flex:1;border:0;border-radius:99px;padding:11px 8px;font:700 14px "Gowun Dodum",sans-serif}#ttcAsk .y{background:#3b2a1a;color:#efe3c4}#ttcAsk .n{background:transparent;border:1.5px solid rgba(59,42,26,.35);color:#3b2a1a}`;
document.head.appendChild(css);
if(CFG){
  const [{initializeApp},A,F]=await Promise.all([import(`https://www.gstatic.com/firebasejs/${V}/firebase-app.js`),import(`https://www.gstatic.com/firebasejs/${V}/firebase-auth.js`),import(`https://www.gstatic.com/firebasejs/${V}/firebase-firestore.js`)]);
  const app=initializeApp(CFG),auth=A.getAuth(app),db=F.getFirestore(app),prov=new A.GoogleAuthProvider();prov.setCustomParameters({prompt:'select_account'});
  const ref=()=>F.doc(db,'saves',st.user.uid);
  let lastData=null;
  async function up(force){if(!st.user||st.busy)return;const data=localStorage.getItem(KEY);if(!data||(!force&&data===lastData))return;
    try{const s=sum(data);await F.setDoc(ref(),{data,t:s.t||Date.now(),lv:s.lv,gen:s.gen,play:s.play,name:s.name,at:Date.now()});lastData=data;st.last=Date.now();st.msg='';}catch(e){st.msg='저장하지 못했어요. 인터넷 연결을 확인해 주세요';}ui();}
  async function sync(){if(!st.user)return;st.busy=true;try{const snap=await F.getDoc(ref());const local=localStorage.getItem(KEY),ls=sum(local||'{}');
      if(snap.exists()){const c=snap.data();st.last=c.at||c.t;
        if(c.data&&c.data!==local&&(c.t||0)>(ls.t||0)+3000){
          const yes=await ask('클라우드에 더 최근 진행이 있어요',`클라우드: Lv.${c.lv}${c.gen?` · ${c.gen+1}번째 동네`:''} · ${when(c.t)} 저장<br>이 기기: Lv.${ls.lv}${ls.gen?` · ${ls.gen+1}번째 동네`:''} · ${when(ls.t)} 저장<br><br>클라우드 진행을 불러올까요?`,'불러오기','이 기기 진행 유지');
          if(yes){localStorage.setItem(PEND,c.data);location.reload();return;}}}
    }catch(e){st.msg='클라우드에 연결하지 못했어요';}st.busy=false;ui();up(true);}
  A.onAuthStateChanged(auth,u=>{st.user=u;ui();if(u)sync();else A.signInAnonymously(auth).catch(()=>{st.msg='클라우드에 연결하지 못했어요';ui();});});
  A.getRedirectResult(auth).catch(async e=>{if(e&&e.code==='auth/credential-already-in-use'){const cr=A.GoogleAuthProvider.credentialFromError(e);if(cr)await A.signInWithCredential(auth,cr);}});
  setInterval(()=>up(false),45000);
  document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='hidden')up(false);});
  document.addEventListener('click',async e=>{const b=e.target.closest('[data-cloud]');if(!b)return;e.stopPropagation();const a=b.dataset.cloud;
    if(a==='now'){await up(true);if(!st.msg)st.msg='저장했어요';ui();}
    else if(a==='out'){if(await ask('로그아웃할까요?','이 기기의 진행은 그대로 남아요. 다시 구글로 로그인하면 클라우드 진행을 불러올 수 있어요.','로그아웃','취소')){await A.signOut(auth);}}
    else if(a==='google'){const cur=auth.currentUser;
      try{if(cur&&cur.isAnonymous)await A.linkWithPopup(cur,prov);else await A.signInWithPopup(auth,prov);st.user=auth.currentUser;st.msg='구글 계정에 연결했어요';ui();sync();}
      catch(e){const c=e&&e.code||'';
        if(c==='auth/credential-already-in-use'||c==='auth/email-already-in-use'){const cr=A.GoogleAuthProvider.credentialFromError(e);if(cr){await A.signInWithCredential(auth,cr);}}
        else if(c==='auth/popup-blocked'||c==='auth/operation-not-supported-in-this-environment'||c==='auth/popup-closed-by-user'&&/iphone|ipad/i.test(navigator.userAgent)){try{if(cur&&cur.isAnonymous)await A.linkWithRedirect(cur,prov);else await A.signInWithRedirect(auth,prov);}catch(e2){st.msg='로그인 창을 열지 못했어요';ui();}}
        else if(c!=='auth/popup-closed-by-user'&&c!=='auth/cancelled-popup-request'){st.msg='연결하지 못했어요 ('+c+')';ui();}}}},true);
}else ui();
