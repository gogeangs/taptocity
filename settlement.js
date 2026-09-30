/* Illustrated map props and companions; state and interaction stay in the game. */
(function(){
'use strict';
const base='assets/illustrated/',images={};
for(const f of ['settlement-props.webp','companions.webp']){const i=new Image();i.decoding='async';i.src=base+f;images[f]=i;}
const ready=f=>!!(images[f].complete&&images[f].naturalWidth);
const frames=[[14,46,337,276],[376,60,331,254],[726,114,319,203],[1081,168,263,145],[37,352,287,209],[355,335,358,243],[734,350,306,231],[1087,403,273,163],[68,598,214,241],[445,590,225,277],[728,637,282,225],[1179,586,118,279],[87,863,170,255],[380,870,309,232],[718,882,347,231],[1139,882,188,239]];
const widths=[53,58,49,44,45,57,51,44,16,24,36,15,16,44,45,21];
const deco={pot:8,flag:9,bench:10,lamp:11,chime:12,string:13,mural:14,statue:15};
function metric(id){if(!ready('settlement-props.webp')||!frames[id])return null;const f=frames[id],w=widths[id];return{f,w,h:w*f[3]/f[2]};}
function prop(g,P,id,scale=1,width){const a=metric(id);if(!a)return false;const[x,y]=P(.5,.5,0),w=width||a.w,h=w*a.f[3]/a.f[2]*scale;g.drawImage(images['settlement-props.webp'],...a.f,x-w/2,y+5-h,w,h);return true;}
function height(id){const a=metric(id);return a?Math.max(0,a.h-13):0;}
const thumbs=new Map();
function thumb(k){const id=deco[k],a=metric(id);if(!a)return'';if(thumbs.has(k))return thumbs.get(k);const c=document.createElement('canvas');c.width=c.height=112;const g=c.getContext('2d'),s=94/Math.max(a.f[2],a.f[3]),w=a.f[2]*s,h=a.f[3]*s;g.drawImage(images['settlement-props.webp'],...a.f,(112-w)/2,(112-h)/2,w,h);const url=c.toDataURL();thumbs.set(k,url);return url;}
const keys=['dog','cat','crow','goat','hog','fox','turtle','owl','fennec','bot','bear'];
const petFrames=[[16,44,353,329],[408,37,302,332],[735,112,340,258],[1115,15,321,355],[29,493,290,212],[350,386,366,325],[723,476,385,239],[1144,383,269,340],[15,728,365,325],[378,726,348,341],[747,769,332,285]];
// Neck-band endpoints in each animal's local image coordinates; not baked into art.
const collars=[[.66,.40,.77,.50],[.72,.43,.86,.5],[.66,.4,.79,.47],[.65,.40,.82,.45],[.67,.65,.75,.86],[.66,.47,.83,.52],[.79,.54,.83,.67],[.39,.57,.67,.57],[.63,.49,.82,.54],[.66,.42,.79,.50],[.68,.53,.87,.54]];
function petMetric(k){const n=keys.indexOf(k);if(n<0||!ready('companions.webp'))return null;const f=petFrames[n],size=k==='hog'||k==='turtle'?18:k==='goat'?25:23,w=Math.min(size,size*f[2]/f[3]);return{n,f,w,h:w*f[3]/f[2]};}
function pet(g,k,t,moving,col,night,reduced){const a=petMetric(k);if(!a)return false;const{n,f,w,h}=a;
 const phase=t/(k==='turtle'?300:120),bob=moving&&!reduced?Math.abs(Math.sin(phase))*(k==='crow'||k==='owl'?1.8:.75):0;
 g.save();g.translate(0,-bob);if(moving&&!reduced)g.rotate(Math.sin(phase)*.035);
 if(k==='fox'&&night){const r=g.createRadialGradient(0,-h/2,1,0,-h/2,17);r.addColorStop(0,'rgba(208,224,248,.3)');r.addColorStop(1,'rgba(208,224,248,0)');g.fillStyle=r;g.fillRect(-17,-h-8,34,h+16);}
 g.drawImage(images['companions.webp'],...f,-w/2,-h,w,h);
 const c=collars[n];g.strokeStyle=col;g.lineWidth=1.1;g.lineCap='round';g.beginPath();g.moveTo((c[0]-.5)*w,(c[1]-1)*h);g.lineTo((c[2]-.5)*w,(c[3]-1)*h);g.stroke();
 g.restore();return true;
}
window.TTCSettlement={prop,height,deco,thumb,pet,petMetric,ready,version:'props-pets-20261001'};
})();
