// 화면 사진 비교: 글꼴 앤티에일리어싱 같은 아주 작은 차이(픽셀 0.3% 이하)는 같은 화면으로 본다 (코드 정리 안전망, 2026-10-23)
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final c = goldenFileComparator;
  if (c is LocalFileComparator) goldenFileComparator = _Tolerant(Uri.parse('${c.basedir}screens_test.dart'));
  await testMain();
}

class _Tolerant extends LocalFileComparator {
  _Tolerant(super.testFile);
  static const tol = .003;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final r = await GoldenFileComparator.compareLists(imageBytes, await getGoldenBytes(golden));
    if (r.passed || r.diffPercent <= tol) {
      r.dispose();
      return true;
    }
    final msg = await generateFailureOutput(r, golden, basedir);
    r.dispose();
    throw FlutterError('화면이 기준과 달라요: $golden (${(r.diffPercent * 100).toStringAsFixed(2)}%)\n$msg');
  }
}
