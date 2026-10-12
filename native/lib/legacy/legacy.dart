// 예전 버전(웹 게임·웹 감싸기 앱)의 진행 찾기.
//  - 웹 미리보기: 같은 주소(gogeangs.github.io)라 웹 게임의 localStorage를 바로 읽는다
//  - iOS: 예전 앱이 쓰던 WKWebView 저장소를 숨은 웹뷰로 읽는다 (legacy_peek.dart)
//  - Android: 예전 앱은 크롬 저장소라 직접 못 읽는다 → 진행 옮기기 페이지(transfer.html)에서 taptocity://import 로 받아 온다
export 'legacy_stub.dart' if (dart.library.js_interop) 'legacy_web.dart';
