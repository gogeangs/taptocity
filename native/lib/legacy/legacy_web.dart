import 'package:web/web.dart' as html;

/// 같은 주소의 웹 게임 저장 (웹 KEY)
Future<String?> readWebSave() async {
  try {
    return html.window.localStorage.getItem('taptocity-shelter-v1');
  } catch (_) {
    return null;
  }
}
