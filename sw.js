const CACHE='taptocity-story-20261011q-batt';
// 그림은 버전과 상관없이 따로 오래 보관하는 캐시에 둔다(배포마다 다시 받지 않게). 처음 쓸 때 받아 두고, 다음에 열 때 조용히 새것인지 확인한다.
const IMG='taptocity-img';
const SHELL=['./','./index.html','./chapter-design.js?v=20261011-lazy','./settlement.js?v=20261011-lazy','./people.js?v=20261001-people','./manifest.webmanifest','./cloud.js?v=20261011-fb','./cloud-config.js','./fonts/ttc-sans.woff2','./icons/icon-192.png?v=2','./icons/icon-512.png?v=2','./design.css?v=20261004-anonymous','./qa.css?v=20261011-ux','./story-art.js?v=20261011-lazy','./music.js?v=20261011-cool','./design.js?v=20261011-lazy'];
// 첫 화면에 바로 필요한 그림만 미리 받는다. 나머지는 게임에서 처음 쓸 때 받는다.
const CORE=['./assets/illustrated/resources.webp','./assets/illustrated/survivors-silhouettes.webp?v=3','./assets/illustrated/story-1.webp?v=1','./assets/illustrated/shelters.webp','./assets/illustrated/modules.webp','./assets/illustrated/player-faceless.webp'];

self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL)).then(()=>caches.open(IMG)).then(c=>Promise.all(CORE.map(u=>c.match(u).then(h=>h||c.add(u).catch(()=>{}))))).then(()=>self.skipWaiting()));});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k.startsWith('taptocity-')&&k!==CACHE&&k!==IMG).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));});
self.addEventListener('fetch',e=>{const r=e.request;if(r.method!=='GET')return;
 const u=new URL(r.url);
 if(u.origin!==location.origin)return;
 if(u.origin===location.origin&&(r.mode==='navigate'||u.pathname.endsWith('/')||u.pathname.endsWith('index.html'))){
  e.respondWith(fetch(r.url,{cache:'no-cache',credentials:'same-origin'}).then(res=>{if(!res.ok)throw new Error('Navigation unavailable');const c=res.clone();e.waitUntil(caches.open(CACHE).then(x=>x.put('./index.html',c)));return res;}).catch(()=>caches.match('./index.html')));return;}
 if(u.pathname.includes('/assets/')){e.respondWith(caches.open(IMG).then(c=>c.match(r).then(hit=>{const net=fetch(r,{cache:'no-cache'}).then(res=>{if(res.ok){e.waitUntil(c.put(r,res.clone()));}return res;});
   if(hit){e.waitUntil(net.catch(()=>{}));return hit;}return net.catch(()=>caches.match(r));})));return;}
 e.respondWith(caches.match(r).then(hit=>hit||fetch(r).then(res=>{if(res.ok||res.type==='opaque'){const c=res.clone();e.waitUntil(caches.open(CACHE).then(x=>x.put(r,c)));}return res;}).catch(()=>hit)));});

