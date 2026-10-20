// 웹 버전(index.html)에 들어 있는 선 아이콘을 그대로 옮겼다. stroke="currentColor"는 그릴 때 색을 정한다.
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract final class Ico {
  static const gear =
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></svg>';
  static const profileLamp =
      '<svg viewBox="0 0 40 40" fill="none" stroke="#efe3c4" stroke-width="2" stroke-linejoin="round"><path d="M14 11h12M16 11V8h8v3M13 13h14l-2 17H15z"/><path d="M16 30h8v3h-8z" fill="#efe3c4"/><path d="M20 17c3 3 3 6 0 8-3-2-3-5 0-8z" fill="#ffcf7a" stroke="none"/></svg>';
  static const home =
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><circle cx="12" cy="12" r="7"/><circle cx="12" cy="12" r="2" fill="currentColor"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/></svg>';
  static const dots = '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="5" cy="12" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="19" cy="12" r="2"/></svg>';
  static const surv =
      '<svg viewBox="0 0 26 26" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="10" cy="9" r="3.5"/><path d="M3 22c.8-4.5 3.6-7 7-7s6.2 2.5 7 7"/><circle cx="18.5" cy="8" r="2.8"/><path d="M18 14.5c3 .3 5 2.5 5.5 6"/></svg>';
  static const exp =
      '<svg viewBox="0 0 26 26" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 23V12a7 7 0 0 1 14 0v11z"/><path d="M9 23v-5h8v5M10 8h6M13 3v2"/></svg>';
  static const shelter =
      '<svg viewBox="0 0 26 26" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 22L13 4l10 18z"/><path d="M9.5 22l3.5-7 3.5 7M2 22h22"/></svg>';
  static const radio =
      '<svg viewBox="0 0 26 26" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="9" width="20" height="14" rx="2"/><path d="M7 9l10-5"/><circle cx="17" cy="16" r="3"/><path d="M6.5 13h4M6.5 16h4M6.5 19h4"/></svg>';
  static const diary =
      '<svg viewBox="0 0 26 26" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 4h13a3 3 0 0 1 3 3v15H8a3 3 0 0 1-3-3z"/><path d="M5 19a3 3 0 0 1 3-3h13M10 8h7M10 11h5"/></svg>';
  static String _i(String p) => '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">$p</svg>';
  static final wall = _i('<path d="M3 20h18M4 20V9h4v11M10 20V6h4v14M16 20V9h4v11"/><path d="M4 9l2-2 2 2M10 6l2-2 2 2M16 9l2-2 2 2"/>');
  static final tap = _i('<path d="M14 4c3 0 6 2 7 5-3-1-6-1-9 1"/><path d="M12 10L4 20"/><path d="M14 4l-2 6"/>');
  static final splash = _i('<path d="M12 3c3 4 5 6 5 9a5 5 0 0 1-10 0c0-3 2-5 5-9z"/><path d="M12 11c1 1.5 2 2.5 2 3.5a2 2 0 0 1-4 0c0-1 1-2 2-3.5z"/>');
  static final drone = _i('<rect x="9" y="10" width="6" height="4" rx="1"/><path d="M9 12H4M15 12h5M4 9h4M16 9h4M12 14v3"/><circle cx="12" cy="18" r="1"/>');
  static const lock =
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>';
  // 글꼴(ttc-sans)에 없는 기호·Material 아이콘 글꼴(시험 화면에서는 안 실림) 대신 그리는 작은 그림들
  static const heart =
      '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>';
  static const heartO =
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"><path d="M12 20l-1.2-1.1C6.2 14.7 3.2 12 3.2 8.7 3.2 6 5.3 4 7.9 4c1.5 0 3 .7 4.1 1.9C13.1 4.7 14.6 4 16.1 4c2.6 0 4.7 2 4.7 4.7 0 3.3-3 6-7.6 10.2L12 20z"/></svg>';
  static final gift = _i('<rect x="3" y="8" width="18" height="4" rx="1"/><path d="M5 12v8h14v-8M12 8v12M12 8c-1.5-3-5-4-5-1.5S10 8 12 8zM12 8c1.5-3 5-4 5-1.5S14 8 12 8z"/>');
  static final truck = _i('<path d="M2 6h11v10H2zM13 9h4l3 3v4h-7"/><circle cx="6" cy="17.5" r="1.8"/><circle cx="16.5" cy="17.5" r="1.8"/>');
  static const check =
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12l5 5 9-10"/></svg>';

  /// 연속 일수 불꽃 (글꼴에 이모지가 없어 그림으로)
  static const flame =
      '<svg viewBox="0 0 24 24"><path d="M12 2c1 4 6 6.5 6 12.5a6 6 0 0 1-12 0c0-3.2 1.8-5.2 3-6.5 0 2 .9 3.2 2 3.5-.8-3.2.1-6.5 1-9.5z" fill="#f08a2c"/><path d="M12 11.5c1.8 1.9 3 3.2 3 5.2a3 3 0 0 1-6 0c0-1.9 1.4-3.2 3-5.2z" fill="#ffd98a"/></svg>';

  /// 랜턴 버튼 (웹 #lamp): 진행 고리와 불꽃 크기만 바뀐다
  /// 웹 두드리기 버튼 (design.js lamp + qa.css #lampRing): 짙은 원 + 밝은 연타 고리. 랜턴은 손그림(shelters.webp 6번째 칸)을 위에 얹는다
  static String lampRing(double p, bool fever) {
    final off = (201 * (1 - p.clamp(0, 1))).toStringAsFixed(1);
    final ring = fever ? '#ffd060' : '#fff3c4';
    return '<svg viewBox="0 0 74 74">'
        '<circle cx="37" cy="37" r="32" fill="#26323c" stroke="#efd7a8" stroke-width="1.5"/>'
        '${fever ? '<circle cx="37" cy="37" r="32" fill="none" stroke="#ffd060" stroke-opacity=".35" stroke-width="9"/>' : ''}'
        '<circle cx="37" cy="37" r="32" fill="none" stroke="#281c0a" stroke-opacity=".55" stroke-width="7" stroke-linecap="round" transform="rotate(-90 37 37)" stroke-dasharray="201" stroke-dashoffset="$off"/>'
        '<circle cx="37" cy="37" r="32" fill="none" stroke="$ring" stroke-width="5.5" stroke-linecap="round" transform="rotate(-90 37 37)" stroke-dasharray="201" stroke-dashoffset="$off"/>'
        '</svg>';
  }

  static String lamp(double p, double flame) {
    final off = (201 * (1 - p.clamp(0, 1))).toStringAsFixed(1);
    return '<svg viewBox="0 0 74 74">'
        '<circle cx="37" cy="37" r="32" fill="#26323c" stroke="#efd7a8" stroke-width="1.5"/>'
        '<circle cx="37" cy="37" r="32" fill="none" stroke="#f3a53a" stroke-width="4" stroke-linecap="round" transform="rotate(-90 37 37)" stroke-dasharray="201" stroke-dashoffset="$off"/>'
        '<path d="M29 24h16M31 24v-4h12v4M28 26h18l-2 24H30z" fill="none" stroke="#efe3c4" stroke-width="2" stroke-linejoin="round"/>'
        '<path d="M31 50h12v4H31z" fill="#efe3c4"/>'
        '<g transform="translate(37 42) scale(${flame.toStringAsFixed(3)})"><path d="M0-10C5-4 5 2 0 5-5 2-5-4 0-10z" fill="#ffcf7a"/><path d="M0-5C2-2 2 2 0 3-2 2-2-2 0-5z" fill="#fff4d6"/></g>'
        '</svg>';
  }
}

class SvgIcon extends StatelessWidget {
  const SvgIcon(this.svg, {super.key, this.size = 22, this.color});
  final String svg;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => SvgPicture.string(svg, width: size, height: size, theme: SvgTheme(currentColor: color ?? const Color(0xFFE7E4DC)));
}
