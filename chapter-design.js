/* Chapter presentation: no progress, resource, damage or save mutations. */
(function(){
'use strict';
const base='assets/illustrated/',images={},esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
for(const f of ['regional-npcs.webp','module-upgrades.webp','ash-foes.webp','world-scenes.webp']){const i=new Image();i.decoding='async';i.src=base+f;images[f]=i;}
const ready=f=>!!(images[f].complete&&images[f].naturalWidth);
function npc(k,name){const n={desert:0,factory:1,snow:2}[k];if(n==null)return'';return`<svg class="illustrated-portrait" viewBox="${n*686+6} 6 674 750" role="img" aria-label="${esc(name)} 초상화" preserveAspectRatio="xMidYMin slice"><image href="${base}regional-npcs.webp" width="2058" height="764"/></svg>`;}
const mf=[[12,85,272,239],[301,32,286,287],[606,79,277,242],[895,40,278,284],[1193,75,265,236],[1476,35,285,283],[30,330,253,252],[305,324,284,258],[606,347,257,235],[887,337,334,260],[1273,339,145,231],[1546,322,163,248],[14,597,271,259],[297,597,293,268],[596,604,282,246],[886,597,329,266],[1218,590,242,267],[1474,590,293,272]],order=[1,2,9,3,4,8,5,6,7];
function moduleMetric(id,l){const n=order.indexOf(id);if(n<0||l<1||!ready('module-upgrades.webp'))return null;const f=mf[n*2+Math.min(1,l-1)],w=id===8?40+l*4:id===7?78+l*3:76+l*3;return{f,w,h:w*f[3]/f[2]};}
function module(g,P,id,l,scale=1){const a=moduleMetric(id,l);if(!a)return false;const[x,y]=P(.5,.5,0),h=a.h*scale;g.drawImage(images['module-upgrades.webp'],...a.f,x-a.w/2,y+8-h,a.w,h);return true;}
function moduleHeight(id,l){const a=moduleMetric(id,l);return a?Math.max(10,a.h-16):0;}
const cache=new Map();
function moduleThumb(id,l){const a=moduleMetric(id,l);if(!a)return null;const key=id+':'+l;if(cache.has(key))return cache.get(key);const c=document.createElement('canvas');c.width=c.height=144;const g=c.getContext('2d'),s=132/Math.max(a.f[2],a.f[3]),w=a.f[2]*s,h=a.f[3]*s;g.drawImage(images['module-upgrades.webp'],...a.f,(144-w)/2,(144-h)/2,w,h);const url=c.toDataURL();cache.set(key,url);return url;}
const scenes={mall:0,road:1,apt:2,plant:3,metro:4,sewer:5,bunker:6,control:7,shelter:8};
function scene(k,cls='',label=''){const n=scenes[k];if(n==null)return'';return`<svg class="scene-art ${cls}" viewBox="${n%3*418} ${Math.floor(n/3)*418} 418 418" preserveAspectRatio="xMidYMid slice" ${label?`role="img" aria-label="${esc(label)}"`:'aria-hidden="true"'}><image href="${base}world-scenes.webp" width="1254" height="1254"/></svg>`;}
const ff=[[121,52,465,539],[648,66,572,524],[33,635,575,573],[647,655,573,561]];
function foe(g,f,t,centerX,reduced){if(!ready('ash-foes.webp'))return false;const attack=f.hit>0,idx=(f.brute?2:0)+(attack?1:0),a=ff[idx],h=f.brute?49:35,w=h*a[2]/a[3],bob=reduced?0:Math.sin(t/230+f.ph)*1.1;
 g.save();g.translate(f.x,f.y+bob);const facing=idx===3?1:-1;g.scale((centerX>=f.x?1:-1)*facing,1);g.drawImage(images['ash-foes.webp'],...a,-w/2,-h,w,h);g.restore();
 if(attack){g.save();g.strokeStyle='rgba(255,224,161,'+Math.min(.9,f.hit)+')';g.lineWidth=1.6;g.beginPath();g.ellipse(f.x,f.y-h*.45,w*.34,h*.27,0,0,7);g.stroke();g.restore();}return true;
}
window.TTCFinal={npc,module,moduleHeight,moduleThumb,scene,foe,ready,version:'chapters-20261001'};
})();
