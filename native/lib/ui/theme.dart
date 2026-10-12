// 웹 버전의 색과 글꼴 (index.html :root)
import 'package:flutter/material.dart';

abstract final class Ttc {
  static const ink = Color(0xFF0D0B08);
  static const leather = Color(0xFF3A2618);
  static const paper = Color(0xFFEFE3C4);
  static const sepia = Color(0xFF3B2A1A);
  static const sepia2 = Color(0xFF6E5638);
  static const amber = Color(0xFFF3A53A);
  static const glow = Color(0xFFFFCF7A);
  static const rust = Color(0xFFB0452A);
  static const muted = Color(0xFFC9B48F);
  static const good = Color(0xFF6E8F3A);

  static const sans = 'TTCSans';
  static const serif = 'GowunBatang';

  static TextStyle body(double size, {Color color = paper, FontWeight weight = FontWeight.w400, bool shadow = false}) => TextStyle(
        fontFamily: sans,
        fontFamilyFallback: const ['Noto Sans KR', 'sans-serif'],
        fontSize: size,
        color: color,
        fontWeight: weight,
        // 본문 글꼴은 가변 글꼴(기본값이 가장 가는 굵기)이라 굵기를 직접 지정한다
        fontVariations: [FontVariation.weight((weight.index + 1) * 100.0)],
        height: 1.3,
        shadows: shadow ? const [Shadow(color: Color(0xCC000000), blurRadius: 3, offset: Offset(0, 1))] : null,
      );

  static TextStyle title(double size, {Color color = paper}) =>
      TextStyle(fontFamily: serif, fontFamilyFallback: const ['serif'], fontSize: size, color: color, fontWeight: FontWeight.w700, height: 1.2);

  static ThemeData theme() => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ink,
        fontFamily: sans,
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: sans).copyWith(
              bodyMedium: body(14),
              bodyLarge: body(16),
              titleMedium: body(16, weight: FontWeight.w700),
            ),
        colorScheme: const ColorScheme.dark(primary: amber, surface: leather, onSurface: paper),
        splashFactory: NoSplash.splashFactory,
      );
}
