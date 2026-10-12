# 탭투시티 네이티브 (Flutter)

웹 버전(저장소 루트)을 Flutter 앱으로 옮기는 중이에요. 계획: [`docs/native-port-plan.md`](../docs/native-port-plan.md)

- `lib/game/` 게임 규칙 — 웹 `index.html`의 같은 이름 함수를 그대로 옮김 (주석에 웹 행 번호)
- `lib/data/web_data.g.dart` 웹에서 자동으로 뽑은 데이터 표 (직접 고치지 않음)
- `lib/ui/` 화면 — 지도는 바뀔 때만 다시 그리고, 연출이 끝나면 프레임을 멈춤
- `test/web_parity_test.dart` 같은 시드·같은 상태에서 웹과 같은 값이 나오는지 확인

## 데이터·기준값 다시 뽑기 (웹 코드를 고쳤을 때)

```
npm i jsdom@24            # 아무 폴더에서 한 번
NODE_PATH=<그 폴더>/node_modules node native/tool/gen_data.cjs
```

## 빌드

GitHub Actions `Native` 워크플로가 `native/`가 바뀔 때마다 검사·테스트 후 APK와 웹 미리보기를 만들어요.
- APK: Actions 실행 화면 → Artifacts → `taptocity-apk`
- 웹 미리보기: https://gogeangs.github.io/taptocity/native-play/
