// Cinematic ambient score for 탭투시티, synthesized live with WebAudio (no audio files).
// A soft felt piano plays short phrases with long rests over slow, wide pads, a quiet sub, and a big dark hall.
// The game calls TTCMusic.mood(name) about once a second. Moods: day, night, air (은호's broadcast night),
// storm, under, tut (그날 밤), off. TTCMusic.blackout() is the '딸깍 → black' beat.
(function(){
let A=null,an=null,master=null,bus=null,hall=null,echo=null,started=false,enabled=true,cur='off',want='off',duck=1,black=0,timer=null;
let t0=0,bar=0,nextBar=0,phraseLeft=0,lastDeg=2;
const L={};
const hz=n=>440*Math.pow(2,(n-69)/12);
// chords are MIDI notes written as voicings (open, wide); mel = scale degrees available to the piano (MIDI)
const M={
  day:  {bar:4.2,chords:[[48,55,64,71,74],[45,52,60,67,71],[41,48,57,64,67],[43,50,59,62,69]],mel:[67,69,71,72,74,76,79],pad:.5,pno:.9,sub:.35,phrase:.55,pan:.4,storm:0,radio:0,drip:0},
  night:{bar:5.2,chords:[[45,52,60,64,71],[41,48,57,60,67],[48,55,60,64,67],[40,47,55,59,66]],mel:[64,67,69,71,72,76],pad:.55,pno:.7,sub:.4,phrase:.38,pan:.35,storm:0,radio:0,drip:0},
  air:  {bar:4.6,chords:[[45,52,60,64,71],[41,48,57,60,67],[48,55,60,64,67],[43,50,59,62,67]],mel:[64,67,69,72,74,76],pad:.38,pno:0,sub:.3,phrase:0,pan:.3,storm:0,radio:1,drip:0},
  storm:{bar:3.2,chords:[[33,40,48,51,58],[34,41,49,53,58],[31,38,46,50,55],[33,40,48,51,56]],mel:[57,58,60,63,64],pad:.6,pno:.55,sub:.6,phrase:.25,pan:.25,storm:1,radio:0,drip:0},
  under:{bar:6.4,chords:[[31,38,46,50],[31,37,46,49],[29,36,44,48],[31,38,46,50]],mel:[74,77,79,82,84],pad:.55,pno:.35,sub:.5,phrase:.2,pan:.5,storm:0,radio:0,drip:1},
  tut:  {bar:5.6,chords:[[38,45,53,57,64],[34,41,50,53,60],[36,43,52,55,62],[38,45,53,57,60]],mel:[62,65,67,69,72],pad:.5,pno:.6,sub:.4,phrase:.3,pan:.3,storm:0,radio:0,drip:0}};
// an old song for the broadcast nights (a simple lullaby-like line, played the same way each time)
const SONG=[[69,1],[72,1],[76,2],[74,1],[72,1],[69,2],[67,1],[69,1],[72,2],[71,4],[69,1],[72,1],[76,2],[79,1],[77,1],[76,2],[74,1],[72,1],[71,2],[69,4]];
let songI=0;
function ctx(){if(A)return A;try{A=new(window.AudioContext||window.webkitAudioContext)();}catch(e){return null;}
  master=A.createGain();master.gain.value=0;
  const comp=A.createDynamicsCompressor();comp.threshold.value=-20;comp.ratio.value=3;comp.attack.value=.02;comp.release.value=.4;
  master.connect(comp);comp.connect(A.destination);an=A.createAnalyser();an.fftSize=1024;comp.connect(an);
  bus=A.createGain();bus.connect(master);
  // large dark hall: smoothed noise with a long exponential tail, so the tail is warm, not hissy
  hall=A.createConvolver();const sec=4.2,len=Math.floor(A.sampleRate*sec),ir=A.createBuffer(2,len,A.sampleRate);
  for(let c=0;c<2;c++){const d=ir.getChannelData(c);let lp=0;for(let i=0;i<len;i++){const w=Math.random()*2-1,k=.12+.5*(1-i/len);lp+=k*(w-lp);d[i]=lp*Math.exp(-3.2*i/len)*(i<A.sampleRate*.012?i/(A.sampleRate*.012):1);}}
  hall.buffer=ir;const hg=A.createGain();hg.gain.value=.9;hall.connect(hg);hg.connect(master);
  // soft echo for the piano
  echo=A.createDelay(2);echo.delayTime.value=.42;const fb=A.createGain();fb.gain.value=.28;const eg=A.createBiquadFilter();eg.type='lowpass';eg.frequency.value=1800;
  echo.connect(eg);eg.connect(fb);fb.connect(echo);const eo=A.createGain();eo.gain.value=.22;eg.connect(eo);eo.connect(hall);eo.connect(bus);
  for(const k of ['pad','pno','sub','storm','radio','drip']){L[k]=A.createGain();L[k].gain.value=0;L[k].connect(bus);}
  const sendP=A.createGain();sendP.gain.value=.55;L.pno.connect(sendP);sendP.connect(hall);L.pno.connect(echo);
  const sendD=A.createGain();sendD.gain.value=.5;L.pad.connect(sendD);sendD.connect(hall);
  const sendR=A.createGain();sendR.gain.value=.4;L.drip.connect(sendR);sendR.connect(hall);L.drip.connect(echo);
  const sendS=A.createGain();sendS.gain.value=.35;L.storm.connect(sendS);sendS.connect(hall);
  // the broadcast: a narrow, warm band like a small radio speaker in the next room
  L.radio.disconnect();const hp=A.createBiquadFilter(),lpR=A.createBiquadFilter();hp.type='highpass';hp.frequency.value=380;lpR.type='lowpass';lpR.frequency.value=2600;
  L.radio.connect(hp);hp.connect(lpR);lpR.connect(bus);const sr=A.createGain();sr.gain.value=.5;lpR.connect(sr);sr.connect(hall);
  return A;}
const pan=(dest,p)=>{if(!A.createStereoPanner)return dest;const s=A.createStereoPanner();s.pan.value=p;s.connect(dest);return s;};
// felt piano: a few slightly stretched partials, a soft hammer, a filter that closes as the note dies
function piano(dest,n,t,vel,len,p=0){const f=hz(n),out=A.createGain(),lp=A.createBiquadFilter();lp.type='lowpass';
  lp.frequency.setValueAtTime(900+vel*2600,t);lp.frequency.exponentialRampToValueAtTime(380,t+len);lp.Q.value=.3;
  out.gain.setValueAtTime(0,t);out.gain.linearRampToValueAtTime(.16*vel,t+.012);out.gain.exponentialRampToValueAtTime(.06*vel,t+.35);out.gain.exponentialRampToValueAtTime(.0004,t+len);
  lp.connect(out);out.connect(pan(dest,p));
  [[1,1],[2.003,.38],[3.008,.12],[4.02,.05]].forEach(([m,a])=>{const o=A.createOscillator(),g=A.createGain();o.type='sine';o.frequency.value=f*m;g.gain.value=a;o.connect(g);g.connect(lp);o.start(t);o.stop(t+len+.1);});
  const h=A.createOscillator(),hg=A.createGain();h.type='triangle';h.frequency.value=f*5.1;hg.gain.setValueAtTime(.025*vel,t);hg.gain.exponentialRampToValueAtTime(.0001,t+.05);h.connect(hg);hg.connect(lp);h.start(t);h.stop(t+.08);}
// pad: each chord tone is two detuned sines and a quiet triangle, swelling slowly, filter breathing
function pad(m,chord,t,dur){chord.forEach((n,i)=>{const p=(i%2?1:-1)*m.pan*(.4+i*.15),dest=pan(L.pad,Math.max(-1,Math.min(1,p)));
  const g=A.createGain(),lp=A.createBiquadFilter();lp.type='lowpass';lp.frequency.setValueAtTime(420,t);lp.frequency.linearRampToValueAtTime(900+i*120,t+dur*.5);lp.frequency.linearRampToValueAtTime(500,t+dur);
  g.gain.setValueAtTime(0,t);g.gain.linearRampToValueAtTime(.035,t+dur*.4);g.gain.linearRampToValueAtTime(.03,t+dur*.75);g.gain.linearRampToValueAtTime(0,t+dur+.6);lp.connect(g);g.connect(dest);
  [['sine',-5],['sine',5],['triangle',0]].forEach(([ty,dt],k)=>{const o=A.createOscillator(),og=A.createGain();o.type=ty;o.frequency.value=hz(n+12);o.detune.value=dt;og.gain.value=k===2?.35:1;o.connect(og);og.connect(lp);o.start(t);o.stop(t+dur+.7);});});}
function sub(n,t,dur){const o=A.createOscillator(),g=A.createGain();o.type='sine';o.frequency.value=hz(n);g.gain.setValueAtTime(0,t);g.gain.linearRampToValueAtTime(.12,t+1.2);g.gain.linearRampToValueAtTime(0,t+dur);o.connect(g);g.connect(L.sub);o.start(t);o.stop(t+dur+.1);}
// storm: deep drum swells and a low piano ostinato
function drum(t,v){const o=A.createOscillator(),g=A.createGain();o.type='sine';o.frequency.setValueAtTime(78,t);o.frequency.exponentialRampToValueAtTime(38,t+.5);g.gain.setValueAtTime(0,t);g.gain.linearRampToValueAtTime(.32*v,t+.01);g.gain.exponentialRampToValueAtTime(.0005,t+1.1);o.connect(g);g.connect(L.storm);o.start(t);o.stop(t+1.2);}
// a short phrase of 2-5 notes, mostly stepwise, with breath between
function phrase(m,t,span){const n=2+Math.floor(Math.random()*4);let tt=t+Math.random()*.4;
  for(let i=0;i<n&&tt<t+span;i++){lastDeg=Math.max(0,Math.min(m.mel.length-1,lastDeg+[-2,-1,-1,1,1,2,0][Math.floor(Math.random()*7)]));
    piano(L.pno,m.mel[lastDeg],tt,.45+Math.random()*.35,3.5,(Math.random()-.5)*.5);tt+=[.55,.8,1.1,.8][Math.floor(Math.random()*4)]*(m.bar/4.6);}}
function song(t,span){const beat=.62;let tt=t;while(tt<t+span-.1){const[n,len]=SONG[songI%SONG.length];songI++;piano(L.radio,n,tt,.7,len*beat+1.4);
    if(songI%4===1)piano(L.radio,n-24,tt,.35,3);tt+=len*beat;}}
function scheduleBar(m,t){const ch=m.chords[bar%m.chords.length];
  pad(m,ch,t,m.bar*1.05);sub(ch[0]-(ch[0]>40?12:0),t,m.bar);
  if(m.radio)song(t,m.bar);
  else if(Math.random()<m.phrase)phrase(m,t+m.bar*.15,m.bar*.8);
  if(m.storm){const q=m.bar/8;for(let i=0;i<8;i++)piano(L.storm,ch[0]+12+[0,7,12,7][i%4],t+i*q,.35,1.2,i%2?.2:-.2);drum(t,1);drum(t+m.bar*.5,.6);if(bar%2)drum(t+m.bar*.75,.45);}
  if(m.drip)for(let i=0;i<3;i++)if(Math.random()<.5)piano(L.drip,m.mel[Math.floor(Math.random()*m.mel.length)],t+Math.random()*m.bar,.25,2.5,(Math.random()-.5)*.8);
  bar++;}
function tick(){if(!A||!started||!enabled||cur==='off')return;const m=M[cur];const t=A.currentTime;if(!m){nextBar=t;return;}if(nextBar<t)nextBar=t+.1;
  while(nextBar<t+.4){scheduleBar(m,nextBar);nextBar+=m.bar;}}
function setLayers(){const m=M[cur],quiet=!enabled||cur==='off'||!m,t=A.currentTime,k=quiet?0:duck*(black?0:1),r=black?.03:1.2;
  const lv={pad:m?m.pad:0,pno:m?m.pno:0,sub:m?m.sub:0,storm:m&&m.storm?.6:0,radio:m&&m.radio?.9:0,drip:m&&m.drip?.8:0};
  for(const x in lv)L[x].gain.setTargetAtTime(lv[x]*k,t,r);}
function apply(){if(!A)return;if(want!==cur){cur=want;bar=0;songI=0;nextBar=A.currentTime+.2;}
  master.gain.setTargetAtTime(enabled&&cur!=='off'?.85:0,A.currentTime,.8);setLayers();}
function start(){if(!enabled)return;if(!ctx())return;if(A.state==='suspended')A.resume();if(!started){started=true;timer=setInterval(tick,120);}apply();}
['pointerdown','keydown','touchend'].forEach(ev=>window.addEventListener(ev,()=>{if(enabled&&want!=='off')start();},{passive:true,capture:true}));
document.addEventListener('visibilitychange',()=>{if(!A)return;if(document.hidden)A.suspend();else if(enabled&&started)A.resume();});
window.TTCMusic={
  mood(m){if(m===want)return;want=m;if(A&&started)apply();},
  duck(on){const d=on?.5:1;if(d===duck)return;duck=d;if(A&&started)apply();},
  enable(on){enabled=!!on;if(enabled&&want!=='off')start();else if(A)apply();},
  // '딸깍', then the score cuts to black for a breath and comes back
  blackout(sec=2.6){if(!A||!started||!enabled)return;
    black=1;apply();setTimeout(()=>{black=0;apply();},sec*1000);},
  level(){if(!an)return 0;const d=new Float32Array(an.fftSize);an.getFloatTimeDomainData(d);let x=0,pk=0;for(const v of d){x+=v*v;pk=Math.max(pk,Math.abs(v));}this.peak=Math.max(this.peak||0,pk);return Math.sqrt(x/d.length);},
  get state(){return{want,cur,started,enabled,ctx:A&&A.state};}};
})();
// iPhone: Web Audio follows the ringer switch unless a media element has played; one silent clip from a tap fixes that
(function(){const SIL='data:audio/wav;base64,UklGRuQSAABXQVZFZm10IBAAAAABAAEAQB8AAIA+AAACABAAZGF0YcASAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';let done=false;
  function unlock(){try{if(navigator.audioSession)navigator.audioSession.type='playback';}catch(e){}
    if(done)return;done=true;try{const a=new Audio(SIL);a.setAttribute('playsinline','');a.volume=0.01;const p=a.play();if(p&&p.catch)p.catch(()=>{done=false;});}catch(e){done=false;}}
  ['pointerdown','touchend','keydown','click'].forEach(ev=>window.addEventListener(ev,unlock,{capture:true,passive:true}));})();
