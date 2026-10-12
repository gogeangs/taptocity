// 웹 버전의 현재 화면 색·글꼴 (design.css + qa.css를 적용한 최종 계산값)
import 'package:flutter/material.dart';

abstract final class Ttc {
  // 바탕
  static const body = Color(0xFF141A21);
  static const header = Color(0xFF202932);
  static const tape = Color(0xFF2D3741);
  static const lvchip = Color(0xFF2C333B);
  static const stage = Color(0xFF252F3B);
  static const btn = Color(0xFF242D36);
  static const tabOn = Color(0xFF35434A);
  static const tabOnLine = Color(0xFFC89D5C);
  static const tabOnText = Color(0xFFF1DEBB);
  static const tabText = Color(0xFFD5D9D3);
  static const hudText = Color(0xFFE7E4DC);
  static const matText = Color(0xFFE9E9DF);
  static const line12 = Color(0x1FEEE5D3); // rgba(238,229,211,.12)
  static const line17 = Color(0x2BEEE5D3);
  static const line20 = Color(0x33EEE5D3);
  static const line25 = Color(0x40EEE5D3);

  // 시트·종이
  static const paper = Color(0xFFE7E4DC);
  static const surface = Color(0xFFFAF8F1);
  static const heroCard = Color(0xFFFAF4E7);
  static const heroLine = Color(0xFFC7974E);
  static const lockedCard = Color(0xFFE0E2DB);
  static const segs = Color(0xFFDCE0DC);
  static const segText = Color(0xFF606970);
  static const sepia = Color(0xFF26333B);
  static const sepia2 = Color(0xFF606B70);
  static const sumText = Color(0xFF64716F);
  static const line = Color(0x2426333B); // rgba(38,51,59,.14)
  static const ok = Color(0xFF4F6E2F);
  static const no = Color(0xFFB0452A);
  static const noBg = Color(0xFFF0DFD7);
  static const noText = Color(0xFF9A483D);

  // 강조
  static const amber = Color(0xFFDFA54B);
  static const amberBtn = Color(0xFFD9A34E);
  static const amberBtnLine = Color(0xFFC68E38);
  static const glow = Color(0xFFF4C77F);
  static const lvText = Color(0xFFFFDF9E);
  static const rust = Color(0xFFAB5145);
  static const darkBtn = Color(0xFF334954);
  static const darkBtnText = Color(0xFFF8F5E9);
  static const offBtn = Color(0xFFDCE0DA);
  static const offBtnLine = Color(0xFFC9CFCA);
  static const offBtnText = Color(0xFF727B7C);

  static const sans = 'TTCSans';

  /// 본문 글꼴 (TTC Sans = Noto Sans KR 일부, 가변 굵기)
  static TextStyle t(double size, {Color color = hudText, FontWeight weight = FontWeight.w400, double height = 1.3}) => TextStyle(
        fontFamily: sans,
        fontFamilyFallback: const ['Noto Sans KR', 'sans-serif'],
        fontSize: size,
        color: color,
        fontWeight: weight,
        fontVariations: [FontVariation.weight((weight.index + 1) * 100.0)],
        height: height,
        leadingDistribution: TextLeadingDistribution.even,
      );

  /// 이야기 글꼴 (고운바탕)
  static TextStyle serif(double size, {Color color = hudText, FontWeight weight = FontWeight.w400, double height = 1.3}) =>
      TextStyle(fontFamily: 'GowunBatang', fontSize: size, color: color, fontWeight: weight, height: height, leadingDistribution: TextLeadingDistribution.even);

  static ThemeData theme() => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: body,
        fontFamily: sans,
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: sans),
        colorScheme: const ColorScheme.dark(primary: amber, surface: header, onSurface: hudText),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      );
}
