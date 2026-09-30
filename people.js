/* Small articulated ink figures. Colors and accessories follow approved portraits.
   Presentation only: never mutates survivor, child, assignment or movement state. */
(function(){
'use strict';
const ink='#24282a',cream='#d7cbb0';
const styles=[
 ['#445665','cap','short',1.08],['#41494b','helmet','short',.96],
 ['#527c78','mask','bun',.91],['#a64e3e','hood','bob',.9],
 ['#53695a','scarf','bun',1.02],['#b7a58a','apron','curl',1.13],
 ['#4a5b69','vest','short',1.12],['#586a78','beret','bob',.9],
 ['#9e5145','firehelm','short',1.06],['#858780','glasses','short',.96],
 ['#655e73','headphones','long',.95],['#4e7878','bag','long',.9],
 ['#74624d','waistcoat','short',.94],['#ba764a','stripe','bob',.99],
 ['#b39a58','scarf','bun',.9],['#4d606d','goggles','short',1.1],
 ['#a75043','pack','bob',.93],['#4d5050','scarf','short',.86]
];
function person(g,sv,x,y,time,moving,face=1,job=null,reduced=false){
 const L=sv.look||{},st=Number.isInteger(sv.id)?styles[sv.id]:null;
 const top=st?st[0]:(L.top||'#6e7b77'),acc=st?st[1]:(L.acc||''),hair=st?st[2]:'short';
 const child=sv.age<13,scale=child?.78:sv.age<18?.9:1,width=st?st[3]:.94;
 const phase=reduced?0:time/(child?135:165)+(sv.id||0)*.71;
 const stride=moving&&!reduced?Math.sin(phase)*2.1:0,work=job&&!reduced?Math.sin(phase*.7):0;
 const bob=moving&&!reduced?Math.abs(Math.sin(phase))*.65:0;
 g.save();g.translate(x,y);g.scale(scale,scale);
 g.fillStyle='rgba(15,21,25,.26)';g.beginPath();g.ellipse(0,.5,5.8,2,0,0,7);g.fill();
 g.scale(face<0?-1:1,1);g.translate(0,-bob);g.lineCap='round';g.lineJoin='round';
 function poly(p,c,line=ink){g.beginPath();p.forEach((q,i)=>i?g.lineTo(...q):g.moveTo(...q));g.closePath();g.fillStyle=c;g.fill();if(line){g.strokeStyle=line;g.lineWidth=.65;g.stroke();}}
 function line(p,c,w){g.beginPath();p.forEach((q,i)=>i?g.lineTo(...q):g.moveTo(...q));g.strokeStyle=c;g.lineWidth=w;g.stroke();}
 function oval(x,y,rx,ry,c){g.fillStyle=c;g.beginPath();g.ellipse(x,y,rx,ry,0,0,7);g.fill();}
 // Alternating knees and small boots stay anchored to the ground.
 for(const side of [-1,1]){const step=stride*side;line([[side*1.7,-9],[side*1.7+step*.4,-4.5],[side*1.7+step,0]],ink,3.1);line([[side*1.7,-8],[side*1.7+step*.4,-4.5]],'#59636a',1.8);line([[side*1.7+step,0],[side*1.7+step+1.7,.1]],'#303235',2.1);}
 if(['pack','bag','helmet'].includes(acc))poly([[-5,-19],[-7,-17],[-6.5,-10],[-3,-10],[-3,-18]],'#665c4d');
 if(hair==='long'||hair==='bob')poly([[-3.5,-25],[-5,-23],[-4.5,hair==='long'?-14:-19],[1,-18],[3,-23]],L.hair||ink);
 const w=4.1*width;
 poly([[-w,-18.5],[-2,-20],[2,-20],[w,-18],[w+.5,-9],[-w,-8.5]],top);
 poly([[-w,-18],[-w+.8,-10],[-1,-9],[-1,-19]],'rgba(20,29,33,.20)',null);
 poly([[-2,-20],[0,-17.6],[2,-20],[1,-15]],'#c2b7a0');
 line([[.4,-17],[.4,-10]],'rgba(28,33,33,.6)',.65);
 line([[-3,-13],[-1.5,-13]],cream,.6);
 if(acc==='apron'||acc==='waistcoat')poly([[-2.8,-17],[2.8,-17],[3.2,-9],[-3,-9]],acc==='apron'?'#9b5141':'#5d5143');
 if(acc==='vest'){for(const a of [-1,1])poly([[a*1.8,-19],[a*3.5,-18],[a*3.9,-10],[a*1.5,-10]],'#b57c47');}
 if(['helmet','firehelm','stripe','vest'].includes(acc))line([[-3.8,-12],[3.8,-12]],'#cbbd87',1.3);
 if(['scarf','hood','pack'].includes(acc)){poly([[-3,-20],[3,-20],[2,-16.5],[-2,-17]],acc==='scarf'?'#929084':'#3a4448');if(acc==='scarf')poly([[-2,-18],[0,-18],[-.8,-12],[-2.5,-13]],'#81867f');}
 // Arms are articulated independently from the body.
 const handY=job?-12+work*1.4:-10+stride*.4;
 line([[-w,-18],[-w-1,-14],[-w-1-stride*.3,-10]],ink,3.3);
 line([[-w,-18],[-w-1,-14]],top,2.3);oval(-w-1-stride*.3,-9.8,1.15,1.35,L.skin||'#d5ac88');
 line([[w,-18],[w+1,-14],[w+1.3+stride*.3,handY]],ink,3.3);
 line([[w,-18],[w+1,-14]],top,2.3);oval(w+1.3+stride*.3,handY,1.15,1.4,L.skin||'#d5ac88');
 // Asymmetric face, hair silhouette and a single readable eye.
 poly([[-2.5,-25.5],[1,-26],[3.5,-24],[3.5,-21.5],[1.6,-19.5],[-1.8,-20],[-3.1,-22]],L.skin||'#d5ac88');
 poly([[-3.2,-23],[-3.7,-25],[-1.6,-27],[1.5,-27.2],[3.2,-25],[1,-24.7],[-1.5,-25.1]],L.hair||ink);
 if(hair==='bun')oval(-3.7,-24,2.3,2.5,L.hair||ink);
 if(hair==='curl')for(const a of [-3,-1,1,3])oval(a,-25.8,1.8,1.6,L.hair||ink);
 line([[1.3,-23],[2.2,-23]],ink,.75);
 if(sv.age>55)line([[-1.5,-20.5],[1,-20]],'#c4bba8',1);
 if(['cap','beret','helmet','firehelm','vest'].includes(acc)){
  const c=acc==='helmet'||acc==='vest'?'#c4a153':acc==='firehelm'?'#a05144':'#3e505e';
  poly([[-4,-25],[-3.5,-28],[.6,-29],[3.5,-27.5],[4,-25]],c);
  line([[-3.5,-25],[4.6,-25.1]],ink,1.1);
  if(acc==='cap'||acc==='firehelm')poly([[.5,-25],[5.5,-25],[4.4,-24],[1,-24]],c);
  if(acc==='beret')oval(-2,-27.3,3.2,1.6,c);
 }
 if(acc==='glasses'||acc==='goggles'){const yy=acc==='glasses'?-23:-26;line([[-1.3,yy],[3.8,yy]],ink,.65);for(const xx of [-.5,2.5])poly([[xx-1,yy-1],[xx+1,yy-1],[xx+1,yy+.8],[xx-1,yy+.8]],acc==='goggles'?'#758180':'rgba(226,218,186,.3)');}
 if(acc==='mask')poly([[-2.5,-19],[2.5,-19],[2,-17],[-2,-17]],'#bacbc2');
 if(acc==='headphones'){oval(-3,-20,1.3,2,'#a8a394');oval(3,-20,1.3,2,'#a8a394');}
 if(acc==='pack'||acc==='bag')line([[-3,-18],[2,-10]],'#b6a17d',1);
 if(job){g.save();g.translate(w+1.3,handY);g.rotate(reduced?-.25:-.25+work*.18);
  if(job==='grow'){line([[0,0],[2,7]],'#a99572',1.2);line([[-1,7],[5,7]],'#646d6b',1.6);}
  else if(job==='care'||job==='read'){poly([[0,-2],[5,-1],[5,5],[0,4]],cream);line([[1,0],[4,.6]],'#747c76',.6);}
  else if(job==='water'){line([[0,0],[3,0],[4,3]],'#a7aea3',.8);poly([[0,2],[5,2],[4,7],[1,7]],'#718a90');}
  else{line([[0,0],[2,-5]],'#ac9270',1.4);line([[0,-5],[4,-4]],'#9ba6a2',2.1);}
  g.restore();}
 g.restore();return true;
}
window.TTCPeople={person,version:'people-20261001'};
})();
