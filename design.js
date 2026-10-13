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
  // 까마귀 대장과 아이들: 3x2 sheet, cells 686x764 — crow 0, (1 unused: 진 keeps the scouts-sheet portrait), kids 2..5 (봄이 다온 로운 하람)
  const CK={file:'crows-kids.webp',w:2058,h:1528,cols:3,rows:2},ckImg=ttcLazy(base+CK.file);
  const ckReady=()=>!!(ckImg.complete&&ckImg.naturalWidth);
  function ckCell(n,label){const w=CK.w/CK.cols,h=CK.h/CK.rows,x=n%CK.cols*w,y=Math.floor(n/CK.cols)*h;
    return '<svg class="illustrated-portrait" viewBox="0 0 120 140" role="img" aria-label="'+escape(label)+' 초상화"><svg width="120" height="140" viewBox="'+[x+6,y+6,w-12,h-14].join(' ')+'" preserveAspectRatio="xMidYMin slice"><image href="'+base+CK.file+'" width="'+CK.w+'" height="'+CK.h+'" preserveAspectRatio="none"/></svg></svg>';}
  const KIDC={'봄이':2,'다온':3,'로운':4,'하람':5};
  function kid(name){const n=KIDC[name];return n!=null&&ckReady()?ckCell(n,name):null;}
  // 동네 사람들 (12 residents, ids 18..29): 4x3 sheet residents.webp, cells 686x764, in RESIDENTS order
  const RS={file:'residents.webp',w:2744,h:2292,cols:4,rows:3},rsImg=ttcLazy(base+RS.file);
  // 전용 도구를 든 초상: survivors-signature-1/2.webp, 3x3 each, cells 387x452, ids 0..8 and 9..17 in reading order
  const SG=[{file:'survivors-signature-1.webp',w:1161,h:1356,cols:3,rows:3},{file:'survivors-signature-2.webp',w:1161,h:1356,cols:3,rows:3}],sgImg=SG.map(a=>ttcLazy(base+a.file));
  // 칸 크기가 고르지 않아(가운데 열이 넓음) 균등 분할하면 옆 칸 테두리가 선으로 비친다 — 실제 칸 안쪽 좌표
  const SGF=[[[10,9,371,427],[397,9,366,427],[779,9,371,427],[10,452,371,413],[397,452,366,413],[779,452,371,413],[10,883,371,461],[397,883,366,461],[779,883,371,461]],[[12,9,354,429],[384,9,394,429],[795,9,356,429],[12,456,354,428],[384,456,394,428],[795,456,356,428],[12,903,354,441],[384,903,394,441],[795,903,356,441]]];
  function sigPortrait(s){const id=s&&s.id;if(!(id>=0&&id<18))return null;const k=id<9?0:1,n=id<9?id:id-9,A=SG[k],im=sgImg[k];if(!(im.complete&&im.naturalWidth))return null;
    const f=SGF[k][n];
    return '<svg class="illustrated-portrait sig" viewBox="0 0 120 140" role="img" aria-label="'+escape(s.name)+' 초상화"><svg width="120" height="140" viewBox="'+f.join(' ')+'" preserveAspectRatio="xMidYMin slice"><image href="'+base+A.file+'" width="'+A.w+'" height="'+A.h+'" preserveAspectRatio="none"/></svg></svg>';}
  function portrait(s,sig){
    if(sig){const r=sigPortrait(s);if(r)return r;}
    if(s&&s.src==='town'&&s.id>=18&&s.id<30){if(!(rsImg.complete&&rsImg.naturalWidth))return null;const n=s.id-18,w=RS.w/RS.cols,h=RS.h/RS.rows,x=n%RS.cols*w,y=Math.floor(n/RS.cols)*h;
      return '<svg class="illustrated-portrait" viewBox="0 0 120 140" role="img" aria-label="'+escape(s.name)+' 초상화"><svg width="120" height="140" viewBox="'+[x+6,y+6,w-12,h-14].join(' ')+'" preserveAspectRatio="xMidYMin slice"><image href="'+base+RS.file+'" width="'+RS.w+'" height="'+RS.h+'" preserveAspectRatio="none"/></svg></svg>';}
    const p=s&&portraits[s.id];if(!p)return null;
    const a=sheets[p[0]],w=a.w/a.cols,h=a.h/a.rows,x=p[1]%a.cols*w,y=Math.floor(p[1]/a.cols)*h;
    return '<svg class="illustrated-portrait" viewBox="0 0 120 140" role="img" aria-label="'+escape(s.name)+' 초상화"><svg width="120" height="140" viewBox="'+[x,y,w,h].join(' ')+'" preserveAspectRatio="xMidYMin slice"><image href="'+base+a.file+'" width="'+a.w+'" height="'+a.h+'" preserveAspectRatio="none"/></svg></svg>';
  }
  // undiscovered survivors: the real portrait as a dark cut-out (same crop as the portrait), so the shape hints at who they are
  const SIL={file:'survivors-silhouettes.webp?v=3',cols:6,rows:5,w:1440,h:1400}; // ids 0..29
  function silhouette(s){
    const p=s&&(portraits[s.id]||(s.src==='town'&&s.id>=18&&s.id<30));if(!p)return null;
    const w=SIL.w/SIL.cols,h=SIL.h/SIL.rows,x=s.id%SIL.cols*w,y=Math.floor(s.id/SIL.cols)*h,hid=!!s.hidden;
    return '<svg class="illustrated-portrait sil" viewBox="0 0 120 140" role="img" aria-label="아직 만나지 못한 생존자"><rect width="120" height="140" fill="#e6d8b6"/><svg x="0" y="4" width="120" height="136" viewBox="'+[x,y,w,h].join(' ')+'" preserveAspectRatio="xMidYMin slice" opacity=".86"><image href="'+base+SIL.file+'" width="'+SIL.w+'" height="'+SIL.h+'" preserveAspectRatio="none"/></svg><circle cx="96" cy="112" r="16" fill="'+(hid?'#ffd24a':'#f3d9a0')+'" stroke="#3b2a1a" stroke-width="2.4"/><text x="96" y="'+(hid?'119':'120')+'" text-anchor="middle" font-family="Gowun Batang,serif" font-size="'+(hid?'18':'21')+'" font-weight="700" fill="#3b2a1a">'+(hid?'★':'?')+'</text></svg>';
  }
  const images={};
  ['shelters.webp','modules.webp','radio.webp','exploration-sites.webp','landmarks.webp'].forEach(file=>{images[file]=ttcLazy(base+file);});
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
  // 동네별 랜드마크 그림(사막·공단·설원). 그 동네에 있을 때만, 처음 쓸 때 받는다. 받기 전에는 첫 동네 그림에 동네 색을 입혀 보여 준다.
  const LMR={desert:{file:'landmarks-desert.webp',frames:[[17,85,366,268],[427,95,372,254],[862,24,252,333],[1189,66,384,283],[1615,64,353,287],[12,463,375,282],[430,474,369,266],[872,408,243,342],[1190,449,385,289],[1616,446,352,294]]},factory:{file:'landmarks-factory.webp',frames:[[22,49,380,340],[450,82,325,305],[824,96,337,277],[1211,62,346,324],[1599,95,364,288],[22,403,381,344],[449,427,329,319],[823,450,338,276],[1210,415,349,328],[1598,448,365,292]]},snow:{file:'landmarks-snow.webp',frames:[[6,81,412,312],[442,115,363,270],[836,83,335,297],[1205,91,350,298],[1587,96,382,291],[11,393,419,375],[446,483,360,273],[831,403,350,345],[1202,417,357,346],[1583,438,388,323]]}};
  const lmRegion=()=>{try{return window.TTCDesign&&TTCDesign.regionFn?TTCDesign.regionFn():null;}catch(e){return null;}};
  function lmRegArt(){const R=LMR[lmRegion()];if(!R)return null;const img=R.img||(R.img=ttcLazy(base+R.file));return img.complete&&img.naturalWidth?R:null;}
  // 노선 역 입구(line-stations): 4열(첫 동네·사막·공단·설원) × 2행(폐허·복구). 받기 전에는 랜드마크 그림을 쓴다.
  const LS={file:'line-stations.webp',frames:[[15,55,363,295],[396,56,368,297],[782,60,357,289],[1159,58,362,295],[14,432,364,299],[399,432,368,299],[783,436,356,293],[1159,433,362,299]]};
  // 공단 역은 화물칸이 들어간 따로 그린 두 칸(line-stations-factory)을 우선 쓴다
  const LSF={file:'line-stations-factory.webp',frames:[[6,75,378,247],[390,75,372,249]]};
  function lsfArt(){const img=LSF.img||(LSF.img=ttcLazy(base+LSF.file));return img.complete&&img.naturalWidth?img:null;}
  function lsArt(){const img=LS.img||(LS.img=ttcLazy(base+LS.file));return img.complete&&img.naturalWidth?img:null;}
  function landmarkMetrics(k,ok){if(k===4){const img=lsArt();if(img){const col={desert:1,factory:2,snow:3}[lmRegion()]||0;if(col===2){const f2=lsfArt();if(f2){const frame=LSF.frames[ok?1:0],width=94;return{img:f2,frame,width,height:width*frame[3]/frame[2]};}}const frame=LS.frames[col+(ok?4:0)],width=88;return{img,frame,width,height:width*frame[3]/frame[2]};}}const R=lmRegArt();if(R&&k>=0&&k<=4){const frame=R.frames[k+(ok?5:0)],width=Math.max(48,Math.min(80,frame[2]*.2));return{img:R.img,frame,width,height:width*frame[3]/frame[2]};}const img=images['landmarks.webp'];if(!img.complete||!img.naturalWidth||k<0||k>4)return null;const frame=landmarkFrames[k+(ok?5:0)],width=[76,44,72,76,66][k];return{img,frame,width,height:width*frame[3]/frame[2]};}
  function landmark(ctx,P,k,ok,scale=1){const a=landmarkMetrics(k,ok);if(!a)return false;const[x,y]=P(.5,.5,0),h=a.height*scale;ctx.drawImage(a.img,...a.frame,x-a.width/2,y+8-h,a.width,h);return true;}
  function landmarkHeight(k,ok){const a=landmarkMetrics(k,ok);return a?Math.max(10,a.height-16):0;}
  const thumbs=new Map();
  function thumb(file,index,cols,rows){const key=[file,index,cols,rows].join(':');if(thumbs.has(key))return thumbs.get(key);const a=crop(file,index,cols,rows);if(!a)return null;const c=document.createElement('canvas');c.width=144;c.height=144;const g=c.getContext('2d');g.drawImage(a.img,a.x,a.y,a.w,a.h,0,0,144,144);const url=c.toDataURL('image/png');thumbs.set(key,url);return url;}
  function radio(){return '<svg class="illustrated-radio" viewBox="0 0 240 180" role="img" aria-label="주파수 탐색 라디오"><image href="'+base+'radio.webp" width="240" height="180" preserveAspectRatio="xMidYMid meet"/></svg>';}
  function lamp(){const a=images['shelters.webp'];if(!a.complete||!a.naturalWidth)return false;const button=document.getElementById('lamp');if(!button||button.dataset.illustrated)return false;const svg=button.querySelector('svg'),w=a.naturalWidth/3,h=a.naturalHeight/2;if(!svg)return false;svg.querySelectorAll('path').forEach(p=>p.style.visibility='hidden');const art=document.createElementNS('http://www.w3.org/2000/svg','svg');art.setAttribute('x','14');art.setAttribute('y','13');art.setAttribute('width','46');art.setAttribute('height','46');art.setAttribute('viewBox',[w*2+3,h+3,w-6,h-6].join(' '));art.setAttribute('class','lamp-art');const image=document.createElementNS('http://www.w3.org/2000/svg','image');image.setAttribute('href',base+'shelters.webp');image.setAttribute('width',a.naturalWidth);image.setAttribute('height',a.naturalHeight);art.appendChild(image);svg.appendChild(art);button.dataset.illustrated='true';return true;}
  const timer=setInterval(()=>{if(lamp())clearInterval(timer);},300);setTimeout(()=>clearInterval(timer),20000);
  // 장비 아이콘 3 시트 (gear-tools 7x3 · gear-wear 5x3 · gear-keep 6x3), GEAR key → [sheet, cell] in reading order
  const GS={tools:{file:'gear-tools.webp',w:1792,h:768,cols:7,rows:3},wear:{file:'gear-wear.webp',w:1600,h:960,cols:5,rows:3},keep:{file:'gear-keep.webp',w:1536,h:768,cols:6,rows:3}};
  const GCELL={};
  ['lever','hammer','welder','binoc','axe','toolbox','shovel','wrench','light','saw','medkit','steth','hoe','ladle','tape2','rope2','meter','mic','rope3','loupe','mpick'].forEach((k,i)=>GCELL[k]=['tools',i]);
  ['coverall','mask','gloves','firesuit','coat','armor','boots','raincoat','helmet','apron','parka','drvglove','herbbag','wmask','mhelm'].forEach((k,i)=>GCELL[k]=['wear',i]);
  ['photo','coin','harmonica','seeds','watch','brooch','tape','bell','compass','notebook','ring','bag','umbrella','sketch','vane','ckey','feather','mlamp'].forEach((k,i)=>GCELL[k]=['keep',i]);
  const gsImg={};for(const k in GS){gsImg[k]=ttcLazy(base+GS[k].file);}
  function gear(t){const c=GCELL[t];if(!c)return null;const A=GS[c[0]],im=gsImg[c[0]];if(!(im.complete&&im.naturalWidth))return null;const w=A.w/A.cols,h=A.h/A.rows,x=c[1]%A.cols*w,y=Math.floor(c[1]/A.cols)*h;
    return '<svg class="gart" viewBox="'+[x+8,y+8,w-16,h-16].join(' ')+'" aria-hidden="true"><image href="'+base+A.file+'" width="'+A.w+'" height="'+A.h+'"/></svg>';}
  window.TTCDesign={lmArtKey:()=>{const r=lmRegion();return (r||'')+(lmRegArt()?'+':'')+(LS.img&&lsArt()?'L':'')+(LSF.img&&lsfArt()?'F':'');},lineArt:()=>!!lsArt(),portrait,silhouette,kid,core,module,moduleHeight,site,siteHeight,landmark,landmarkHeight,thumb,radio,gear,sigPortrait,version:'landmarks-20261014-line',assets:[...Object.values(sheets).map(a=>base+a.file),...Object.values(GS).map(a=>base+a.file),...SG.map(a=>base+a.file),base+SIL.file,base+'shelters.webp',base+'modules.webp',base+'radio.webp',base+'exploration-sites.webp',base+'landmarks.webp']};
})();
