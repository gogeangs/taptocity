// 웹 미리보기를 실제 크롬으로 열어 본다: 콘솔 오류와 화면 사진을 남긴다 (CI 전용).
//   node native/tool/web_smoke.cjs <출력 폴더>
const puppeteer = require('puppeteer-core');
const out = process.argv[2] || '.';
const fs = require('fs');
(async () => {
  const browser = await puppeteer.launch({ executablePath: process.env.CHROME || '/usr/bin/google-chrome', args: ['--no-sandbox', '--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 375, height: 812, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  const log = [];
  page.on('console', (m) => log.push(`[${m.type()}] ${m.text()}`));
  page.on('pageerror', (e) => log.push(`[pageerror] ${e.message}`));
  page.on('requestfailed', (r) => log.push(`[requestfailed] ${r.url()} ${r.failure() && r.failure().errorText}`));
  const url = 'http://localhost:8080/taptocity/native-play/';
  let bytes = 0;
  page.on('response', async (r) => {
    try {
      const b = await r.buffer();
      bytes += b.length;
    } catch (_) {}
  });
  const t0 = Date.now();
  await page.goto(url, { waitUntil: 'load', timeout: 60000 });
  await page.waitForSelector('flutter-view', { timeout: 60000 }).catch(() => log.push('[timing] flutter-view 없음'));
  log.push(`[timing] 첫 화면까지 ${((Date.now() - t0) / 1000).toFixed(1)}초`);
  await new Promise((r) => setTimeout(r, 12000));
  log.push(`[timing] 받은 양 ${(bytes / 1e6).toFixed(1)}MB`);
  await page.screenshot({ path: `${out}/web-1-first.png` });
  // 다시 열기 (저장된 진행으로 시작)
  await page.reload({ waitUntil: 'load' });
  await new Promise((r) => setTimeout(r, 12000));
  await page.screenshot({ path: `${out}/web-2-reload.png` });
  fs.writeFileSync(`${out}/web-console.txt`, log.join('\n') + '\n');
  await browser.close();
  const bad = log.filter((l) => /pageerror|\[error\]|Exception|Error:/.test(l));
  if (bad.length) console.log(bad.slice(0, 30).join('\n'));
})().catch((e) => {
  console.log('smoke failed: ' + e);
  process.exit(0);
});
