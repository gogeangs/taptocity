// 안개 지도. 웹과 달리 화면을 쉬지 않고 다시 그리지 않는다:
//  - 지도(땅·건물·구름)는 지도 번호(mapVersion)나 카메라가 바뀔 때만 그린다.
//  - 반짝임·떠오르는 글자 같은 연출은 남아 있는 동안에만 따로 그린다. 없으면 0fps.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../game/data.dart';
import '../game/engine.dart';
import '../game/rng.dart';
import 'atlas.dart';
import 'theme.dart';

class Camera extends ChangeNotifier {
  double x = 0, y = (CX + CY + 1) * TH / 2 - 10, z = 1.4;
  bool userZoomed = false;
  void set(double nx, double ny, [double? nz]) {
    if (nz != null) userZoomed = true;
    x = nx.clamp(-W * TW / 2, W * TW / 2).toDouble();
    y = ny.clamp(0, (W + H) * TH / 2).toDouble();
    if (nz != null) z = nz.clamp(.45, 3.2).toDouble();
    notifyListeners();
  }
}

Offset tileC(int i, [double z = 0]) {
  final x = i % W, y = i ~/ W;
  return Offset((x - y) * TW / 2, (x + y + 1) * TH / 2 - z);
}

int pickTile(Offset w) {
  final a = w.dx / (TW / 2), b = w.dy / (TH / 2);
  final gx = ((a + b) / 2).floor(), gy = ((b - a) / 2).floor();
  return (gx < 0 || gy < 0 || gx >= W || gy >= H) ? -1 : gy * W + gx;
}

/// 땅 색 무늬 (웹 GN 4477)
final List<double> groundNoise = List<double>.generate(N, (i) {
  final x = i % W, y = i ~/ W;
  return (math.sin(x * .55 + 1.3) * math.cos(y * .47 - .7) + math.sin((x + y) * .23 + 2.1) * .8 + math.sin((x - y) * .31) * .5 + (speck[i] - .5) * .7) / 2.9;
});

class MapView extends StatefulWidget {
  const MapView({super.key, required this.game, required this.camera, required this.onSelect, required this.fxLayer, this.onTouch});
  final Game game;
  final Camera camera;
  final void Function(String kind, int tile) onSelect;
  final FxLayerController fxLayer;
  final VoidCallback? onTouch;

  @override
  State<MapView> createState() => _MapViewState();
}

class _Ptr {
  _Ptr(this.pos) : start = pos;
  Offset pos;
  final Offset start;
  bool moved = false;
  bool acted = false;
  int site = -1;
  int digging = -1;
  int r0 = 0;
  Timer? hold;
}

const holdMax = 30;

class _MapViewState extends State<MapView> {
  final Map<int, _Ptr> ptrs = {};
  Size size = Size.zero;
  Offset? dragCam;
  Offset? dragStart;
  double? pinchD, pinchZ;
  double _framedW = 0;

  Game get g => widget.game;
  Camera get cam => widget.camera;

  Offset toWorld(Offset s) => Offset((s.dx - size.width / 2) / cam.z + cam.x, (s.dy - size.height / 2) / cam.z + cam.y);
  Offset toScreen(Offset w) => Offset((w.dx - cam.x) * cam.z + size.width / 2, (w.dy - cam.y) * cam.z + size.height / 2);

  bool onScreen(int i) {
    final s = toScreen(tileC(i, 12));
    return s.dx >= 14 && s.dx <= size.width - 14 && s.dy >= 40 && s.dy <= size.height - 14;
  }

  int frontierAt(Offset p) {
    final r = TW * .8 * cam.z;
    var best = -1;
    var bd = r * r;
    for (final i in g.frontier) {
      final d = (toScreen(tileC(i, 12)) - p).distanceSquared;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  int screenFrontier(Offset p) {
    var best = -1;
    var bd = double.infinity;
    for (final i in g.frontier) {
      if (!onScreen(i)) continue;
      final d = (toScreen(tileC(i, 12)) - p).distanceSquared;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  int get revCount => g.S.rev.fold(0, (a, v) => a + v);

  void _down(PointerDownEvent e) {
    widget.onTouch?.call();
    final p = _Ptr(e.localPosition);
    ptrs[e.pointer] = p;
    if (ptrs.length == 1) {
      dragStart = e.localPosition;
      dragCam = Offset(cam.x, cam.y);
    } else {
      for (final q in ptrs.values) {
        q.hold?.cancel();
        q.moved = true;
      }
      final l = ptrs.values.toList();
      pinchD = math.max(1.0, (l[0].pos - l[1].pos).distance);
      pinchZ = cam.z;
      return;
    }
    final w = toWorld(p.pos);
    final i = pickTile(w);
    if (i >= 0 && g.S.rev[i] == 1 && ((g.S.camp[i]?['hp'] as num?) ?? 0) > 0) {
      p.acted = true;
      g.setAim(i);
      g.hitCamp(i, g.tapPow * (g.fever > 0 ? 2 : 1));
      _after();
      void again() {
        final q = ptrs[e.pointer];
        if (q == null || q.moved || ((g.S.camp[i]?['hp'] as num?) ?? 0) <= 0) return;
        g.hitCamp(i, g.tapPow * (g.fever > 0 ? 2 : 1));
        _after();
        q.hold = Timer(const Duration(milliseconds: 110), again);
      }

      p.hold = Timer(const Duration(milliseconds: 320), again);
      return;
    }
    if (i >= 0 && g.S.rev[i] == 1 && g.siteLive(i)) {
      p.acted = true;
      p.site = i;
      g.setAim(i);
      g.hitSite(i, g.tapPow * (g.fever > 0 ? 2 : 1));
      _after();
      p.hold = Timer(const Duration(milliseconds: 320), () => _holdSite(e.pointer));
      return;
    }
    final onBld = i >= 0 && g.S.rev[i] == 1 && (i == C0 || g.modAtTile(i) != null || g.S.camp.containsKey(i) || g.S.ter[i] == T.lm);
    final f = frontierAt(p.pos);
    final onLand = i >= 0 && g.S.rev[i] == 1;
    if (f >= 0 && !onBld && (!onLand || (toScreen(tileC(f, 12)) - p.pos).distance < TW * .38 * cam.z)) {
      p.acted = true;
      p.digging = f;
      p.r0 = revCount;
      g.setAim(f);
      g.dig(f);
      _after();
      p.hold = Timer(const Duration(milliseconds: 320), () => _holdDig(e.pointer));
    }
  }

  void _holdSite(int id) {
    final p = ptrs[id];
    if (p == null || p.moved || !g.siteLive(p.site)) return;
    g.hitSite(p.site, g.tapPow * (g.fever > 0 ? 2 : 1));
    _after();
    p.hold = Timer(const Duration(milliseconds: 110), () => _holdSite(id));
  }

  void _holdDig(int id) {
    final p = ptrs[id];
    if (p == null || p.moved) return;
    if (revCount - p.r0 >= holdMax) {
      widget.fxLayer.toast('구름 $holdMax개를 걷었어요 · 다시 눌러요');
      return;
    }
    var f = p.digging;
    if (f < 0 || g.S.rev[f] == 1) {
      f = (g.aim >= 0 && g.frontier.contains(g.aim) && onScreen(g.aim)) ? g.aim : frontierAt(p.pos);
      if (f < 0 || !onScreen(f)) f = screenFrontier(p.pos);
      if (f < 0) {
        widget.fxLayer.toast('화면 안의 구름을 다 걷었어요 · 지도를 옮겨요');
        return;
      }
      g.setAim(f);
    }
    p.digging = f;
    g.dig(f);
    _after();
    p.hold = Timer(const Duration(milliseconds: 110), () => _holdDig(id));
  }

  void _move(PointerMoveEvent e) {
    final p = ptrs[e.pointer];
    if (p == null) return;
    p.pos = e.localPosition;
    if (!p.moved && (p.pos - p.start).distance > 14) {
      p.moved = true;
      p.hold?.cancel();
    }
    if (ptrs.length >= 2 && pinchD != null) {
      final l = ptrs.values.toList();
      final d = (l[0].pos - l[1].pos).distance;
      cam.set(cam.x, cam.y, pinchZ! * d / pinchD!);
      return;
    }
    if (ptrs.length == 1 && p.moved && dragStart != null) {
      cam.set(dragCam!.dx - (p.pos.dx - dragStart!.dx) / cam.z, dragCam!.dy - (p.pos.dy - dragStart!.dy) / cam.z);
    }
  }

  void _up(PointerEvent e, {bool cancel = false}) {
    final p = ptrs.remove(e.pointer);
    if (p == null) return;
    p.hold?.cancel();
    if (!cancel && !p.moved && !p.acted && pinchD == null) {
      final i = pickTile(toWorld(p.pos));
      final kind = g.tapTile(i);
      if (kind == 'far' || kind == 'none') {
        widget.fxLayer.toast('빛이 새는 구름이나 폐허를 두드려 보세요');
      } else {
        widget.onSelect(kind, i);
      }
      _after();
    }
    if (ptrs.length < 2) pinchD = null;
    if (ptrs.isEmpty) {
      dragStart = null;
    } else {
      final q = ptrs.values.first;
      q.moved = true;
      dragStart = q.pos;
      dragCam = Offset(cam.x, cam.y);
    }
  }

  void _after() {
    widget.fxLayer.pull(g);
    g.poke();
  }

  @override
  void dispose() {
    for (final p in ptrs.values) {
      p.hold?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      size = c.biggest;
      widget.fxLayer.viewSize = size;
      if (!cam.userZoomed && size.width > 0 && (size.width - _framedW).abs() > 1) {
        // 웹과 같은 확대: 화면 폭에 칸 4.2개 (직접 확대하기 전까지는 화면 크기를 따라감)
        _framedW = size.width;
        cam.z = (size.width / (TW * 4.2)).clamp(.6, 2.2).toDouble();
      }
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: (e) => _up(e),
        onPointerCancel: (e) => _up(e, cancel: true),
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) cam.set(cam.x, cam.y, cam.z * math.exp(-e.scrollDelta.dy * .0015));
        },
        child: ClipRect(child: Stack(fit: StackFit.expand, children: [
          RepaintBoundary(child: CustomPaint(painter: MapPainter(g, cam, Listenable.merge([g.mapVersion, cam])))),
          RepaintBoundary(child: FxLayer(controller: widget.fxLayer, camera: cam)),
        ])),
      );
    });
  }
}

// ======================= 지도 그리기 =======================
/// 구름 덩이 하나의 타원들 (웹 mkFog 재정의, index.html 6372): 132×104 그림 기준, 칸 중심에서의 위치
class _FogShape {
  _FogShape(int seed) {
    final r = mulberry(seed);
    for (var k = 0; k < 4; k++) {
      final y = 56 - r() * 10, rx = 27 + r() * 5, ry = 23 + r() * 6;
      ovals.add(Rect.fromCenter(center: Offset(34.0 + k * 21 - 66, y - 62), width: rx * 2, height: ry * 2));
    }
  }
  final List<Rect> ovals = [];
  static final top = Rect.fromCenter(center: const Offset(62.0 - 66, 39.0 - 62), width: 82, height: 42);
}

final List<_FogShape> _fogShapes = [for (var v = 0; v < 8; v++) _FogShape(101 + v * 17)];

class MapPainter extends CustomPainter {
  MapPainter(this.g, this.cam, Listenable repaint) : super(repaint: repaint);
  final Game g;
  final Camera cam;

  static final _fill = Paint()..isAntiAlias = true;
  static final _img = Paint()..filterQuality = FilterQuality.medium;
  static final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  // 첫 동네 풍경 (웹 LANDSCAPES.home)
  static const bgTop = Color(0xFF25323F), bgBottom = Color(0xFF1B2631), voidCol = Color(0xFF1C2733);
  static const fog0 = Color(0xFF283643), fog1 = Color(0xFF354351);
  static const fogTop0 = Color(0x0D718391), fogTop1 = Color(0x14C4AD81);
  static const soil = [0x8A, 0x8C, 0x80], ruin = [0x76, 0x7B, 0x78], green = [0x71, 0x82, 0x72], paving = [0x9E, 0x9C, 0x8A];
  static const w1 = [0x2A, 0x66, 0x82], w2 = [0x35, 0x7D, 0x98];

  static List<double> _lerp(List<num> a, List<num> b, double t) => [for (var k = 0; k < 3; k++) (a[k] + (b[k] - a[k]) * t).toDouble()];
  static Color _rgb(List<num> a, [double k = 1]) => Color.fromARGB(255, math.min(255, a[0] * k).floor(), math.min(255, a[1] * k).floor(), math.min(255, a[2] * k).floor());

  /// 웹 groundCol (6327 재정의)
  Color groundCol(int i, int t, double gr, bool paved) {
    final n = groundNoise[i];
    return _rgb(paved ? paving : _lerp(t == T.ruin ? ruin : soil, green, math.min(.6, gr * .65)), 1 + n * .045);
  }

  Color waterCol(int i) => _rgb(_lerp(w1, w2, (.5 + groundNoise[i] * .6).clamp(0, 1).toDouble()));

  final List<(Offset, double, Color, double)> _glows = [];

  bool _nearRev(int i) {
    final x = i % W, y = i ~/ W;
    for (var dy = -2; dy <= 2; dy++) {
      final yy = y + dy;
      if (yy < 0 || yy >= H) continue;
      for (var dx = -2; dx <= 2; dx++) {
        final xx = x + dx;
        if (xx >= 0 && xx < W && g.S.rev[yy * W + xx] == 1) return true;
      }
    }
    return false;
  }

  /// 칸 안의 상대 위치 (웹 P(u,v,z))
  static Offset P(int i, double u, double v, [double z = 0]) {
    final x = i % W, y = i ~/ W;
    return Offset((x + u - y - v) * TW / 2, (x + u + y + v) * TH / 2 - z);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.clipRect(rect);
    canvas.drawRect(rect, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), const [bgTop, bgBottom]));
    _glows.clear();
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(cam.z);
    canvas.translate(-cam.x, -cam.y);
    final tl = Offset(cam.x - (size.width / 2 + 80) / cam.z, cam.y - (size.height / 2 + 40) / cam.z);
    final br = Offset(cam.x + (size.width / 2 + 80) / cam.z, cam.y + (size.height / 2 + 260) / cam.z);
    final S = g.S;
    for (var s = 0; s <= W + H - 2; s++) {
      final wy = (s + 1) * TH / 2;
      if (wy < tl.dy - 10 || wy > br.dy) continue;
      for (var x = math.max(0, s - H + 1); x <= math.min(W - 1, s); x++) {
        final y = s - x, wx = (x - y) * TW / 2;
        if (wx < tl.dx - TW || wx > br.dx + TW) continue;
        final i = y * W + x;
        if (S.rev[i] == 1) {
          _landTile(canvas, i, x, y);
        } else {
          _fogTile(canvas, i, x, y);
        }
      }
    }
    if (g.sel >= 0) {
      final c = tileC(g.sel);
      _line
        ..color = const Color(0xE6FFCF7A)
        ..strokeWidth = 2.5;
      final pts = [Offset(c.dx, c.dy - TH / 2), Offset(c.dx + TW / 2, c.dy), Offset(c.dx, c.dy + TH / 2), Offset(c.dx - TW / 2, c.dy)];
      for (var k = 0; k < 4; k++) {
        final a = pts[k], b = pts[(k + 1) % 4], len = (b - a).distance;
        for (var d = 0.0; d < len; d += 14) {
          canvas.drawLine(a + (b - a) * (d / len), a + (b - a) * (math.min(len, d + 8) / len), _line);
        }
      }
    }
    if (g.aimValid) _aim(canvas);
    // 불빛 (웹 glowPts, 더하기 합성)
    for (final (c, r, col, a) in _glows) {
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = ui.Gradient.radial(c, r, [col.withValues(alpha: math.min(.85, a * .75)), col.withValues(alpha: 0)]));
    }
    canvas.restore();
    // 가장자리 어둡게 (웹 비네트)
    final c = size.center(Offset.zero), mn = math.min(size.width, size.height), mx = math.max(size.width, size.height);
    canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(c, mx * .75, const [Color(0x00000000), Color(0x00000000), Color(0x80000000)], [0, (mn * .35) / (mx * .75), 1]));
  }

  Path _diamond(Offset c, [double k = 1]) => Path()
    ..moveTo(c.dx, c.dy - TH / 2 * k)
    ..lineTo(c.dx + TW / 2 * k, c.dy)
    ..lineTo(c.dx, c.dy + TH / 2 * k)
    ..lineTo(c.dx - TW / 2 * k, c.dy)
    ..close();

  /// 그림을 칸 중심 기준으로: 가로 width, 바닥에서 dy만큼 내려 놓고 높이의 anchor만큼 올림
  double _sprite(Canvas canvas, ui.Image? img, Rect? src, Offset base, double width, double anchorY, {double dy = 0, double alpha = 1}) {
    if (img == null || src == null) return 0;
    final h = width * src.height / src.width;
    _img.color = Color.fromRGBO(255, 255, 255, alpha);
    canvas.drawImageRect(img, src, Rect.fromLTWH(base.dx - width / 2, base.dy + dy - h * anchorY, width, h), _img);
    return h;
  }

  void _landTile(Canvas canvas, int i, int x, int y) {
    final S = g.S, t = S.ter[i], c = tileC(i);
    final mod = g.modAtTile(i), core = i == C0;
    _fill.color = t == T.water ? waterCol(i) : groundCol(i, t, g.green[i], core || mod != null);
    canvas.drawPath(_diamond(c, 1.02), _fill);
    // 구름과 맞닿은 가장자리는 그늘 (웹 edgeFade)
    final n = Offset(c.dx, c.dy - TH / 2), e = Offset(c.dx + TW / 2, c.dy), s = Offset(c.dx, c.dy + TH / 2), w = Offset(c.dx - TW / 2, c.dy);
    final edges = [
      if (x > 0 && S.rev[i - 1] == 0) (n, w),
      if (x < W - 1 && S.rev[i + 1] == 0) (e, s),
      if (y > 0 && S.rev[i - W] == 0) (n, e),
      if (y < H - 1 && S.rev[i + W] == 0) (w, s),
    ];
    if (edges.isNotEmpty) {
      canvas.save();
      canvas.clipPath(_diamond(c));
      for (final (a, b) in edges) {
        _line
          ..color = const Color(0x2E140C06)
          ..strokeWidth = 18;
        canvas.drawLine(a, b, _line);
        _line
          ..color = const Color(0x4D140C06)
          ..strokeWidth = 8;
        canvas.drawLine(a, b, _line);
      }
      canvas.restore();
    }
    if (t == T.water) return;

    if (core) {
      final lv = S.lv;
      _sprite(canvas, Atlas.image('shelters.webp'), Atlas.cell('shelters.webp', lv - 1, 3, 2), c, const [84.0, 84.0, 90.0, 100.0, 112.0][lv - 1], .91);
      _glows.add((P(i, .5, .5, 16), 42.0 + lv * 3, const Color(0xFFF0C071), .38));
      return;
    }
    if (mod != null) {
      final idx = modOrder.indexOf(mod.id);
      if (mod.l >= 1 && Atlas.image('module-upgrades.webp') != null) {
        final w = mod.id == 8 ? 40.0 + mod.l * 4 : mod.id == 7 ? 78.0 + mod.l * 3 : 76.0 + mod.l * 3;
        _sprite(canvas, Atlas.image('module-upgrades.webp'), Atlas.fr(Atlas.moduleUpFrames[idx * 2 + math.min(1, mod.l - 1)]), c, w, 1, dy: 8);
      } else {
        _sprite(canvas, Atlas.image('modules.webp'), Atlas.cell('modules.webp', idx, 3, 3), c, (mod.id == 8 || mod.id == 7 ? 94.0 : 78.0) + mod.l * 3, .9);
      }
      if (mod.l > 0) {
        final p = P(i, .5, .8, 1);
        _fill.color = const Color(0xFFEFC77F);
        for (var k = 0; k < mod.l; k++) {
          canvas.drawRect(Rect.fromLTWH(p.dx - 3 + k * 4, p.dy, 2, 2), _fill);
        }
      }
      if (mod.id == 8) _glows.add((P(i, .5, .5, 34), 34.0, const Color(0xFFF0C071), .42));
      if (mod.id == 5 && g.have('fuel') > 0) _glows.add((P(i, .5, .5, 12), 22.0, const Color(0xFFF0C071), .42));
      return;
    }
    final camp = S.camp[i];
    if (camp != null) {
      final hp = (camp['hp'] as num?) ?? 0, mx = (camp['max'] as num?) ?? 1;
      _prop(canvas, hp > 0 ? 1 : 0, c);
      final p = P(i, .5, .5, hp > 0 ? 34 : 30);
      if (hp > 0) {
        canvas.drawRect(
            Rect.fromLTWH(p.dx - 2, p.dy - 80, 4, 80),
            Paint()
              ..blendMode = BlendMode.plus
              ..shader = ui.Gradient.linear(p, p.translate(0, -80), const [Color(0x99C8E6FF), Color(0x00C8E6FF)]));
      }
      final y = p.dy - 8;
      _fill.color = hp > 0 ? const Color(0xFFE8F4FF) : const Color(0xFFFFCF7A);
      canvas.drawCircle(Offset(p.dx, y), 9, _fill);
      _line
        ..color = const Color(0xFF3B2A1A)
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(p.dx, y), 9, _line);
      final tp = TextPainter(text: TextSpan(text: hp > 0 ? '!' : '?', style: const TextStyle(fontSize: 12, color: Color(0xFF3B2A1A), fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, y - tp.height / 2));
      if (hp > 0) {
        _fill.color = const Color(0xBF0D0B08);
        canvas.drawRect(Rect.fromLTWH(p.dx - 20, y + 13, 40, 5), _fill);
        _fill.color = const Color(0xFFCFE6FF);
        canvas.drawRect(Rect.fromLTWH(p.dx - 19, y + 14, 38 * (1 - hp / mx).clamp(0.0, 1.0).toDouble(), 3), _fill);
      }
      return;
    }
    if (t == T.lm) {
      final l = S.lm[i];
      if (l != null) {
        final f = Atlas.fr(Atlas.landmarkFrames[l.k + (l.ok ? 5 : 0)]);
        final h = _sprite(canvas, Atlas.image('landmarks.webp'), f, c, Atlas.landmarkWidth[l.k], 1, dy: 8);
        if (l.ok) {
          _glows.add((c.translate(0, -12), 28.0, const Color(0xFFF0C071), .28));
        } else {
          _lmMarker(canvas, c.dx, c.dy - (math.max(10, h - 16) + 14));
        }
      }
      return;
    }
    final site = S.site[i];
    final live = site != null && site.c > 0;
    final kind = t == T.car ? 0 : t == T.ruin ? 1 : t == T.crate ? 2 : -1;
    if (kind >= 0) {
      final v = (((speck[i] * 7.31 + speck2[i] * 3.17) % 1) * 5).floor();
      final f = Atlas.fr(Atlas.siteFrames[kind * 6 + (live ? math.min(4, v) : 5)]);
      _sprite(canvas, Atlas.image('exploration-sites.webp'), f, c, live ? (kind == 0 ? 60.0 : 62.0) : 54.0, 1, dy: 8);
      return;
    }
    if (t == T.silo) {
      final v = (((speck[i] * 7.31 + speck2[i] * 3.17) % 1) * 3).floor();
      _prop(canvas, 4 + v, c, alpha: live ? 1 : .55);
      if (live) _glows.add((c, 18.0, const Color(0xFFFFC86E), .3));
      return;
    }
    if (site != null && site.k == 'rubble') {
      _prop(canvas, live ? 2 : 3, c);
      return;
    }
    // 빈 땅: 쉘터 가까이 나무, 군데군데 풀·자갈 (웹 tree / groundDecor)
    final gr = g.green[i];
    final trees = speck2[i] > .45 ? (gr * 2.5).floor() : 0;
    for (var k = 0; k < trees; k++) {
      _tree(canvas, P(i, .2 + ((speck[i] * 97 + k * .37) % 1) * .6, .2 + ((speck2[i] * 53 + k * .61) % 1) * .6), (k + i) % 3 == 0);
    }
    if ((trees == 0 || gr > .3) && speck[i] > .75) {
      final p = P(i, .3 + speck2[i] * .4, .35 + speck[i] * .3);
      _fill.color = gr > .2 ? const Color(0xFF6E8466) : const Color(0xFF7A7C72);
      canvas.drawOval(Rect.fromCenter(center: p, width: 6, height: 3), _fill);
      canvas.drawOval(Rect.fromCenter(center: p.translate(5, 2), width: 4, height: 2), _fill);
    }
  }

  void _tree(Canvas canvas, Offset p, bool dark) {
    _fill.color = const Color(0x40192019);
    canvas.drawOval(Rect.fromCenter(center: p.translate(2, 1), width: 13, height: 5), _fill);
    _fill.color = const Color(0xFF5A4433);
    canvas.drawRect(Rect.fromLTWH(p.dx - 1, p.dy - 6, 2, 6), _fill);
    _fill.color = dark ? const Color(0xFF4F6B4A) : const Color(0xFF5F7D55);
    canvas.drawOval(Rect.fromCenter(center: p.translate(0, -10), width: 13, height: 12), _fill);
    _fill.color = dark ? const Color(0xFF5F7D55) : const Color(0xFF738F62);
    canvas.drawOval(Rect.fromCenter(center: p.translate(-1.5, -12), width: 7, height: 6), _fill);
  }

  void _lmMarker(Canvas canvas, double x, double top) {
    canvas.drawRect(
        Rect.fromLTWH(x - 2, top - 90, 4, 90),
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(Offset(x, top), Offset(x, top - 90), const [Color(0x8CFFD26E), Color(0x00FFD26E)]));
    final y = top - 10;
    _fill.color = const Color(0xFFFFD24A);
    canvas.drawCircle(Offset(x, y), 9, _fill);
    _line
      ..color = const Color(0xFF3B2A1A)
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(x, y), 9, _line);
    final tp = TextPainter(text: const TextSpan(text: '★', style: TextStyle(fontSize: 11, color: Color(0xFF3B2A1A), fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2 + .5));
  }

  void _prop(Canvas canvas, int id, Offset c, {double alpha = 1}) {
    final f = Atlas.fr(Atlas.propFrames[id]);
    _sprite(canvas, Atlas.image('settlement-props.webp'), f, c, Atlas.propWidth[id], 1, dy: 5, alpha: alpha);
  }

  void _fogTile(Canvas canvas, int i, int x, int y) {
    final S = g.S, c = tileC(i);
    final fr = g.frontier.contains(i);
    _fill.color = voidCol;
    canvas.drawPath(_diamond(c, 1.02), _fill);
    // 구름 덩이: 경계와 밝힌 땅 가까이는 칸마다, 먼 곳은 한 칸 건너 하나씩
    if (fr || (x + y) % 2 == 0 || _nearRev(i)) {
      final o = Offset(c.dx, c.dy - 11);
      final shape = _fogShapes[(speck[i] * 8).floor()];
      _fill.color = fr ? fog1 : fog0;
      for (final r in shape.ovals) {
        canvas.drawOval(r.shift(o), _fill);
      }
      _fill.color = fr ? fogTop1 : fogTop0;
      canvas.drawOval(_FogShape.top.shift(o), _fill);
    }
    // 구름 속 발견물 반짝임 (웹 drawHint): 밝힌 땅 가까이, 또는 지도 스케치(hintT) 동안 전부
    final t = S.ter[i];
    if (t >= T.car && t <= T.lm && ((S.rest['hintT'] as num?) ?? 0) > 0 || (t >= T.car && t < T.lm && _nearRev(i))) {
      final p = P(i, .5, .5, 22), a = .45 + .5 * speck[i];
      final col = t == T.crate ? const Color(0xFFFFC86E) : t == T.trace ? const Color(0xFFFFE678) : t == T.lm ? const Color(0xFFFFD24A) : const Color(0xFFDCEBF5);
      final r = 4 + a * 3;
      _line
        ..color = col.withValues(alpha: a)
        ..strokeWidth = 1.6;
      canvas.drawLine(p.translate(-r, 0), p.translate(r, 0), _line);
      canvas.drawLine(p.translate(0, -r), p.translate(0, r), _line);
      _glows.add((p, 14.0, col, a * .6));
    }
    // 구조 신호: 하늘로 솟는 빛줄기
    if (S.sig.containsKey(i)) {
      final p = P(i, .5, .5, 18);
      final add = Paint()..blendMode = BlendMode.plus;
      add.shader = ui.Gradient.linear(p, p.translate(0, -110), const [Color(0xBFC8E6FF), Color(0x00C8E6FF)]);
      canvas.drawRect(Rect.fromLTWH(p.dx - 3, p.dy - 110, 6, 110), add);
      add.shader = null;
      add.color = const Color(0x2EC8E6FF);
      canvas.drawRect(Rect.fromLTWH(p.dx - 9, p.dy - 80, 18, 80), add);
      _glows.add((p, 34.0, const Color(0xFFBEDCFF), .9));
      _fill.color = const Color(0xFFE8F4FF);
      canvas.drawCircle(p, 2.5, _fill);
    }
    if (fr) {
      // 밝힌 땅과 맞닿은 변을 등불색으로
      final a = i == g.aim ? .65 : .18;
      _line
        ..color = Color.fromRGBO(235, 189, 112, a)
        ..strokeWidth = 2;
      final n = Offset(c.dx, c.dy - TH / 2), e = Offset(c.dx + TW / 2, c.dy), s = Offset(c.dx, c.dy + TH / 2), w = Offset(c.dx - TW / 2, c.dy);
      if (x > 0 && S.rev[i - 1] == 1) canvas.drawLine(n, w, _line);
      if (x < W - 1 && S.rev[i + 1] == 1) canvas.drawLine(e, s, _line);
      if (y > 0 && S.rev[i - W] == 1) canvas.drawLine(n, e, _line);
      if (y < H - 1 && S.rev[i + W] == 1) canvas.drawLine(w, s, _line);
      // 두드린 만큼 금이 간 빛
      final hp = S.hp[i];
      if (hp >= 0) {
        final mh = g.maxHp(i), dmg = (1 - hp / mh).clamp(0.0, 1.0).toDouble();
        if (dmg > 0) {
          final p = Offset(c.dx, c.dy - 14);
          final r = 10 + dmg * 26;
          canvas.drawCircle(
              p,
              r,
              Paint()
                ..blendMode = BlendMode.plus
                ..shader = ui.Gradient.radial(p, r, [Color.fromRGBO(255, 200, 110, .4 + dmg * .35), const Color(0x00FF9632)]));
          _line
            ..color = const Color(0xD9FFDC96)
            ..strokeWidth = 1.4;
          for (var k = 0; k < (dmg * 7).ceil(); k++) {
            final an = speck[i] * 6 + k * .9, l1 = 6 + dmg * 9, l2 = l1 + 5 + dmg * 9;
            final path = Path()
              ..moveTo(p.dx, p.dy)
              ..lineTo(p.dx + math.cos(an) * l1, p.dy + math.sin(an) * l1 * .6)
              ..lineTo(p.dx + math.cos(an + .3) * l2, p.dy + math.sin(an + .3) * l2 * .6);
            canvas.drawPath(path, _line);
          }
        }
      }
    }
  }

  /// 조준 표시 (웹 draw의 aimValid 부분): 점선 타원 + 네 방향 눈금 + 남은 체력 막대
  void _aim(Canvas canvas) {
    final S = g.S, aim = g.aim;
    final camp = S.rev[aim] == 1 ? S.camp[aim] : null;
    final site = S.rev[aim] == 1 && camp == null ? S.site[aim] : null;
    final c = tileC(aim, site != null || camp != null ? 8 : 14);
    const r = 20.0;
    final col = site != null ? const Color(0xF2BEE696) : const Color(0xF2FFDC96);
    _line
      ..color = col
      ..strokeWidth = 2.2;
    const rx = r * 1.4, ry = r * .8;
    // 점선: 둘레를 따라 7 그리고 5 비우기
    var ang = 0.0;
    var on = true;
    while (ang < math.pi * 2) {
      final step = (on ? 7.0 : 5.0) / math.sqrt(math.pow(rx * math.sin(ang), 2) + math.pow(ry * math.cos(ang), 2) + 1e-6);
      if (on) {
        final path = Path();
        for (var a = ang; a <= ang + step + 1e-9; a += step / 4) {
          final p = c + Offset(math.cos(a) * rx, math.sin(a) * ry);
          if (a == ang) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        canvas.drawPath(path, _line);
      }
      ang += step;
      on = !on;
    }
    _line.strokeWidth = 2.6;
    for (final (a, b) in const [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)]) {
      canvas.drawLine(c + Offset(a * (rx + 3), b * (ry + 3)), c + Offset(a * (rx + 10), b * (ry + 8)), _line);
    }
    const bw = 46.0;
    double f;
    if (camp != null) {
      f = ((camp['hp'] as num?) ?? 0) / ((camp['max'] as num?) ?? 1);
    } else if (site != null) {
      f = site.hp / g.siteHp(site);
    } else {
      final mh = g.maxHp(aim), cur = S.hp[aim] < 0 ? mh.toDouble() : S.hp[aim];
      f = cur / mh;
    }
    _fill.color = const Color(0xBF0D0B08);
    canvas.drawRect(Rect.fromLTWH(c.dx - bw / 2 - 2, c.dy - r - 22, bw + 4, 8), _fill);
    _fill.color = site != null ? const Color(0xFF9FCF6A) : const Color(0xFFF3A53A);
    canvas.drawRect(Rect.fromLTWH(c.dx - bw / 2, c.dy - r - 20, bw * f.clamp(0.0, 1.0).toDouble(), 4), _fill);
    if (site != null) {
      final mx = site.max;
      for (var q = 0; q < mx; q++) {
        _fill.color = q < site.c ? const Color(0xFFFFD98A) : const Color(0x33FFFFFF);
        canvas.drawRect(Rect.fromLTWH(c.dx - bw / 2 + q * (bw / mx), c.dy - r - 12, bw / mx - 1.5, 3), _fill);
      }
    }
  }

  @override
  bool shouldRepaint(MapPainter old) => false;
}

// ======================= 연출(파티클·떠오르는 글자) =======================
class _Particle {
  _Particle(this.p, this.v, this.color, this.life, {this.text}) : max = life;
  Offset p, v;
  final int color;
  double life;
  final double max;
  final String? text;
  final double size = 3;
}

class FxLayerController extends ChangeNotifier {
  final List<_Particle> parts = [];
  final List<(String, double)> toasts = [];
  Size viewSize = Size.zero;
  final math.Random _r = math.Random();
  void Function(Fx fx)? onFx;

  void toast(String t) {
    toasts.add((t, 2.6));
    if (toasts.length > 3) toasts.removeAt(0);
    notifyListeners();
  }

  /// 게임에서 나온 연출 신호를 받아 파티클로 바꾼다.
  void pull(Game g) {
    for (final f in g.takeFx()) {
      switch (f) {
        case FxBurst(:final tile, :final color, :final n):
          final c = tileC(tile, 12);
          for (var k = 0; k < math.min(n, 16); k++) {
            final a = _r.nextDouble() * math.pi * 2, sp = 20 + _r.nextDouble() * 50;
            parts.add(_Particle(c, Offset(math.cos(a) * sp, math.sin(a) * sp * .6 - 40), color, .5 + _r.nextDouble() * .3));
          }
        case FxFloat(:final tile, :final text, :final color, :final rise):
          final c = tileC(tile, rise);
          parts.add(_Particle(c, const Offset(0, -26), color, 1.1, text: text));
        case FxToast(:final text):
          toast(text);
        default:
          onFx?.call(f);
      }
    }
    if (parts.length > 160) parts.removeRange(0, parts.length - 160);
    notifyListeners();
  }

  /// 연출을 dt초 진행. 남은 게 있으면 true.
  bool step(double dt) {
    for (final p in parts) {
      p.p += p.v * dt;
      if (p.text == null) p.v = Offset(p.v.dx * .96, p.v.dy + 160 * dt);
      p.life -= dt;
    }
    parts.removeWhere((p) => p.life <= 0);
    for (var k = 0; k < toasts.length; k++) {
      toasts[k] = (toasts[k].$1, toasts[k].$2 - dt);
    }
    toasts.removeWhere((t) => t.$2 <= 0);
    return parts.isNotEmpty || toasts.isNotEmpty;
  }
}

class FxLayer extends StatefulWidget {
  const FxLayer({super.key, required this.controller, required this.camera});
  final FxLayerController controller;
  final Camera camera;
  @override
  State<FxLayer> createState() => _FxLayerState();
}

class _FxLayerState extends State<FxLayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_wake);
  }

  void _wake() {
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
    setState(() {});
  }

  void _onTick(Duration t) {
    final dt = _last == Duration.zero ? 1 / 60 : (t - _last).inMicroseconds / 1e6;
    _last = t;
    final alive = widget.controller.step(dt.clamp(0.0, .1).toDouble());
    setState(() {});
    if (!alive) _ticker.stop(); // 연출이 끝나면 프레임을 완전히 멈춘다
  }

  @override
  void dispose() {
    widget.controller.removeListener(_wake);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return IgnorePointer(
      child: Stack(fit: StackFit.expand, children: [
        CustomPaint(painter: _FxPainter(c, widget.camera)),
        Positioned(
          left: 55,
          right: 55,
          top: 96,
          child: Column(children: [
            for (final (t, life) in c.toasts)
              Opacity(
                opacity: life.clamp(0, .3) / .3,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xE620160E),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0x29EFE3C4)),
                    boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 12, offset: Offset(0, 5))],
                  ),
                  child: Text(t, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ttc.t(13, color: const Color(0xFFF1E5C6), height: 1.4)),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _FxPainter extends CustomPainter {
  _FxPainter(this.c, this.cam);
  final FxLayerController c;
  final Camera cam;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(cam.z);
    canvas.translate(-cam.x, -cam.y);
    final paint = Paint();
    for (final p in c.parts) {
      final a = (p.life / p.max).clamp(0.0, 1.0).toDouble();
      if (p.text != null) {
        final tp = TextPainter(
          text: TextSpan(text: p.text, style: Ttc.t(17 / math.max(.8, cam.z), color: Color(p.color).withValues(alpha: a), weight: FontWeight.w700).copyWith(shadows: [Shadow(color: Color.fromRGBO(13, 11, 8, a * .8), blurRadius: 2)])),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, p.p - Offset(tp.width / 2, tp.height / 2));
      } else {
        paint.color = Color(p.color).withValues(alpha: a);
        canvas.drawCircle(p.p, p.size * (.5 + a * .5), paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FxPainter old) => true;
}
