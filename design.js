/* Approved art direction, shared by canvas and native UI. No gameplay state here. */
(function(){
  'use strict';
  const base='assets/illustrated/';
  const sheets={
    founders:{file:'survivors-founders.webp',w:2058,h:764,cols:4,rows:1},
    neighbors:{file:'survivors-neighbors.webp',w:1161,h:1355,cols:2,rows:2},
    signals:{file:'survivors-signals.webp',w:1161,h:1355,cols:2,rows:2},
    frontier:{file:'survivors-frontier.webp',w:1161,h:1355,cols:2,rows:2},
    scouts:{file:'survivors-scouts.webp',w:1641,h:958,cols:2,rows:1}
  };
  const portraits=[['founders',0],['neighbors',0],['founders',1],['neighbors',1],['neighbors',2],['neighbors',3],['signals',0],['founders',2],['signals',1],['founders',3],['signals',2],['signals',3],['frontier',0],['frontier',1],['frontier',2],['frontier',3],['scouts',0],['scouts',1]];
  const escape=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  function portrait(s){
    const p=s&&portraits[s.id];if(!p)return null;
    const a=sheets[p[0]],w=a.w/a.cols,h=a.h/a.rows,x=p[1]%a.cols*w,y=Math.floor(p[1]/a.cols)*h;
    return '<svg class="illustrated-portrait" viewBox="0 0 120 140" role="img" aria-label="'+escape(s.name)+' 초상화"><svg width="120" height="140" viewBox="'+[x,y,w,h].join(' ')+'" preserveAspectRatio="xMidYMin slice"><image href="'+base+a.file+'" width="'+a.w+'" height="'+a.h+'" preserveAspectRatio="none"/></svg></svg>';
  }
  const images={};
  ['shelters.webp','modules.webp','radio.webp','exploration-sites.webp','landmarks.webp'].forEach(file=>{const img=new Image();img.decoding='async';img.src=base+file;images[file]=img;});
  function crop(file,index,cols,rows){const img=images[file];if(!img||!img.complete||!img.naturalWidth)return null;const w=img.naturalWidth/cols,h=img.naturalHeight/rows;return{img,x:index%cols*w,y:Math.floor(index/cols)*h,w,h};}
  function sprite(ctx,P,file,index,cols,rows,width,anchor=.9){const a=crop(file,index,cols,rows);if(!a)return false;const[x,y]=P(.5,.5,0),height=width*a.h/a.w;ctx.drawImage(a.img,a.x,a.y,a.w,a.h,x-width/2,y-height*anchor,width,height);return true;}
  function core(ctx,P,level){return sprite(ctx,P,'shelters.webp',Math.max(0,Math.min(4,level-1)),3,2,level===5?112:level===4?100:level===3?90:84,.91);}
  function module(ctx,P,id,level){const order=[1,2,9,3,4,8,5,6,7],index=order.indexOf(id);if(index<0)return false;return sprite(ctx,P,'modules.webp',index,3,3,(id===8||id===7?94:78)+level*3,.9);}
  // the drawn height of a module (for tap hit-testing), from the same cell and width the sprite uses
  function moduleHeight(id,level){const order=[1,2,9,3,4,8,5,6,7],index=order.indexOf(id);if(index<0)return 0;const a=crop('modules.webp',index,3,3);if(!a)return 0;const w=(id===8||id===7?94:78)+level*3;return Math.max(10,w*a.h/a.w*.9-14);}
  // Frames use measured ink bounds, preserving the generated atlas's uneven gutters.
  const siteFrames=[
    [17,128,278,188],[304,64,283,249],[597,117,284,193],[892,137,286,179],[1192,57,278,253],[1482,151,278,163],
    [14,351,286,239],[306,355,306,235],[614,329,272,268],[892,361,290,241],[1187,365,294,231],[1484,445,278,156],
    [16,612,281,230],[308,617,301,228],[618,618,273,226],[896,620,290,229],[1192,631,286,217],[1482,693,279,158]
  ];
  function siteMetrics(kind,variant,live){
    const row={car:0,house:1,store:2}[kind],img=images['exploration-sites.webp'];
    if(row==null||!img.complete||!img.naturalWidth)return null;
    const frame=siteFrames[row*6+(live?Math.max(0,Math.min(4,variant|0)):5)],width=live?(kind==='car'?60:62):54;
    return{img,frame,width,height:width*frame[3]/frame[2]};
  }
  function site(ctx,P,kind,variant,live,scale=1){
    const a=siteMetrics(kind,variant,live);if(!a)return false;
    const[x,y]=P(.5,.5,0),h=a.height*scale;
    ctx.drawImage(a.img,...a.frame,x-a.width/2,y+8-h,a.width,h);return true;
  }
  function siteHeight(kind,variant){const a=siteMetrics(kind,variant,true);return a?Math.max(10,a.height-16):0;}
  const landmarkFrames=[[18,83,473,334],[499,53,236,362],[757,173,400,255],[1169,91,443,331],[1623,180,346,256],[22,437,471,328],[501,424,235,335],[758,524,406,246],[1164,435,449,338],[1618,525,353,256]];
  function landmarkMetrics(k,ok){const img=images['landmarks.webp'];if(!img.complete||!img.naturalWidth||k<0||k>4)return null;const frame=landmarkFrames[k+(ok?5:0)],width=[76,44,72,76,66][k];return{img,frame,width,height:width*frame[3]/frame[2]};}
  function landmark(ctx,P,k,ok,scale=1){const a=landmarkMetrics(k,ok);if(!a)return false;const[x,y]=P(.5,.5,0),h=a.height*scale;ctx.drawImage(a.img,...a.frame,x-a.width/2,y+8-h,a.width,h);return true;}
  function landmarkHeight(k,ok){const a=landmarkMetrics(k,ok);return a?Math.max(10,a.height-16):0;}
  const thumbs=new Map();
  function thumb(file,index,cols,rows){const key=[file,index,cols,rows].join(':');if(thumbs.has(key))return thumbs.get(key);const a=crop(file,index,cols,rows);if(!a)return null;const c=document.createElement('canvas');c.width=144;c.height=144;const g=c.getContext('2d');g.drawImage(a.img,a.x,a.y,a.w,a.h,0,0,144,144);const url=c.toDataURL('image/png');thumbs.set(key,url);return url;}
  function radio(){return '<svg class="illustrated-radio" viewBox="0 0 240 180" role="img" aria-label="주파수 탐색 라디오"><image href="'+base+'radio.webp" width="240" height="180" preserveAspectRatio="xMidYMid meet"/></svg>';}
  function lamp(){const a=images['shelters.webp'];if(!a.complete||!a.naturalWidth)return false;const button=document.getElementById('lamp');if(!button||button.dataset.illustrated)return false;const svg=button.querySelector('svg'),w=a.naturalWidth/3,h=a.naturalHeight/2;if(!svg)return false;svg.querySelectorAll('path').forEach(p=>p.style.visibility='hidden');const art=document.createElementNS('http://www.w3.org/2000/svg','svg');art.setAttribute('x','14');art.setAttribute('y','13');art.setAttribute('width','46');art.setAttribute('height','46');art.setAttribute('viewBox',[w*2+3,h+3,w-6,h-6].join(' '));art.setAttribute('class','lamp-art');const image=document.createElementNS('http://www.w3.org/2000/svg','image');image.setAttribute('href',base+'shelters.webp');image.setAttribute('width',a.naturalWidth);image.setAttribute('height',a.naturalHeight);art.appendChild(image);svg.appendChild(art);button.dataset.illustrated='true';return true;}
  const timer=setInterval(()=>{if(lamp())clearInterval(timer);},300);setTimeout(()=>clearInterval(timer),20000);
  window.TTCDesign={portrait,core,module,moduleHeight,site,siteHeight,landmark,landmarkHeight,thumb,radio,version:'landmarks-20261002',assets:[...Object.values(sheets).map(a=>base+a.file),base+'shelters.webp',base+'modules.webp',base+'radio.webp',base+'exploration-sites.webp',base+'landmarks.webp']};
})();
