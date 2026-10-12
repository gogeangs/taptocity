// iOS: 예전 탭투시티 앱(웹 게임을 띄우던 WKWebView)의 저장을 읽는 숨은 웹뷰.
// 같은 앱(번들 kr.co.itso.taptocity)이 기본 웹사이트 저장소를 쓰므로, 같은 주소를 열면 그때의 localStorage가 보인다.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LegacyPeek extends StatefulWidget {
  const LegacyPeek({super.key, required this.onResult});
  final void Function(String? raw) onResult;
  @override
  State<LegacyPeek> createState() => _LegacyPeekState();
}

class _LegacyPeekState extends State<LegacyPeek> {
  late final WebViewController c;
  bool _done = false;

  void _finish(String? v) {
    if (_done) return;
    _done = true;
    widget.onResult(v);
  }

  @override
  void initState() {
    super.initState();
    c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) async {
        try {
          final r = await c.runJavaScriptReturningResult("localStorage.getItem('taptocity-shelter-v1')||''");
          var s = r is String ? r : '$r';
          // iOS는 문자열을 JSON 문자열로 감싸 돌려줄 때가 있다
          if (s.startsWith('"')) s = jsonDecode(s) as String;
          _finish(s.isEmpty || s == 'null' ? null : s);
        } catch (_) {
          _finish(null);
        }
      }, onWebResourceError: (_) => _finish(null)))
      ..loadRequest(Uri.parse('https://gogeangs.github.io/taptocity/transfer.html?peek=1'));
    Timer(const Duration(seconds: 15), () => _finish(null));
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(child: Opacity(opacity: .01, child: SizedBox(width: 2, height: 2, child: WebViewWidget(controller: c))));
}
