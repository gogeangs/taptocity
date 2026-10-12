import 'dart:math' as math;

/// 웹 버전(JavaScript)과 같은 결과를 내는 수 계산 도구.
/// 앱(64비트 정수)과 웹 미리보기(자바스크립트 숫자) 어느 쪽에서도 같은 값이 나오도록 32비트 연산을 직접 맞춘다.

const int _m32 = 0xFFFFFFFF;

/// JavaScript `Math.imul` — 결과는 부호 없는 32비트(0 ~ 2^32-1)로 돌려준다.
int imul32(int a, int b) {
  a &= _m32;
  b &= _m32;
  final ah = (a >>> 16) & 0xFFFF, al = a & 0xFFFF;
  final bh = (b >>> 16) & 0xFFFF, bl = b & 0xFFFF;
  final lo = al * bl;
  final mid = (((ah * bl + al * bh) & 0xFFFF) << 16) & _m32;
  return (lo + mid) & _m32;
}

/// 웹의 `mulberry(a)` (mulberry32). 0 이상 1 미만의 수를 차례로 낸다.
double Function() mulberry(int seed) {
  var a = seed & _m32;
  return () {
    a = (a + 0x6D2B79F5) & _m32;
    var t = imul32(a ^ (a >>> 15), 1 | a);
    t = ((t + imul32(t ^ (t >>> 7), 61 | t)) & _m32) ^ t;
    return ((t ^ (t >>> 14)) & _m32) / 4294967296;
  };
}

/// 웹의 `noise(r, sc)` — 격자 값 잡음.
double Function(num x, num y) valueNoise(double Function() r, int sc, {int w = 40}) {
  final gw = (w / sc).ceil() + 2;
  final g = List<double>.generate(gw * gw, (_) => r());
  double s(double t) => t * t * (3 - 2 * t);
  return (x, y) {
    final fx = x / sc, fy = y / sc;
    final x0 = fx.truncate(), y0 = fy.truncate();
    final u = s(fx - x0), v = s(fy - y0);
    final a = g[y0 * gw + x0], b = g[y0 * gw + x0 + 1], c = g[(y0 + 1) * gw + x0], d = g[(y0 + 1) * gw + x0 + 1];
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
  };
}

/// JavaScript `Math.round` (0.5는 항상 위로).
int jsRound(num x) => (x + 0.5).floor();

/// JavaScript `Math.hypot` (두 수).
double hypot(num a, num b) => math.sqrt(a * a + b * b);
