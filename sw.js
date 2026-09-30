const CACHE='taptocity-people-20261001';
const SHELL=['./','./index.html','./people.js?v=20261001-people','./manifest.webmanifest','./cloud.js','./cloud-config.js','./fonts/ttc-sans.woff2','./icons/icon-192.png','./icons/icon-512.png','./design.css?v=20261001','./design.js?v=20261002-landmarks','./assets/illustrated/survivors-signals.webp','./assets/illustrated/survivors-neighbors.webp','./assets/illustrated/shelters.webp','./assets/illustrated/survivors-founders.webp','./assets/illustrated/modules.webp','./assets/illustrated/survivors-scouts.webp','./assets/illustrated/survivors-frontier.webp','./assets/illustrated/radio.webp','./assets/illustrated/exploration-sites.webp','./assets/illustrated/landmarks.webp'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL)).then(()=>self.skipWaiting()));});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));});
self.addEventListener('fetch',e=>{const r=e.request;if(r.method!=='GET')return;
 const u=new URL(r.url);
 if(u.origin===location.origin&&(r.mode==='navigate'||u.pathname.endsWith('/')||u.pathname.endsWith('index.html'))){
  e.respondWith(fetch(r).then(res=>{const c=res.clone();caches.open(CACHE).then(x=>x.put('./index.html','./people.js?v=20261001-people',c));return res;}).catch(()=>caches.match('./index.html')));return;}
 e.respondWith(caches.match(r).then(hit=>hit||fetch(r).then(res=>{if(res.ok||res.type==='opaque'){const c=res.clone();caches.open(CACHE).then(x=>x.put(r,c));}return res;}).catch(()=>hit)));});
