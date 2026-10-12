// 기기 시험 드라이버: 앱이 찍은 화면 사진을 ios-shots/ 에 저장한다
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final f = File('ios-shots/$name.png');
        f.parent.createSync(recursive: true);
        f.writeAsBytesSync(bytes);
        return true;
      },
    );
