// 광고: 휴대폰(안드로이드·아이폰)에서만. 웹 미리보기에서는 아무것도 하지 않는 빈 판을 쓴다 (google_mobile_ads·dart:io는 웹에서 못 쓴다)
export 'ads_stub.dart' if (dart.library.io) 'ads_io.dart';
