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
import 'atlas.dart';
import 'theme.dart';

class Camera extends ChangeNotifier {
  double x = 0, y = (CX + CY + 1) * TH / 2 - 10, z = 1.4;
  void set(double nx, double ny, [double? nz]) {
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
  const MapView({super.key, required this.game, required this.camera, required this.onSelect, required this.fxLayer});
  final Game game;
  final Camera camera;
  final void Function(String kind, int tile) onSelect;
  final FxLayerController fxLayer;

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
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: (e) => _up(e),
        onPointerCancel: (e) => _up(e, cancel: true),
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) cam.set(cam.x, cam.y, cam.z * math.exp(-e.scrollDelta.dy * .0015));
        },
        child: Stack(fit: StackFit.expand, children: [
          RepaintBoundary(child: CustomPaint(painter: MapPainter(g, cam, Listenable.merge([g.mapVersion, cam])))),
          RepaintBoundary(child: FxLayer(controller: widget.fxLayer, camera: cam)),
        ]),
      );
    });
  }
}

// ======================= 지도 그리기 =======================
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
  static const fogA = Color(0xFF283643), fogB = Color(0xFF354351);
  static const cD = [0x63, 0x55, 0x3F], cR = [0x5B, 0x50, 0x47], cGD = [0x5B, 0x8A, 0x3D], cGL = [0x8F, 0xB3, 0x58], cM = [0x76, 0x67, 0x4F], cM2 = [0x8A, 0x78, 0x58];
  static const w1 = [0x2A, 0x66, 0x82], w2 = [0x35, 0x7D, 0x98];

  static List<double> _lerp(List<num> a, List<num> b, double t) => [for (var k = 0; k < 3; k++) (a[k] + (b[k] - a[k]) * t).toDouble()];
  static Color _rgb(List<double> a, [double k = 1]) => Color.fromARGB(255, math.min(255, a[0] * k).floor(), math.min(255, a[1] * k).floor(), math.min(255, a[2] * k).floor());

  Color groundCol(int i, int t, double gr, bool paved) {
    final n = groundNoise[i];
    List<double> c;
    if (paved) {
      c = _lerp(cM, cM2, .25 + speck[i] * .5);
    } else {
      final grass = _lerp(cGD, cGL, (.5 + n * .8).clamp(0, 1).toDouble());
      c = _lerp(t == T.ruin ? cR : cD, grass, math.min(1.0, gr * .95));
    }
    return _rgb(c, 1 + n * .08);
  }

  Color waterCol(int i) => _rgb(_lerp(w1, w2, (.5 + groundNoise[i] * .6).clamp(0, 1).toDouble()));

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), const [bgTop, bgBottom]));
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(cam.z);
    canvas.translate(-cam.x, -cam.y);
    final tl = Offset(cam.x - size.width / 2 / cam.z, cam.y - size.height / 2 / cam.z);
    final br = Offset(cam.x + size.width / 2 / cam.z, cam.y + size.height / 2 / cam.z + 140);
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
    // 조준 표시
    if (g.aim >= 0 && g.aimValid) {
      final c = tileC(g.aim);
      _line
        ..color = const Color(0xCCFFCF7A)
        ..strokeWidth = 2;
      canvas.drawPath(_diamond(c, .92), _line);
    }
    canvas.restore();
  }

  Path _diamond(Offset c, [double k = 1]) => Path()
    ..moveTo(c.dx, c.dy - TH / 2 * k)
    ..lineTo(c.dx + TW / 2 * k, c.dy)
    ..lineTo(c.dx, c.dy + TH / 2 * k)
    ..lineTo(c.dx - TW / 2 * k, c.dy)
    ..close();

  void _sprite(Canvas canvas, ui.Image? img, Rect? src, Offset base, double width, double anchorY, {double dy = 0, double alpha = 1}) {
    if (img == null || src == null) return;
    final h = width * src.height / src.width;
    _img.color = Color.fromRGBO(255, 255, 255, alpha);
    canvas.drawImageRect(img, src, Rect.fromLTWH(base.dx - width / 2, base.dy + dy - h * anchorY, width, h), _img);
  }

  void _landTile(Canvas canvas, int i, int x, int y) {
    final S = g.S, t = S.ter[i], c = tileC(i);
    final mod = g.modAtTile(i), core = i == C0;
    _fill.color = t == T.water ? waterCol(i) : groundCol(i, t, g.green[i], core || mod != null);
    canvas.drawPath(_diamond(c, 1.02), _fill);
    // 구름과 맞닿은 가장자리는 어둡게
    final dark = Paint()
      ..color = const Color(0x40140C06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    final n = Offset(c.dx, c.dy - TH / 2), e = Offset(c.dx + TW / 2, c.dy), s = Offset(c.dx, c.dy + TH / 2), w = Offset(c.dx - TW / 2, c.dy);
    if (x > 0 && S.rev[i - 1] == 0) canvas.drawLine(n, w, dark);
    if (x < W - 1 && S.rev[i + 1] == 0) canvas.drawLine(e, s, dark);
    if (y > 0 && S.rev[i - W] == 0) canvas.drawLine(n, e, dark);
    if (y < H - 1 && S.rev[i + W] == 0) canvas.drawLine(w, s, dark);
    if (t == T.water) return;

    if (core) {
      final lv = S.lv;
      _sprite(canvas, Atlas.image('shelters.webp'), Atlas.cell('shelters.webp', lv - 1, 3, 2), c, const [84.0, 84.0, 90.0, 100.0, 112.0][lv - 1], .91);
      return;
    }
    if (mod != null) {
      final idx = modOrder.indexOf(mod.id);
      _sprite(canvas, Atlas.image('modules.webp'), Atlas.cell('modules.webp', idx, 3, 3), c, (mod.id == 8 || mod.id == 7 ? 94.0 : 78.0) + mod.l * 3, .9);
      return;
    }
    final camp = S.camp[i];
    if (camp != null) {
      final live = ((camp['hp'] as num?) ?? 0) > 0;
      _prop(canvas, live ? 1 : 0, c);
      return;
    }
    if (t == T.lm) {
      final l = S.lm[i];
      if (l != null) {
        final f = Atlas.fr(Atlas.landmarkFrames[l.k + (l.ok ? 5 : 0)]);
        _sprite(canvas, Atlas.image('landmarks.webp'), f, c, Atlas.landmarkWidth[l.k], 1, dy: 8);
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
      return;
    }
    if (site != null && site.k == 'rubble') {
      _prop(canvas, live ? 2 : 3, c);
      return;
    }
    // 빈 땅: 쉘터 가까이는 풀
    final gr = g.green[i];
    if (gr > .3 && speck2[i] > .45) {
      _fill.color = const Color(0xFF6E9A48);
      for (var k = 0; k < (gr * 2.5).floor(); k++) {
        final u = .2 + ((speck[i] * 97 + k * .37) % 1) * .6, v = .2 + ((speck2[i] * 53 + k * .61) % 1) * .6;
        final p = Offset(c.dx + (u - v) * TW / 2, c.dy - TH / 2 + (u + v) * TH / 2);
        canvas.drawOval(Rect.fromCenter(center: p.translate(0, -3), width: 7, height: 9), _fill);
      }
    }
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
    // 구름 덩이: 경계는 밝게, 안쪽은 한 칸 건너 하나씩
    if (fr || (x + y) % 2 == 0) {
      final cc = Offset(c.dx, c.dy - 11);
      final k = fr ? 1.0 : .82;
      _fill.color = Color.lerp(fogA, fogB, speck[i])!.withValues(alpha: k);
      canvas.drawOval(Rect.fromCenter(center: cc.translate(-10, 3), width: 46, height: 26), _fill);
      canvas.drawOval(Rect.fromCenter(center: cc.translate(12, 2), width: 42, height: 24), _fill);
      _fill.color = Color.lerp(fogB, const Color(0xFF4A596A), fr ? .55 : .15)!.withValues(alpha: k);
      canvas.drawOval(Rect.fromCenter(center: cc.translate(1 + speck2[i] * 6 - 3, -5), width: 40, height: 24), _fill);
    }
    // 구조 신호: 하늘로 솟는 빛줄기
    if (S.sig.containsKey(i)) {
      final p = Offset(c.dx, c.dy - 18);
      canvas.drawRect(Rect.fromLTWH(p.dx - 3, p.dy - 110, 6, 110),
          Paint()..shader = ui.Gradient.linear(p, p.translate(0, -110), const [Color(0xBFC8E6FF), Color(0x00C8E6FF)]));
      _fill.color = const Color(0xFFE8F4FF);
      canvas.drawCircle(p, 2.5, _fill);
    }
    if (fr) {
      // 밝힌 땅과 맞닿은 변을 등불색으로
      final a = i == g.aim ? .65 : .22;
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
          canvas.drawCircle(
              p,
              10 + dmg * 26,
              Paint()
                ..shader = ui.Gradient.radial(p, 10 + dmg * 26, [Color.fromRGBO(255, 200, 110, .4 + dmg * .35), const Color(0x00FF9632)]));
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
          left: 0,
          right: 0,
          top: 96,
          child: Column(children: [
            for (final (t, life) in c.toasts)
              Opacity(
                opacity: life.clamp(0, .3) / .3,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Ttc.paper, boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 4))]),
                  child: Text(t, textAlign: TextAlign.center, style: Ttc.body(15, color: Ttc.sepia, weight: FontWeight.w600)),
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
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(cam.z);
    canvas.translate(-cam.x, -cam.y);
    final paint = Paint();
    for (final p in c.parts) {
      final a = (p.life / p.max).clamp(0.0, 1.0).toDouble();
      if (p.text != null) {
        final tp = TextPainter(
          text: TextSpan(text: p.text, style: Ttc.body(14 / math.max(.8, cam.z) * 1.2, color: Color(p.color).withValues(alpha: a), weight: FontWeight.w700, shadow: true)),
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
