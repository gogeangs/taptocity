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

## 2026-10-11 첫 TestFlight 업로드
- 번들 ID `kr.co.itso.taptocity` 등록, App Store Connect 앱 '탭투시티'(App ID 6821579723, SKU taptocity-ios) 생성.
- 시크릿 4개(APPLE_TEAM_ID=TGYFG9R2C7, ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8) 등록 후 Actions의 iOS 워크플로를 수동 실행(workflow_dispatch)하면 빌드 번호 = 실행 번호로 업로드된다.
- 테스트 기기 없이 올리기: 아카이브는 서명 없이(CODE_SIGNING_ALLOWED=NO), 내보내기에서 API 키로 Apple 클라우드 배포 서명.
- App Store는 Xcode 26(iOS 26 SDK) 이상 빌드만 받는다 → macos-26 러너, Xcode_26 선택.
- 실패하면 원인이 Actions 실행의 주석(annotations)에 `::error::`로 남는다.

## 2026-10-11 App Store 출시 준비
- iOS 앱은 아이폰 전용(TARGETED_DEVICE_FAMILY 1). 심사용 빌드 12.
- 스토어 문구·카테고리·스크린샷: `ios/store/metadata`, `ios/store/screenshots/ko/*.jpg`(1320x2868). 고친 뒤 Actions의 'iOS store listing'을 실행하면 `ios/store/asc_upload.py`가 App Store Connect API로 올린다(스크린샷은 지우고 다시 올림, 제출은 안 함).
- 웹에서 직접 한 것: 가격 무료·175개국, 연령 등급 13+, 콘텐츠 권한(타사 콘텐츠 없음), 앱 개인정보(사용자 ID·게임 플레이 콘텐츠, 앱 기능, 신원 연결, 추적 없음), 심사 메모(영문), 로그인 불필요.
- ios/store 만 바뀐 푸시는 iOS 빌드를 다시 돌리지 않는다.
