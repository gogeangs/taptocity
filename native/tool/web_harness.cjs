// 웹 버전(index.html)의 게임 코드를 브라우저 없이 불러와, 그 안의 값·함수를 그대로 꺼내 쓰는 도구.
// 네이티브 이식에서 (1) 데이터 표를 뽑고 (2) Dart 계산 결과를 웹과 비교하는 기준값(fixture)을 만드는 데 쓴다.
//
// 준비: 아무 폴더에서 `npm i jsdom@24` 후 NODE_PATH로 그 node_modules를 가리킨다.
// 사용: const web = require('./web_harness.cjs')(); web.ev('SURV.length'); web.ev('fresh()');
const fs = require('node:fs');
const path = require('node:path');
const { JSDOM } = require('jsdom');

module.exports = function load({ seedRandom = 12345 } = {}) {
  const root = path.join(__dirname, '../..');
  const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  // 게임 본체는 '(function(){ ... })();' 하나. 시작 호출 바로 앞에 스코프 안을 들여다보는 창(__ev)을 열고, 시작(루프)은 막는다.
  const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
  const main = scripts.find(s => s.includes("KEY='taptocity-shelter-v1'"));
  if (!main) throw Error('게임 본체 스크립트를 찾지 못했어요');
  const startCall = 'if(window.claude&&window.claude.hot&&window.claude.hot.ready)window.claude.hot.ready(start);';
  const at = main.indexOf(startCall);
  if (at < 0) throw Error('시작 호출 위치를 찾지 못했어요');
  const end = main.indexOf('\n', at);
  const code = main.slice(0, at) + 'window.__ev=(c)=>eval(c);' + main.slice(end);

  const body = html.slice(html.indexOf('<body>'), html.lastIndexOf('</body>') + 7).replace(/<script[\s\S]*?<\/script>/g, '');
  const dom = new JSDOM('<!doctype html><html><head></head>' + body + '</html>', { runScripts: 'outside-only', pretendToBeVisual: true, url: 'https://gogeangs.github.io/taptocity/' });
  const w = dom.window;
  // 캔버스·오디오는 아무 일도 안 하는 가짜로
  const noop = new Proxy(function () {}, { get: (t, k) => (k === 'canvas' ? { width: 1, height: 1 } : k === 'measureText' ? () => ({ width: 10 }) : k === 'getImageData' ? (x, y, a, b) => ({ data: new Uint8ClampedArray(Math.max(4, a * b * 4)) }) : noop), apply: () => noop, construct: () => noop, set: () => true });
  w.HTMLCanvasElement.prototype.getContext = () => noop;
  w.HTMLCanvasElement.prototype.toDataURL = () => '';
  w.AudioContext = w.webkitAudioContext = function () { return noop; };
  w.matchMedia = () => ({ matches: false, addEventListener() {}, addListener() {} });
  w.Element.prototype.animate = () => ({ finished: Promise.resolve() });
  w.Element.prototype.scrollIntoView = () => {};
  // 그림 늦게 받기(ttcLazy): 받지 않은 빈 그림으로
  w.ttcLazy = () => ({ complete: false, naturalWidth: 0, kick() {}, addEventListener() {} });
  // 같은 결과가 나오도록 Math.random 고정
  let s = seedRandom >>> 0;
  w.Math.random = () => { s = (s + 0x6D2B79F5) | 0; let t = Math.imul(s ^ (s >>> 15), 1 | s); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  w.eval(code);
  return { window: w, ev: c => w.__ev(c) };
};
