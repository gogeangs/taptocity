// Generative score for 탭투시티: no audio files, everything is synthesized with WebAudio.
// The game calls TTCMusic.mood(name) about once a second; layers crossfade between moods.
// Moods: day, night, air (은호's broadcast night), storm, under, story (dialogue: ducked), tut (그날 밤), off.
// TTCMusic.blackout() is the '딸깍 → black' beat: a lantern click, then the score drops out for a moment.
(function(){
let A=null,an=null,master=null,verb=null,started=false,enabled=true,cur='off',want='off',duck=1,black=0,timer=null,beat=0,nextT=0,chordI=0,lastMel=0;
const L={};// layer gains
const midi=n=>440*Math.pow(2,(n-69)/12);
// scales (semitones above root) and chord roots per mood
const M={
  day:  {bpm:72,root:57,scale:[0,2,4,7,9],chords:[[0,4,7],[5,9,12],[-3,0,4],[7,11,14]],pad:.2,mel:.55,pluck:'triangle',wind:.015,drum:0,radio:0,drip:0},
  night:{bpm:58,root:52,scale:[0,3,5,7,10],chords:[[0,3,7],[-4,0,3],[5,8,12],[-2,2,5]],pad:.18,mel:.28,pluck:'sine',wind:.05,drum:0,radio:0,drip:0},
  air:  {bpm:66,root:55,scale:[0,2,4,7,9],chords:[[0,4,7],[-3,0,4],[5,9,12],[7,11,14]],pad:.05,mel:.75,pluck:'triangle',wind:.03,drum:0,radio:1,drip:0},
  storm:{bpm:96,root:45,scale:[0,1,3,7,8],chords:[[0,3,7],[1,5,8],[-2,1,5],[0,3,7]],pad:.13,mel:.22,pluck:'sawtooth',wind:.09,drum:1,radio:0,drip:0},
  under:{bpm:50,root:43,scale:[0,3,5,6,10],chords:[[0,7,12],[0,6,12],[-2,5,10],[0,7,12]],pad:.22,mel:.18,pluck:'sine',wind:0,drum:0,radio:0,drip:1},
  tut:  {bpm:60,root:50,scale:[0,3,5,7,10],chords:[[0,3,7],[-2,2,5],[-4,0,3],[0,3,7]],pad:.1,mel:.2,pluck:'sine',wind:.07,drum:0,radio:0,drip:0}};
function ctx(){if(A)return A;try{A=new(window.AudioContext||window.webkitAudioContext)();}catch(e){return null;}
  master=A.createGain();master.gain.value=0;master.connect(A.destination);an=A.createAnalyser();an.fftSize=1024;master.connect(an);
  // small room: a generated impulse keeps everything soft and far away
  verb=A.createConvolver();const len=A.sampleRate*2.6,ir=A.createBuffer(2,len,A.sampleRate);for(let c=0;c<2;c++){const d=ir.getChannelData(c);for(let i=0;i<len;i++)d[i]=(Math.random()*2-1)*Math.pow(1-i/len,3);}verb.buffer=ir;
  const vg=A.createGain();vg.gain.value=.55;verb.connect(vg);vg.connect(master);
  for(const k of ['pad','mel','wind','drum','radio','drip'])L[k]=A.createGain(),L[k].gain.value=0,L[k].connect(master),L[k].connect(verb);
  L.radio.disconnect();const bp=A.createBiquadFilter();bp.type='bandpass';bp.frequency.value=1400;bp.Q.value=.9;L.radio.connect(bp);bp.connect(master);bp.connect(verb);
  wind();return A;}
function noiseBuf(sec){const n=A.sampleRate*sec,b=A.createBuffer(1,n,A.sampleRate),d=b.getChannelData(0);for(let i=0;i<n;i++)d[i]=Math.random()*2-1;return b;}
function wind(){const s=A.createBufferSource();s.buffer=noiseBuf(4);s.loop=true;const f=A.createBiquadFilter();f.type='bandpass';f.frequency.value=380;f.Q.value=.7;
  const lfo=A.createOscillator(),lg=A.createGain();lfo.frequency.value=.07;lg.gain.value=220;lfo.connect(lg);lg.connect(f.frequency);s.connect(f);f.connect(L.wind);s.start();lfo.start();}
function env(g,t,a,peak,dec){g.gain.cancelScheduledValues(t);g.gain.setValueAtTime(0,t);g.gain.linearRampToValueAtTime(peak,t+a);g.gain.exponentialRampToValueAtTime(.0005,t+a+dec);}
function note(dest,type,f,t,a,peak,dec,cut){const o=A.createOscillator(),g=A.createGain();o.type=type;o.frequency.value=f;let n=o;
  if(cut){const lp=A.createBiquadFilter();lp.type='lowpass';lp.frequency.value=cut;o.connect(lp);n=lp;}n.connect(g);g.connect(dest);env(g,t,a,peak,dec);o.start(t);o.stop(t+a+dec+.05);}
function pad(m,t,dur){const ch=m.chords[chordI%m.chords.length];for(const s of ch)for(const det of [-6,6]){const o=A.createOscillator(),g=A.createGain(),lp=A.createBiquadFilter();
  o.type='sawtooth';o.frequency.value=midi(m.root+s-12);o.detune.value=det;lp.type='lowpass';lp.frequency.value=m===M.storm?900:620;o.connect(lp);lp.connect(g);g.connect(L.pad);
  g.gain.setValueAtTime(0,t);g.gain.linearRampToValueAtTime(.05,t+dur*.35);g.gain.linearRampToValueAtTime(0,t+dur);o.start(t);o.stop(t+dur+.05);}}
function melody(m,t){let i=lastMel+[-2,-1,-1,0,1,1,2][Math.floor(Math.random()*7)];i=Math.max(0,Math.min(9,i));lastMel=i;
  const n=m.root+12+m.scale[i%5]+(i>=5?12:0);note(L.mel,m.pluck,midi(n),t,.006,.09,m===M.storm?.35:1.4,m.pluck==='sawtooth'?1500:0);
  if(m.radio){note(L.radio,'square',midi(n),t,.01,.05,.6,2600);}}
function drum(t,acc){const s=A.createBufferSource(),f=A.createBiquadFilter(),g=A.createGain();s.buffer=noiseBuf(.2);f.type='lowpass';f.frequency.value=acc?260:180;s.connect(f);f.connect(g);g.connect(L.drum);env(g,t,.003,acc?.5:.25,.18);s.start(t);
  note(L.drum,'sine',acc?62:52,t,.003,.5,.25);}
function drip(t){note(L.drip,'sine',midi(84+Math.floor(Math.random()*7)),t,.002,.06,.25);}
function crackle(t){const s=A.createBufferSource(),g=A.createGain();s.buffer=noiseBuf(.03);s.connect(g);g.connect(L.radio);env(g,t,.001,.08,.02);s.start(t);}
function setLayers(m,quiet){const t=A.currentTime,k=quiet?0:duck*(black?0:1),r=black?.03:.8;
  const lv={pad:m?m.pad:0,mel:m?.9:0,wind:m?m.wind*4:0,drum:m&&m.drum?.6:0,radio:m&&m.radio?1:0,drip:m&&m.drip?1:0};
  for(const x in lv)L[x].gain.setTargetAtTime(lv[x]*k,t,r);}
function tick(){if(!A||!started)return;const m=M[cur];const t=A.currentTime;if(!m){nextT=t;return;}
  const sp=60/m.bpm;if(nextT<t)nextT=t+.05;
  while(nextT<t+.25){const b=beat++;
    if(b%8===0){chordI++;pad(m,nextT,sp*8.2);}
    if(Math.random()<m.mel*(b%2?.6:1))melody(m,nextT);
    if(m.drum&&b%2===0)drum(nextT,b%8===0);
    if(m.drip&&Math.random()<.18)drip(nextT+Math.random()*sp);
    if(m.radio&&Math.random()<.5)crackle(nextT+Math.random()*sp);
    nextT+=sp;}}
function apply(){if(!A)return;const m=M[want]||null;if(want!==cur){cur=want;beat=0;nextT=A.currentTime+.1;}
  master.gain.setTargetAtTime(enabled&&cur!=='off'?.9:0,A.currentTime,.6);setLayers(m,!enabled||cur==='off');}
function start(){if(!enabled)return;if(!ctx())return;if(A.state==='suspended')A.resume();if(!started){started=true;timer=setInterval(tick,100);}apply();}
// browsers only allow audio after a tap
['pointerdown','keydown','touchend'].forEach(ev=>window.addEventListener(ev,()=>{if(enabled&&want!=='off')start();},{passive:true,capture:true}));
document.addEventListener('visibilitychange',()=>{if(!A)return;if(document.hidden)A.suspend();else if(enabled&&started)A.resume();});
window.TTCMusic={
  mood(m){if(m===want)return;want=m;if(A&&started)apply();},
  duck(on){const d=on?.45:1;if(d===duck)return;duck=d;if(A&&started)apply();},
  enable(on){enabled=!!on;if(enabled&&want!=='off')start();else if(A)apply();},
  // '딸깍', then the score cuts to black for a breath and comes back
  blackout(sec=2.6){if(!A||!started||!enabled)return;const t=A.currentTime;note(master,'square',2600,t,.001,.25,.03,0);note(master,'sine',180,t,.001,.3,.05);
    black=1;apply();setTimeout(()=>{black=0;apply();},sec*1000);},
  level(){if(!an)return 0;const d=new Float32Array(an.fftSize);an.getFloatTimeDomainData(d);let x=0,pk=0;for(const v of d){x+=v*v;pk=Math.max(pk,Math.abs(v));}this.peak=Math.max(this.peak||0,pk);return Math.sqrt(x/d.length);},
  get state(){return{want,cur,started,enabled,ctx:A&&A.state};}};
})();
