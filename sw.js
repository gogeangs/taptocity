const CACHE='taptocity-story-20261017a-lines';
// 그림은 버전과 상관없이 따로 오래 보관하는 캐시에 둔다(배포마다 다시 받지 않게). 쓸 때마다 서버에 바뀌었는지 묻고(304면 보관본), 늦거나 오프라인이면 보관본을 쓴다.
const IMG='taptocity-img';
const SHELL=['./','./index.html','./chapter-design.js?v=20261014-lsf','./settlement.js?v=20261011-lazy','./people.js?v=20261013-walkers4','./manifest.webmanifest','./cloud.js?v=20261016-cloudrow','./cloud-config.js','./fonts/ttc-sans.woff2','./icons/icon-192.png?v=2','./icons/icon-512.png?v=2','./design.css?v=20261004-anonymous','./qa.css?v=20261016-cloudrow','./story-art.js?v=20261017-fallback','./music.js?v=20261011-cool','./design.js?v=20261014-lsf'];
// 첫 화면에 바로 필요한 그림만 미리 받는다. 나머지는 게임에서 처음 쓸 때 받는다.
const CORE=['./assets/illustrated/resources.webp','./assets/illustrated/survivors-silhouettes.webp?v=3','./assets/illustrated/story-1.webp?v=1','./assets/illustrated/shelters.webp','./assets/illustrated/modules.webp','./assets/illustrated/player-faceless.webp'];

self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL)).then(()=>caches.open(IMG)).then(c=>Promise.all(CORE.map(u=>c.match(u).then(h=>h||c.add(u).catch(()=>{}))))).then(()=>self.skipWaiting()));});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k.startsWith('taptocity-')&&k!==CACHE&&k!==IMG).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));});
self.addEventListener('fetch',e=>{const r=e.request;if(r.method!=='GET')return;
 const u=new URL(r.url);
 if(u.origin!==location.origin)return;
 // 네이티브 미리보기(native-play/)는 이 게임과 별개 — 가로채지도, 저장하지도 않는다
 if(u.pathname.includes('/native-play/'))return;
 if(u.origin===location.origin&&(r.mode==='navigate'||u.pathname.endsWith('/')||u.pathname.endsWith('index.html'))){
  e.respondWith(fetch(r.url,{cache:'no-cache',credentials:'same-origin'}).then(res=>{if(!res.ok)throw new Error('Navigation unavailable');const c=res.clone();e.waitUntil(caches.open(CACHE).then(x=>x.put('./index.html',c)));return res;}).catch(()=>caches.match('./index.html')));return;}
 // 그림: 먼저 서버에 '바뀌었나'만 묻는다(안 바뀌었으면 304로 아주 짧게 끝남). 같은 이름으로 그림을 바꿔도 예전 그림이 한 번 더 보이지 않게.
 // 응답이 1.5초 넘게 늦거나 오프라인이면 보관해 둔 그림을 쓴다.
 if(u.pathname.includes('/assets/')){e.respondWith(caches.open(IMG).then(c=>c.match(r).then(hit=>{const net=fetch(r,{cache:'no-cache'}).then(res=>{if(res.ok){e.waitUntil(c.put(r,res.clone()));}return res;});
   if(!hit)return net.catch(()=>caches.match(r));
   e.waitUntil(net.catch(()=>{}));
   return Promise.race([net.then(res=>res.ok?res:hit).catch(()=>hit),new Promise(ok=>setTimeout(()=>ok(hit),1500))]);})));return;}
 e.respondWith(caches.match(r).then(hit=>hit||fetch(r).then(res=>{if(res.ok||res.type==='opaque'){const c=res.clone();e.waitUntil(caches.open(CACHE).then(x=>x.put(r,c)));}return res;}).catch(()=>hit)));});

