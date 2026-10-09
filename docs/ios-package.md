# iOS 앱 (App Store)

- 방식: SwiftUI + WKWebView 래퍼가 `https://gogeangs.github.io/taptocity/` 를 전체 화면으로 띄운다 (`ios/`).
- 번들 ID `kr.co.itso.taptocity`, 표시 이름 "탭투시티", iOS 16 이상, 세로 고정.
- `gogeangs.github.io` 는 App-Bound Domain 이라 서비스 워커가 동작해 한 번 연 뒤에는 오프라인에서도 열린다.
- 앱의 사용자 에이전트에 `TaptocityiOS` 가 붙는다. `cloud.js` 는 이를 보고 구글 계정 연결 버튼을 숨긴다
  (WKWebView 안에서는 구글 로그인이 막히고, Apple 심사 4.8 조항도 피하기 위해). 익명 자동 백업과 데이터 삭제는 그대로 동작한다.
- 빌드: GitHub Actions(`.github/workflows/ios.yml`)가 macOS 러너에서 XcodeGen → 아카이브 → App Store Connect 업로드까지 한다.
  - 시크릿: `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`
  - 시크릿이 없으면 시뮬레이터 빌드로 컴파일만 확인한다.
  - 빌드 번호 = 워크플로 실행 번호. 버전을 올릴 때는 `ios/project.yml` 의 `MARKETING_VERSION` 을 바꾼다.
- 다시 올리기: Actions 탭 → iOS → Run workflow.
