// 웹 버전의 소리(실시간 WebAudio 합성)를 그대로 오프라인으로 렌더링해 음원 파일로 만든다.
//  효과음: index.html 의 sfx() 를 그대로 돌림 → assets/audio/sfx/<이름>.m4a (변주가 있는 소리는 여러 벌)
//  배경음: music.js 의 분위기(day·night·air·storm·under·tut)마다 이음매 없이 도는 약 100초 고리 → assets/audio/music/<분위기>.m4a
// 실행: NODE_PATH=<node-web-audio-api 가 있는 곳> node tool/gen_audio.cjs   (ffmpeg 필요)
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const W = require('node-web-audio-api');
const ROOT = path.join(__dirname, '..', '..');
const OUT = path.join(__dirname, '..', 'assets', 'audio');
const TMP = fs.mkdtempSync(path.join(require('os').tmpdir(), 'ttc-audio-'));
const SR = 44100;
fs.mkdirSync(path.join(OUT, 'sfx'), { recursive: true });
fs.mkdirSync(path.join(OUT, 'music'), { recursive: true });

function wav(file, chans) {
  const n = chans[0].length, nc = chans.length, b = Buffer.alloc(44 + n * nc * 2);
  b.write('RIFF', 0); b.writeUInt32LE(36 + n * nc * 2, 4); b.write('WAVE', 8); b.write('fmt ', 12);
  b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(nc, 22); b.writeUInt32LE(SR, 24);
  b.writeUInt32LE(SR * nc * 2, 28); b.writeUInt16LE(nc * 2, 32); b.writeUInt16LE(16, 34); b.write('data', 36); b.writeUInt32LE(n * nc * 2, 40);
  let o = 44;
  for (let i = 0; i < n; i++) for (let c = 0; c < nc; c++) { b.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(chans[c][i] * 32767))), o); o += 2; }
  fs.writeFileSync(file, b);
}
function enc(src, dst, kbps) {
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', src, '-c:a', 'aac', '-b:a', `${kbps}k`, '-movflags', '+faststart', dst]);
}

// ---------- 효과음 ----------
const html = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');
const a0 = html.indexOf('let FXR=null;'), a1 = html.indexOf('\nconst DIARY=[');
let code = html.slice(a0, a1).replace(/let sfxAt=0;setInterval\([^\n]*\n/, 'let sfxAt=0;\n');
const make = new Function('ac', 'performance', `const lastS={};${code};return {sfx,setGet:(i)=>{getI=i;getT=0;},reset:()=>{FXR=null;for(const k in lastS)delete lastS[k];}};`);
async function renderSfx(k, sec, prep) {
  const c = new W.OfflineAudioContext(2, Math.ceil(SR * sec), SR);
  const S = make(() => c, { now: () => 0 });
  if (prep) prep(S);
  S.sfx(k);
  const buf = await c.startRendering();
  const L = buf.getChannelData(0), R = buf.getChannelData(1);
  // 끝의 무음 자르기
  let end = L.length;
  while (end > SR * .05 && Math.abs(L[end - 1]) < 1e-4 && Math.abs(R[end - 1]) < 1e-4) end--;
  end = Math.min(L.length, end + Math.round(SR * .02));
  return [L.slice(0, end), R.slice(0, end)];
}
const SFX = {
  click: [.5, 3], tap: [.25, 4], hit: [.25, 4], reveal: [1.5, 1], chime: [2.2, 1], toll: [6, 1], find: [1.8, 1], join: [3, 1], level: [3.6, 1], win: [3.2, 1],
  lit: [5.5, 1], heart: [.6, 1], steps: [1.2, 1], mystery: [3.6, 1], static: [2.1, 1], night: [4, 1], ui: [.12, 1],
};
(async () => {
  const only = process.argv[2];
  if (!only || only === 'sfx') {
    for (const [k, [sec, n]] of Object.entries(SFX)) {
      for (let v = 0; v < n; v++) {
        const ch = await renderSfx(k, sec);
        const nm = n > 1 ? `${k}${v}` : k, w = path.join(TMP, nm + '.wav');
        wav(w, ch);
        enc(w, path.join(OUT, 'sfx', nm + '.m4a'), 96);
      }
    }
    // 줍기: 오음음계를 한 칸씩 올라간다 (웹 PENTA·getI)
    for (let i = 0; i < 8; i++) {
      const ch = await renderSfx('get', 1, (S) => S.setGet(i));
      const w = path.join(TMP, `get${i}.wav`);
      wav(w, ch);
      enc(w, path.join(OUT, 'sfx', `get${i}.m4a`), 96);
    }
    console.log('sfx ok');
  }
  if (!only || only === 'music') {
    const src = fs.readFileSync(path.join(ROOT, 'music.js'), 'utf8');
    const first = src.indexOf('})();');
    let mcode = src.slice(0, first).replace('const t=A.currentTime;if(!m)', 'const t=(window.__T??A.currentTime);if(!m)') + 'window.__tick=tick;\n})();';
    // 분위기마다: 앞 8초는 버리고, 100초 남짓(마디의 배수) + 이음매 8초를 렌더링해 끝과 처음을 겹쳐 고리로 만든다
    const BAR = { day: 4.2, night: 5.2, air: 4.6, storm: 3.2, under: 6.4, tut: 5.6 };
    for (const [mood, bar] of Object.entries(BAR)) {
      const cyc = bar * 4, D = Math.round(cyc * Math.max(1, Math.round(100 / cyc)) * SR) / SR, X = 8, PRE = 8, tot = PRE + D + X + 1;
      const c = new W.OfflineAudioContext(2, Math.ceil(SR * tot), SR);
      c.resume = () => Promise.resolve(); c.suspend = () => Promise.resolve();
      const win = { addEventListener() {}, AudioContext: function () { return c; } };
      const doc = { addEventListener() {}, hidden: false };
      const realSI = global.setInterval;
      global.setInterval = () => 0;
      new Function('window', 'document', 'Math', mcode)(win, doc, Math);
      global.setInterval = realSI;
      win.TTCMusic.mood(mood);
      win.TTCMusic.enable(true);
      for (let t = 0; t < tot - 1; t += .1) { win.__T = t; win.__tick(); }
      const buf = await c.startRendering();
      const out = [new Float32Array(Math.round(D * SR)), new Float32Array(Math.round(D * SR))];
      const s0 = PRE * SR, n = out[0].length, x = X * SR;
      let pk = 0;
      for (let ch = 0; ch < 2; ch++) {
        const d = buf.getChannelData(ch);
        for (let i = 0; i < n; i++) {
          let v = d[s0 + i];
          if (i < x) { const f = i / x; v = d[s0 + i] * Math.sqrt(f) + d[s0 + n + i] * Math.sqrt(1 - f); }
          out[ch][i] = v;
          pk = Math.max(pk, Math.abs(v));
        }
      }
      if (pk > .98) for (const o of out) for (let i = 0; i < o.length; i++) o[i] *= .98 / pk;
      const w = path.join(TMP, mood + '.wav');
      wav(w, out);
      enc(w, path.join(OUT, 'music', mood + '.m4a'), 64);
      console.log('music', mood, D.toFixed(1) + 's', 'peak', pk.toFixed(3));
    }
  }
  process.exit(0);
})();
