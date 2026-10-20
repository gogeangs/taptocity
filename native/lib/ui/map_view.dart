// 안개 지도. 웹과 달리 화면을 쉬지 않고 다시 그리지 않는다:
//  - 지도(땅·건물·구름)는 지도 번호(mapVersion)나 카메라가 바뀔 때만 그린다.
//  - 반짝임·떠오르는 글자 같은 연출은 남아 있는 동안에만 따로 그린다. 없으면 0fps.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../game/data.dart';
import '../game/engine.dart';
import '../game/rng.dart';
import '../game/state.dart';
import 'atlas.dart';
import 'live.dart';
import 'people.dart';
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
  const MapView({super.key, required this.game, required this.camera, required this.onSelect, required this.fxLayer, this.onTouch, this.onPlace});
  final Game game;
  /// 장식 놓는 중이면 누른 칸을 넘긴다
  final void Function(int tile)? onPlace;
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
  bool def = false;
  int site = -1;
  int digging = -1;
  int r0 = 0;
  Timer? hold;
}

const holdMax = 30;

class _MapViewState extends State<MapView> {
  final Map<int, _Ptr> ptrs = {};
  late final Life life = Life(widget.game);
  final Map<String, int> _petPatT = {};
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

  /// 눌린 곳의 붉은 재 (웹 ashAt)
  int ashAt(Offset p) {
    final under = pickTile(toWorld(p));
    if (under >= 0 && g.S.ash.containsKey('$under')) return under;
    final r = TW * .3 * cam.z;
    var best = -1;
    var bd = r * r;
    for (final k in g.S.ash.keys) {
      final d = (toScreen(tileC(int.parse(k), 10)) - p).distanceSquared;
      if (d < bd) {
        bd = d;
        best = int.parse(k);
      }
    }
    return best;
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
    // 두 사람 말풍선 ▸: 대화 전체 듣기 (웹 openChat). 웹처럼 누르는 순간 먼저 본다 —
    // 말풍선이 구름·폐허 위에 떠 있어도 그 칸을 두드리지 않고 대화가 열리게
    final bb = life.bubbleRect, ch = life.chat;
    if (widget.onPlace == null && bb != null && ch != null && !ch.solo && bb.inflate(6).contains(p.pos)) {
      p.acted = true;
      life.chat = null;
      life.bubbleRect = null;
      g.openChat(ch.a, ch.b, ch.lines);
      widget.fxLayer.pull(g);
      return;
    }
    // 대형 재폭풍: 두드리면 가까운 괴물, 누르고 있으면 연타, 문지르면 베기
    if (g.defn != null) {
      p.acted = true;
      p.def = true;
      void strike() {
        final w = toWorld(p.pos);
        g.strikeAt(w.dx, w.dy, 110 * math.max(.8, cam.z) / cam.z);
        _after();
      }

      strike();
      void again() {
        if (!ptrs.containsKey(e.pointer) || g.defn == null) return;
        strike();
        p.hold = Timer(const Duration(milliseconds: 120), again);
      }

      p.hold = Timer(const Duration(milliseconds: 260), again);
      return;
    }
    final ax = ashAt(p.pos);
    if (ax >= 0) {
      p.acted = true;
      g.hitAsh(ax, g.tapPow * (g.fever > 0 ? 2 : 1));
      _after();
      void again() {
        final q = ptrs[e.pointer];
        if (q == null || q.moved || !g.S.ash.containsKey('$ax')) return;
        g.hitAsh(ax, g.tapPow * (g.fever > 0 ? 2 : 1));
        _after();
        q.hold = Timer(const Duration(milliseconds: 110), again);
      }

      p.hold = Timer(const Duration(milliseconds: 320), again);
      return;
    }
    final w = toWorld(p.pos);
    var i = pickTile(w);
    // 폐허 그림도 칸보다 위로 솟아 있다: 누른 칸이 빈 땅이면 그 앞 칸 폐허 그림 안인지 본다 (2026-10-21 대표님: 폐허를 눌러도 잘 안 캐짐)
    if (i < 0 || g.S.rev[i] != 1 || !(g.siteLive(i) || g.S.camp.containsKey(i) || i == C0 || g.modAtTile(i) != null || g.S.ter[i] == T.lm)) {
      final sj = MapPainter(g, cam, cam).siteAt(w);
      if (sj >= 0) i = sj;
    }
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
    if (p.def) {
      if (g.defn != null) {
        final w = toWorld(p.pos);
        g.slashAt(w.dx, w.dy, 46 * math.max(.8, cam.z) / cam.z, DateTime.now().millisecondsSinceEpoch);
        _after();
      }
      return;
    }
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
      final w0 = toWorld(p.pos), i0 = pickTile(w0);
      if (widget.onPlace != null) {
        widget.onPlace!(i0);
        return;
      }
      // 수상한 그림자: 눌러서 쫓아가기 (웹 catchShadow)
      final sh = g.shadow;
      if (sh != null && sh.light == null && !sh.got) {
        final (sx, sy) = sh.pos;
        if ((Offset(sx, sy - 14) - w0).distance < 34 * math.max(.8, cam.z) / cam.z) {
          g.catchShadow();
          g.fx.add(FxBurstAt(sx, sy - 14, 0xFF3A3040, 14));
          widget.fxLayer.pull(g);
          return;
        }
      }
      // 신기루·멈추지 않은 기계 (웹 rspotHit)
      final rsp = g.rspot;
      if (rsp != null) {
        final ri = (rsp['i'] as num).toInt();
        if (g.S.rev[ri] == 1 && (toScreen(tileC(ri, rsp['k'] == 'machine' ? 14 : 10)) - p.pos).distance <= math.max(30, 26 * cam.z) && g.rspotHit(ri)) {
          widget.fxLayer.pull(g);
          _after();
          return;
        }
      }
      // 펫: 한 번 누르면 쓰다듬기, 1.5초 안에 또 누르면 자세히 (웹 petTap)
      final pk = life.petAt(w0, math.max(16 / cam.z, 12));
      if (pk != null) {
        final w = life.pets[pk]!;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - (_petPatT[pk] ?? 0) < 1500) {
          widget.onSelect('pet', petKeys.indexOf(pk));
        } else {
          _petPatT[pk] = now;
          life.heartsAt(w.x, w.y);
          final snd = petInfo(pk)['snd'] as String;
          widget.fxLayer.pull(g);
          g.fx.add(FxFloatAt(w.x, w.y - 26, snd == '은빛 발자국' ? '…' : '$snd!', 0xFFFFE6C8));
          g.petPat(pk);
          _after();
        }
        return;
      }
      life.petTap = w0;
      life.petTapT = 0;
      final st = g.stray;
      if (st != null && g.strayVis && (toScreen(tileC((st['i'] as num).toInt(), 6)) - p.pos).distance < math.max(22, 20 * cam.z)) {
        widget.onSelect('stray', (st['i'] as num).toInt());
        return;
      }
      if (i0 >= 0 && g.band != null && g.band!['tile'] == i0) {
        widget.onSelect('band', i0);
        return;
      }
      if (i0 >= 0 && g.deco.containsKey('$i0')) {
        widget.onSelect('deco', i0);
        return;
      }
      // 건물 그림 위(칸보다 위로 솟은 부분 포함)에서는 사람을 좁게 잡는다 — 쉘터 둘레를 걷는 사람이 텐트 누르기를 가로채지 않게
      final bld = (i0 >= 0 && g.S.rev[i0] == 1 && (i0 == C0 || g.modAtTile(i0) != null || g.S.camp.containsKey(i0) || g.S.ter[i0] == T.lm)) || MapPainter(g, cam, cam).bldAt(w0) >= 0;
      final pid = life.personAt(w0, bld ? 9 + 3 / cam.z : 18 + 8 / cam.z);
      if (pid != null) {
        widget.onSelect('person', pid);
        if (ptrs.isEmpty) dragStart = null;
        return;
      }
      // 건물 그림이 덮은 곳이면 그 건물 — 여러 그림이 겹치면 누른 곳이 그림 가운데에 가장 가까운 건물 (2026-10-21 대표님: 작업대·텃밭이 겹쳐 누르기 어려움).
      // 그림이 없는 곳이면 누른 칸 그대로 (2026-10-20: 텐트 윗부분·이름표를 누르면 뒤 칸이 잡혀 '구름을 두드려 보세요'만 떴다)
      var i = pickTile(w0);
      final j = MapPainter(g, cam, cam).bldAt(w0);
      if (j >= 0) i = j;
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
          RepaintBoundary(child: LiveLayer(game: g, camera: cam, life: life)),
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

typedef _Land = ({List<int> bg, int v, List<int> soil, List<int> ruin, List<int> green, List<int> paving, List<int> w1, List<int> w2, List<int> fog});

class MapPainter extends CustomPainter {
  MapPainter(this.g, this.cam, Listenable repaint) : super(repaint: repaint);
  final Game g;
  final Camera cam;

  static final _fill = Paint()..isAntiAlias = true;
  static final _img = Paint()..filterQuality = FilterQuality.medium;
  static final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  // 동네 풍경 (웹 LANDSCAPES — 색만 바꾼다. 2026-10-14 첫 동네 물 색을 손그림 결에 맞춤)
  static const _lands = {
    'home': (bg: [0xFF25323F, 0xFF1B2631], v: 0xFF1C2733, soil: [0x8A, 0x8C, 0x80], ruin: [0x76, 0x7B, 0x78], green: [0x71, 0x82, 0x72], paving: [0x9E, 0x9C, 0x8A], w1: [0x34, 0x53, 0x5C], w2: [0x41, 0x63, 0x6A], fog: [0xFF283643, 0xFF354351]),
    'desert': (bg: [0xFF49443C, 0xFF292C2D], v: 0xFF373733, soil: [0xB7, 0xA1, 0x83], ruin: [0x9B, 0x8C, 0x77], green: [0x96, 0x91, 0x6D], paving: [0xC1, 0xB2, 0x98], w1: [0x50, 0x6F, 0x76], w2: [0x63, 0x85, 0x8A], fog: [0xFF45443E, 0xFF5A5549]),
    'factory': (bg: [0xFF303B42, 0xFF20272E], v: 0xFF252D32, soil: [0x85, 0x8D, 0x8B], ruin: [0x73, 0x7C, 0x7C], green: [0x6D, 0x81, 0x78], paving: [0xA0, 0xA7, 0xA1], w1: [0x3A, 0x5D, 0x66], w2: [0x4B, 0x70, 0x77], fog: [0xFF303C43, 0xFF414F55]),
    'snow': (bg: [0xFF465665, 0xFF293845], v: 0xFF354452, soil: [0xC5, 0xD1, 0xD2], ruin: [0xA8, 0xB8, 0xBF], green: [0xA4, 0xBC, 0xB5], paving: [0xD6, 0xDE, 0xD9], w1: [0x53, 0x7D, 0x94], w2: [0x77, 0x9C, 0xAF], fog: [0xFF3C5060, 0xFF526878]),
  };
  _Land get _L => _lands[g.S.region] ?? _lands['home']!;
  Color get bgTop => Color(_L.bg[0]);
  Color get bgBottom => Color(_L.bg[1]);
  Color get voidCol => Color(_L.v);
  Color get fog0 => Color(_L.fog[0]);
  Color get fog1 => Color(_L.fog[1]);
  static const fogTop0 = Color(0x0D718391), fogTop1 = Color(0x14C4AD81);
  List<int> get soil => _L.soil;
  List<int> get ruin => _L.ruin;
  List<int> get green => _L.green;
  List<int> get paving => _L.paving;
  List<int> get w1 => _L.w1;
  List<int> get w2 => _L.w2;

  static List<double> _lerp(List<num> a, List<num> b, double t) => [for (var k = 0; k < 3; k++) (a[k] + (b[k] - a[k]) * t).toDouble()];
  static Color _rgb(List<num> a, [double k = 1]) => Color.fromARGB(255, math.min(255, a[0] * k).floor(), math.min(255, a[1] * k).floor(), math.min(255, a[2] * k).floor());

  /// 웹 groundCol (6327 재정의)
  Color groundCol(int i, int t, double gr, bool paved) {
    final n = groundNoise[i];
    return _rgb(paved ? paving : _lerp(t == T.ruin ? ruin : soil, green, math.min(.6, gr * .65)), 1 + n * .045);
  }

  Color waterCol(int i) => _rgb(_lerp(w1, w2, (.5 + groundNoise[i] * .6).clamp(0, 1).toDouble()));

  /// 불빛 자리 (웹 glowPts). 그리기는 위층(LiveLayer)이 밤 어둠을 덮은 뒤에 한다.
  static final List<(Offset, double, Color, double)> glows = [];

  /// 노선 역 '노선' 표식 (x, y, 복구됨, 아직 안 가 본 노선)과 역 입구 빛 — 움직이므로 위층(LiveLayer)이 그린다
  static final List<(double, double, bool, bool)> badges = [];
  static final List<Offset> stationGlows = [];
  List<(Offset, double, Color, double)> get _glows => glows;

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
    canvas.drawRect(rect, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [bgTop, bgBottom]));
    _glows.clear();
    badges.clear();
    stationGlows.clear();
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(cam.z);
    canvas.translate(-cam.x, -cam.y);
    final tl = Offset(cam.x - (size.width / 2 + 80) / cam.z, cam.y - (size.height / 2 + 40) / cam.z);
    final br = Offset(cam.x + (size.width / 2 + 80) / cam.z, cam.y + (size.height / 2 + 260) / cam.z);
    final S = g.S;
    _lnFade();
    for (var s = 0; s <= W + H - 2; s++) {
      final wy = (s + 1) * TH / 2;
      if (wy < tl.dy - 10 || wy > br.dy) continue;
      for (var x = math.max(0, s - H + 1); x <= math.min(W - 1, s); x++) {
        final y = s - x, wx = (x - y) * TW / 2;
        if (wx < tl.dx - TW || wx > br.dx + TW) continue;
        final i = y * W + x;
        if (S.rev[i] == 1) {
          _landTile(canvas, i, x, y);
          if (S.ash.containsKey('$i')) _ash(canvas, i);
          if (g.placingDeco != null && g.decoOk(i)) {
            canvas.drawPath(
                _diamond(tileC(i), .9),
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2
                  ..color = const Color(0xCCFFD98A));
            canvas.drawPath(_diamond(tileC(i), .9), Paint()..color = const Color(0x22FFD98A));
          }
        } else {
          _fogTile(canvas, i, x, y);
        }
      }
    }
    _crowMarks(canvas);
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
    canvas.restore();
  }

  /// 등불 탑 (웹 towerDraw 5124): 쉘터 왼쪽의 철골 탑, 4단계부터 렌즈, 불이 켜지면 하늘로 빛줄기
  /// 까마귀가 남긴 검은 새 표식 (웹 towerDraw 덮어쓰기)
  void _crowMarks(Canvas canvas) {
    final p = Paint()..color = const Color(0xCC141216);
    for (final i in g.crowMarks) {
      if (g.S.rev[i] != 1) continue;
      final c = tileC(i, 2), x = c.dx, y = c.dy;
      canvas.drawPath(
          Path()
            ..moveTo(x - 9, y - 3)
            ..quadraticBezierTo(x - 4, y - 7, x, y - 1)
            ..quadraticBezierTo(x + 4, y - 7, x + 9, y - 3)
            ..quadraticBezierTo(x + 4, y - 4, x, y + 1)
            ..quadraticBezierTo(x - 4, y - 4, x - 9, y - 3),
          p);
    }
  }

  /// 붉은 재 (웹 drawAsh 2826)
  void _ash(Canvas canvas, int i) {
    final a = g.S.ash['$i'];
    if (a is! Map) return;
    final f = (((a['hp'] as num?) ?? 0) / math.max(.001, ((a['max'] as num?) ?? 1))).clamp(0.0, 1.0).toDouble();
    for (var k = 0; k < 4; k++) {
      final c = P(i, .5 + (k % 2 - .5) * .3, .5 + ((k >> 1) - .5) * .3, 6 + k * 2.0);
      _fill.color = k.isOdd ? const Color(0xFF6C6760) : const Color(0xFF85807A);
      canvas.drawCircle(c, (9 + k * 2) * (.5 + f * .5), _fill);
    }
    final c = tileC(i);
    final pts = [Offset(c.dx, c.dy - TH / 2), Offset(c.dx + TW / 2, c.dy), Offset(c.dx, c.dy + TH / 2), Offset(c.dx - TW / 2, c.dy)];
    _line
      ..color = const Color(0xD9E2644F)
      ..strokeWidth = 2.2;
    for (var k = 0; k < 4; k++) {
      final p0 = pts[k], p1 = pts[(k + 1) % 4], len = (p1 - p0).distance;
      for (var d = 0.0; d < len; d += 10) {
        canvas.drawLine(p0 + (p1 - p0) * (d / len), p0 + (p1 - p0) * (math.min(len, d + 6) / len), _line);
      }
    }
    final b = P(i, .5, .5, 34);
    if (a['stuck'] != true) {
      _line
        ..color = const Color(0xB30D0B08)
        ..strokeWidth = 4;
      canvas.drawCircle(b, 7, _line..style = PaintingStyle.stroke);
      _line
        ..color = const Color(0xFFE2644F)
        ..strokeWidth = 3;
      final t = (((a['t'] as num?) ?? 0) / 14).clamp(0.0, 1.0).toDouble();
      canvas.drawArc(Rect.fromCircle(center: b, radius: 7), -math.pi / 2, math.pi * 2 * t, false, _line);
    }
    _fill.color = const Color(0xBF0D0B08);
    canvas.drawRect(Rect.fromLTWH(b.dx - 18, b.dy + 10, 36, 5), _fill);
    _fill.color = const Color(0xFFB9B3AA);
    canvas.drawRect(Rect.fromLTWH(b.dx - 17, b.dy + 11, 34 * f, 3), _fill);
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
    final dia = _diamond(c, 1.02);
    _fill.color = t == T.water ? waterCol(i) : groundCol(i, t, g.green[i], core || mod != null);
    canvas.drawPath(dia, _fill);
    final n = Offset(c.dx, c.dy - TH / 2), e = Offset(c.dx + TW / 2, c.dy), s = Offset(c.dx, c.dy + TH / 2), w = Offset(c.dx - TW / 2, c.dy);
    if (t == T.water) {
      // 손그림 물 질감 + 물가 (웹 drawTile 2026-10-13)
      _gtFill(canvas, S.region == 'snow' ? 7 : 3, .88, dia);
      final shore = [
        if (x > 0 && S.rev[i - 1] == 1 && S.ter[i - 1] != T.water) (n, w),
        if (x < W - 1 && S.rev[i + 1] == 1 && S.ter[i + 1] != T.water) (e, s),
        if (y > 0 && S.rev[i - W] == 1 && S.ter[i - W] != T.water) (n, e),
        if (y < H - 1 && S.rev[i + W] == 1 && S.ter[i + W] != T.water) (w, s),
      ];
      if (shore.isNotEmpty) {
        canvas.save();
        canvas.clipPath(_diamond(c));
        for (final (a, b) in shore) {
          _line
            ..color = const Color(0x59142832)
            ..strokeWidth = 9;
          canvas.drawLine(a, b, _line);
          _line
            ..color = const Color(0x73E1F0EB)
            ..strokeWidth = 2.2;
          canvas.drawLine(a, b, _line);
        }
        canvas.restore();
      }
    } else {
      _line
        ..color = const Color(0x12140E08)
        ..strokeWidth = 1;
      canvas.drawLine(w, s, _line);
      canvas.drawLine(s, e, _line);
      // 땅 질감: 쉘터·모듈 자리는 콘크리트, 그 밖은 동네 흙 (+ 첫 동네 풀밭엔 마른 풀)
      final paved = core || mod != null;
      final ok = _gtFill(canvas, paved ? 2 : const {'desert': 4, 'factory': 5, 'snow': 6}[S.region] ?? 0, paved ? .82 : .8, dia);
      if (ok && !paved && S.region == null && g.green[i] > .05) _gtFill(canvas, 1, math.min(.9, g.green[i] * 1.5), dia);
    }
    // 구름과 맞닿은 가장자리는 그늘 (웹 edgeFade)
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
    _walls(canvas, i, false);
    // 노선 역 앞을 가리는 건물은 반투명 (웹 lnFade)
    // 등불 탑은 쉘터 뒤에 (웹 2026-10-14) — 노선 역 반투명 층 밖에서 그린다 (웹 towerBody는 withFade 밖: 잘리지도 흐려지지도 않음)
    if (core) _towerBody(canvas);
    final soft = _fadeSoft.contains(i);
    if (soft) canvas.saveLayer(Rect.fromCenter(center: c.translate(0, -70), width: TW * 2.6, height: 220), Paint()..color = const Color(0x73000000));
    _tileStuff(canvas, i, c, t, mod, core);
    if (soft) canvas.restore();
    _walls(canvas, i, true);
  }

  void _tileStuff(Canvas canvas, int i, Offset c, int t, Mod? mod, bool core) {
    final S = g.S;

    if (core) {
      final lv = S.lv;
      _sprite(canvas, Atlas.mapImage('shelters.webp'), Atlas.cell('shelters.webp', lv - 1, 3, 2), c, const [84.0, 84.0, 90.0, 100.0, 112.0][lv - 1], .91);
      _glows.add((P(i, .5, .5, 16), 42.0 + lv * 3, const Color(0xFFF0C071), .38));
      return;
    }
    if (mod != null) {
      final idx = modOrder.indexOf(mod.id);
      if (mod.l >= 1 && Atlas.mapImage('module-upgrades.webp') != null) {
        final w = mod.id == 8 ? 40.0 + mod.l * 4 : mod.id == 7 ? 78.0 + mod.l * 3 : 76.0 + mod.l * 3;
        _sprite(canvas, Atlas.mapImage('module-upgrades.webp'), Atlas.fr(Atlas.moduleUpFrames[idx * 2 + math.min(1, mod.l - 1)]), c, w, 1, dy: 8);
      } else {
        _sprite(canvas, Atlas.mapImage('modules.webp'), Atlas.cell('modules.webp', idx, 3, 3), c, (mod.id == 8 || mod.id == 7 ? 94.0 : 78.0) + mod.l * 3, .9);
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
    // 떠돌이 무리 (웹 drawBandTile)
    final band = g.band;
    if (band != null && band['tile'] == i) {
      final f = Atlas.fr(Atlas.propFrames[0]);
      _sprite(canvas, Atlas.mapImage('settlement-props.webp'), f, c, 60, 1, dy: 5);
      final k = band['k'] as String;
      final fp = P(i, .75, .25), tp = P(i, .75, .25, 34);
      _line
        ..color = const Color(0xFF3B2A1A)
        ..strokeWidth = 1.6;
      canvas.drawLine(fp, tp, _line);
      _fill.color = Color(bandTypes[k]!.$2);
      canvas.drawPath(Path()..moveTo(tp.dx, tp.dy)..lineTo(tp.dx + 14, tp.dy + 3)..lineTo(tp.dx, tp.dy + 8)..close(), _fill);
      final m = P(i, .5, .5, 44);
      _fill.color = k == 'raider' ? const Color(0xFFE2644F) : const Color(0xFFFFCF7A);
      canvas.drawCircle(m, 9, _fill);
      _line.strokeWidth = 1.5;
      canvas.drawCircle(m, 9, _line);
      final tx = TextPainter(text: TextSpan(text: k == 'trader' ? '⇄' : k == 'raider' ? '!' : '?', style: Ttc.t(11, color: const Color(0xFF3B2A1A), weight: FontWeight.w700, height: 1)), textDirection: TextDirection.ltr)..layout();
      tx.paint(canvas, Offset(m.dx - tx.width / 2, m.dy - tx.height / 2));
      _glows.add((P(i, .35, .62, 2), 24.0, const Color(0xFFFFAA50), .4));
      // 무리를 이끄는 사람 (웹 drawBandTile figureAt: 장사꾼 15 · 약탈자 14 · 그 밖 17)
      final fp2 = P(i, .42, .78);
      figureAt(canvas, (1, k == 'trader' ? 15 : k == 'raider' ? 14 : 17), fp2.dx, fp2.dy, 0);
      return;
    }
    // 장식 (웹 drawDeco: settlement-props 8~15)
    final dk = g.deco['$i'];
    if (dk != null) {
      const ids = {'pot': 8, 'flag': 9, 'bench': 10, 'lamp': 11, 'chime': 12, 'string': 13, 'mural': 14, 'statue': 15};
      final id = ids[dk];
      if (id != null) _prop(canvas, id, c);
      if (dk == 'lamp' || dk == 'string') _glows.add((P(i, .5, .5, dk == 'lamp' ? 22 : 15), dk == 'lamp' ? 24.0 : 30.0, const Color(0xFFF0C071), .36));
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
      final tp = TextPainter(text: TextSpan(text: hp > 0 ? '!' : '?', style: Ttc.t(12, color: const Color(0xFF3B2A1A), weight: FontWeight.w700, height: 1)), textDirection: TextDirection.ltr)..layout();
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
        final (img, f, w) = _lmArt(l.k, l.ok);
        final h = _sprite(canvas, img, f, c, w, 1, dy: 8), lh = h > 0 ? math.max(10.0, h - 16) : 44.0;
        final station = landmarks[l.k].key == 'station';
        if (l.ok) {
          _glows.add((c.translate(0, -12), 28.0, const Color(0xFFF0C071), .28));
          // 노선 역: 입구에서 새는 빛 (웹 drawLandmark 2026-10-14)
          if (station) stationGlows.add(P(i, .42, .62)); // 숨 쉬듯 밝아졌다 어두워짐 → 매 프레임 그리는 위층(LiveLayer)에서
        } else {
          _lmMarker(canvas, c.dx, c.dy - (lh + 14));
        }
        if (station) badges.add((c.dx, c.dy - (lh + (l.ok ? 10 : 40)), l.ok, l.ok && ((g.lnState()['fat'] as num?) ?? 0) == 0)); // 위아래로 흔들림 → 위층에서
      }
      return;
    }
    final site = S.site[i];
    final live = site != null && site.c > 0;
    final kind = t == T.car ? 0 : t == T.ruin ? 1 : t == T.crate ? 2 : -1;
    if (kind >= 0) {
      final v = (((speck[i] * 7.31 + speck2[i] * 3.17) % 1) * 5).floor();
      final f = Atlas.fr(Atlas.siteFrames[kind * 6 + (live ? math.min(4, v) : 5)]);
      _sprite(canvas, Atlas.mapImage('exploration-sites.webp'), f, c, live ? (kind == 0 ? 60.0 : 62.0) : 54.0, 1, dy: 8);
      return;
    }
    if (t == T.silo) {
      final v = (((speck[i] * 7.31 + speck2[i] * 3.17) % 1) * 3).floor();
      // 다 털린 벙커는 닫힌 벙커 그림 (웹 drawBunker live?4+v:7 · 2026-10-21: 앱은 열린 그림을 55%로 흐리게 그려 유령처럼 보였다)
      _prop(canvas, live ? 4 + v : 7, c);
      if (live) _glows.add((c, 18.0, const Color(0xFFFFC86E), .3));
      return;
    }
    if (site != null && site.k == 'rubble') {
      _prop(canvas, live ? 2 : 3, c);
      return;
    }
    // 빈 땅: 쉘터 가까이 나무, 군데군데 풀·덤불·벽돌 (웹 tree / groundDecor, 손그림 terrain-props)
    final gr = g.green[i];
    final trees = speck2[i] > .45 ? (gr * 2.5).floor() : 0;
    for (var k = 0; k < trees; k++) {
      _tree(canvas, .2 + ((speck[i] * 97 + k * .37) % 1) * .6, .2 + ((speck2[i] * 53 + k * .61) % 1) * .6, i, (k + i) % 3 == 0);
    }
    if (trees == 0 || gr > .3) _groundDecor(canvas, i, gr);
  }

  // ---------- 땅·물 질감 (웹 gtFill: 질감 한 장이 땅 두 칸을 덮고 칸을 넘어 이어진다) ----------
  static final Map<int, ImageShader> _gtShader = {};
  static final _gtM = Float64List.fromList([TW / 256, TH / 256, 0, 0, -TW / 256, TH / 256, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
  static final _gtPaint = Paint()..filterQuality = FilterQuality.medium;
  bool _gtFill(Canvas canvas, int k, double a, Path p) {
    if (a <= 0) return false;
    var sh = _gtShader[k];
    if (sh == null) {
      final im = Atlas.groundTile(k);
      if (im == null) return false;
      sh = _gtShader[k] = ImageShader(im, TileMode.repeated, TileMode.repeated, _gtM, filterQuality: FilterQuality.medium);
    }
    _gtPaint
      ..shader = sh
      ..color = Color.fromRGBO(0, 0, 0, a);
    canvas.drawPath(p, _gtPaint);
    return true;
  }

  // ---------- 나무·풀 소품 (웹 terrain-props.webp 4×2: 0·1 활엽수 · 2 소나무 · 3 마른 나무 · 4·5 풀포기 · 6 덤불 · 7 벽돌 더미) ----------
  bool _tp(Canvas canvas, int k, double x, double y, double h) {
    final b = Atlas.boxes('terrain-props.webp', 4, 2), im = Atlas.image('terrain-props.webp'); // 웹 SNOW_FILES에 없음: 동네 색을 입히지 않는다
    if (b == null || im == null || b[k] == null) return false;
    final src = b[k]!, w = src.width * h / src.height;
    canvas.drawImageRect(im, src, Rect.fromLTWH(x - w / 2, y - h, w, h), _img..color = const Color(0xFFFFFFFF));
    return true;
  }

  /// 웹 tree(u,v,.85,kind)
  void _tree(Canvas canvas, double u, double v, int i, bool pine) {
    const s = .85;
    final p = P(i, u, v), hh = ((u * 97.13 + v * 41.7) % 1 + 1) % 1, k = pine ? 2 : hh < .45 ? 0 : hh < .9 ? 1 : 3;
    if (_tp(canvas, k, p.dx, p.dy + 2 * s, (k == 2 ? 34 : 30) * s)) return;
    // 그림이 아직이면 단순한 나무 (손그림 결: 먹선)
    _fill.color = const Color(0x38100C08);
    canvas.drawOval(Rect.fromCenter(center: p.translate(4 * s, 1), width: 15 * s, height: 6.4 * s), _fill);
    _fill.color = const Color(0xFF4F3624);
    canvas.drawRect(Rect.fromLTWH(p.dx - 1, p.dy - 8 * s, 2.2 * s, 8 * s), _fill);
    _fill.color = pine ? const Color(0xFF47563F) : const Color(0xFF55603F);
    canvas.drawOval(Rect.fromCenter(center: p.translate(0, -13 * s), width: 14 * s, height: 13 * s), _fill);
  }

  /// 웹 groundDecor: 풀밭엔 풀포기·덤불, 맨땅엔 가끔 벽돌 더미
  /// 빈 땅 꾸밈 (웹 groundDecor 6392 재정의): 첫 동네는 네 칸에 한 칸쯤(speck>.75)만 풀·꽃·돌·금,
  /// 다른 동네는 가는 땅결 한 줄(눈 위 흰 줄 · 모래 곡선 · 공단 회색)
  void _groundDecor(Canvas canvas, int i, double gr) {
    final r = g.S.region;
    if (r != null) {
      if (speck[i] < .72) return;
      final a = P(i, .18, .62, 0), b = P(i, .68, .62, 0), c = P(i, .8, .44, 0);
      _line
        ..color = r == 'snow' ? const Color.fromRGBO(245, 249, 244, .55) : r == 'desert' ? const Color.fromRGBO(107, 87, 61, .24) : const Color.fromRGBO(58, 69, 70, .28)
        ..strokeWidth = .7;
      final path = Path()..moveTo(a.dx, a.dy);
      if (r == 'desert') {
        path.quadraticBezierTo(b.dx, b.dy - 3, c.dx, c.dy);
      } else {
        path
          ..lineTo(b.dx, b.dy)
          ..lineTo(c.dx, c.dy);
      }
      canvas.drawPath(path, _line);
      return;
    }
    if (speck[i] > .75) _groundDecor0(canvas, i, gr);
  }

  /// 웹 groundDecor 4521 (원래 것): 손그림 풀·덤불 → 없으면 먹선 풀포기·꽃 / 맨땅엔 자갈과 금
  void _groundDecor0(Canvas canvas, int i, double gr) {
    final s1 = speck[i], s2 = speck2[i];
    final tpOk = Atlas.boxes('terrain-props.webp', 4, 2) != null && Atlas.image('terrain-props.webp') != null;
    if (gr > .3 && tpOk) {
      final n = 1 + ((s2 * 7).floor()) % 2;
      for (var k = 0; k < n; k++) {
        final p = P(i, .2 + ((s1 * 97 + k * .37) % 1) * .6, .2 + ((s2 * 53 + k * .61) % 1) * .6);
        _tp(canvas, k == 0 && s2 > .84 && gr > .5 ? 5 : (s1 + k * .3) % 1 < .6 ? 4 : 6, p.dx, p.dy + 1, 11 + ((s1 * 13 + k) % 1) * 4);
      }
      return;
    }
    if (gr <= .3 && s2 > .86 && tpOk) {
      final p = P(i, .4 + s1 * .2, .55);
      _tp(canvas, 7, p.dx, p.dy + 1, 9);
      return;
    }
    if (gr > .3) {
      // 손그림을 아직 못 쟀을 때: 먹선 풀포기
      final n = 2 + ((s2 * 7).floor()) % 3;
      _line
        ..color = groundNoise[i] > 0 ? const Color.fromRGBO(128, 134, 84, .75) : const Color.fromRGBO(52, 60, 36, .6)
        ..strokeWidth = 1.1;
      for (var k = 0; k < n; k++) {
        final p = P(i, .15 + ((s1 * 97 + k * .37) % 1) * .7, .15 + ((s2 * 53 + k * .61) % 1) * .7);
        canvas.drawLine(Offset(p.dx - 2, p.dy), Offset(p.dx - 3, p.dy - 3.5), _line);
        canvas.drawLine(p, Offset(p.dx, p.dy - 4.5), _line);
        canvas.drawLine(Offset(p.dx + 2, p.dy), Offset(p.dx + 3.2, p.dy - 3.2), _line);
      }
      if (s2 > .84 && gr > .5) {
        const cols = [Color(0xFFF2D06B), Color(0xFFEFE6D0), Color(0xFFD9745A)];
        for (var k = 0; k < 3; k++) {
          final p = P(i, .25 + ((s1 * 31 + k * .29) % 1) * .5, .25 + ((s2 * 17 + k * .47) % 1) * .5);
          _fill.color = cols[(k + (s1 * 3).floor()) % 3];
          canvas.drawCircle(p.translate(0, -1), 1.4, _fill);
        }
      }
      return;
    }
    // 맨땅: 그늘 진 자갈 1~3개, 가끔 금
    for (var k = 0; k < 1 + ((s1 * 5).floor()) % 3; k++) {
      final p = P(i, .18 + ((s1 * 7 + k * .3) % 1) * .64, .18 + ((s2 * 5 + k * .43) % 1) * .64), rr = 1.2 + ((s1 * 13 + k) % 1) * 1.6;
      _fill.color = const Color.fromRGBO(28, 20, 12, .35);
      canvas.drawOval(Rect.fromCenter(center: p.translate(.6, .6), width: rr * 2.6, height: rr * 1.6), _fill);
      _fill.color = k.isOdd ? const Color(0xFF7A6C57) : const Color(0xFF857660);
      canvas.drawOval(Rect.fromCenter(center: p, width: rr * 2.6, height: rr * 1.6), _fill);
    }
    if (s2 < .3) {
      _line
        ..color = const Color.fromRGBO(30, 22, 14, .22)
        ..strokeWidth = .8;
      final a = P(i, .36 + s1 * .15, .4), b = P(i, .46, .5 + s2 * .15), c = P(i, .58, .56);
      canvas.drawLine(a, b, _line);
      canvas.drawLine(b, c, _line);
    }
  }


  // ---------- 방벽 (웹 drawWalls · wallSeg: 쉘터 둘레, 뒤쪽 두 변은 건물 앞에서, 앞쪽 두 변은 건물 뒤에) ----------
  void _walls(Canvas canvas, int i, bool front) {
    final S = g.S;
    if (S.walls <= 0) return;
    final rw = S.lv >= 3 ? 2 : 1, dx = i % W - CX, dy = i ~/ W - CY;
    if (dx.abs() > rw || dy.abs() > rw) return;
    if (!front) {
      if (dx == -rw) _wallSeg(canvas, P(i, 0, 0), P(i, 0, 1), S.walls);
      if (dy == -rw) _wallSeg(canvas, P(i, 0, 0), P(i, 1, 0), S.walls);
    } else {
      if (dx == rw) _wallSeg(canvas, P(i, 1, 0), P(i, 1, 1), S.walls);
      if (dy == rw) _wallSeg(canvas, P(i, 0, 1), P(i, 1, 1), S.walls);
    }
  }

  void _wallSeg(Canvas canvas, Offset a, Offset b, int lv) {
    final h = const [11.0, 8.0, 17.0][lv - 1];
    Offset at(double t, [double z = 0]) => Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t - z);
    void poly(List<Offset> pts, Color f, Color st) {
      final path = Path()..addPolygon(pts, true);
      _fill.color = f;
      canvas.drawPath(path, _fill);
      _line
        ..color = st
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, _line);
    }

    void seg(Offset p, Offset q, Color c, double w) {
      _line
        ..color = c
        ..strokeWidth = w;
      canvas.drawLine(p, q, _line);
    }

    if (lv == 1) {
      for (var q = 0; q < 7; q++) {
        final p = at(q / 6), top = h + (q % 2) * 1.5;
        poly([Offset(p.dx - 1.8, p.dy), Offset(p.dx + 1.8, p.dy), Offset(p.dx + 1.6, p.dy - top), Offset(p.dx - .8, p.dy - top - 1), Offset(p.dx - 1.8, p.dy - top + .5)],
            q % 2 == 1 ? const Color(0xFF7A6450) : const Color(0xFF8D7659), const Color(0xFF231A14));
        seg(Offset(p.dx - .2, p.dy - 2), Offset(p.dx + .2, p.dy - top + 2), const Color(0x59DFCFA9), .55);
      }
      for (final z in const [3.5, 8.0]) {
        seg(at(0, z), at(1, z), const Color(0xFF534F45), 1.5);
      }
    } else if (lv == 2) {
      for (var row = 0; row < 2; row++) {
        for (var q = 0; q < 4; q++) {
          final t0 = q / 4, t1 = (q + 1) / 4, z = row * 4.0;
          poly([at(t0, z + 1), at(t1, z + 1), at(t1, z + 3.6), at(t1 - .025, z + 4.5), at(t0 + .025, z + 4.5), at(t0, z + 3.5)],
              (q + row) % 2 == 1 ? const Color(0xFFAFA48A) : const Color(0xFFC2B69A), const Color(0xFF64665D));
          final m = at((t0 + t1) / 2, z + 2.5);
          seg(Offset(m.dx - 1.5, m.dy), Offset(m.dx + 1.5, m.dy - .3), const Color(0x73444C46), .5);
        }
      }
    } else {
      for (var q = 0; q < 4; q++) {
        final t = q / 4, u = (q + 1) / 4, top = h + (q % 2);
        poly([at(t), at(u), at(u, top), at(t, top - 1)], q % 2 == 1 ? const Color(0xFF5A5048) : const Color(0xFF6B5D50), const Color(0xFF231A14));
        seg(at(t + .1, top - 2), at(t + .12, 3), const Color(0x8C96542E), 1.1);
        seg(at(t + .04, 2), at(t + .04, top - 2), const Color(0x66D1CAAF), .65);
        _fill.color = const Color(0xFFC0B59C);
        for (final z in [3.0, top - 3]) {
          final p = at(t + .035, z);
          canvas.drawRect(Rect.fromLTWH(p.dx - .5, p.dy - .5, 1, 1), _fill);
        }
        final p = at(t + .13, 5 + (q % 2) * 3.0);
        seg(p, Offset(p.dx + 2, p.dy - 3), const Color(0xFF946F50), 1);
      }
    }
  }

  // ---------- 랜드마크 그림 (웹 design.js landmarkMetrics: 동네별 그림 · 노선 역 손그림) ----------
  static const _lmr = {
    'desert': ('landmarks-desert.webp', [[17, 85, 366, 268], [427, 95, 372, 254], [862, 24, 252, 333], [1189, 66, 384, 283], [1615, 64, 353, 287], [12, 463, 375, 282], [430, 474, 369, 266], [872, 408, 243, 342], [1190, 449, 385, 289], [1616, 446, 352, 294]]),
    'factory': ('landmarks-factory.webp', [[22, 49, 380, 340], [450, 82, 325, 305], [824, 96, 337, 277], [1211, 62, 346, 324], [1599, 95, 364, 288], [22, 403, 381, 344], [449, 427, 329, 319], [823, 450, 338, 276], [1210, 415, 349, 328], [1598, 448, 365, 292]]),
    'snow': ('landmarks-snow.webp', [[6, 81, 412, 312], [442, 115, 363, 270], [836, 83, 335, 297], [1205, 91, 350, 298], [1587, 96, 382, 291], [11, 393, 419, 375], [446, 483, 360, 273], [831, 403, 350, 345], [1202, 417, 357, 346], [1583, 438, 388, 323]]),
  };
  // line-stations.webp: 4열(첫 동네·사막·공단·설원) × 2행(폐허·복구), 공단은 화물칸이 들어간 line-stations-factory 두 칸을 우선
  static const _ls = [[15, 55, 363, 295], [396, 56, 368, 297], [782, 60, 357, 289], [1159, 58, 362, 295], [14, 432, 364, 299], [399, 432, 368, 299], [783, 436, 356, 293], [1159, 433, 362, 299]];
  static const _lsf = [[6, 75, 378, 247], [390, 75, 372, 249]];

  (ui.Image?, Rect?, double) _lmArt(int k, bool ok) {
    final r = g.S.region;
    if (landmarks[k].key == 'station') {
      final col = const {'desert': 1, 'factory': 2, 'snow': 3}[r] ?? 0;
      final f2 = Atlas.image('line-stations-factory.webp');
      if (col == 2 && f2 != null) return (f2, Atlas.fr(_lsf[ok ? 1 : 0]), 94.0);
      final ls = Atlas.image('line-stations.webp');
      if (ls != null) return (ls, Atlas.fr(_ls[col + (ok ? 4 : 0)]), 88.0);
    }
    final R = _lmr[r];
    final rim = R == null ? null : Atlas.image(R.$1);
    if (R != null && rim != null) {
      final f = R.$2[k + (ok ? 5 : 0)];
      return (rim, Atlas.fr(f), (f[2] * .2).clamp(48.0, 80.0).toDouble());
    }
    return (Atlas.mapImage('landmarks.webp'), Atlas.fr(Atlas.landmarkFrames[k + (ok ? 5 : 0)]), Atlas.landmarkWidth[k]);
  }

  /// 역 위의 '노선' 표식 (웹 lnBadge)
  static TextPainter? _lnText;

  /// '노선' 표식 (웹 lnBadge 6451): 위아래로 살짝 흔들리고, 아직 안 가 본 노선이면 둥근 물결
  static void lnBadge(Canvas canvas, double x, double y, double time, bool ok, bool fresh, {bool calm = false}) {
    y += calm ? 0 : math.sin(time / 320) * 1.5;
    if (fresh && !calm) {
      final p = (time % 1600) / 1600;
      _line
        ..color = Color.fromRGBO(255, 205, 120, (1 - p) * .8)
        ..strokeWidth = 2;
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: (22 + p * 16) * 2, height: (11 + p * 8) * 2), _line);
    }
    final tp = _lnText ??= TextPainter(text: TextSpan(text: '노선', style: Ttc.t(10, color: const Color(0xFF2C2217), weight: FontWeight.w700, height: 1)), textDirection: TextDirection.ltr)..layout();
    final w = tp.width + 30, hh = 18.0, col = ok ? (fresh ? const Color(0xFFF0C071) : const Color(0xFFC9A46A)) : const Color(0xFF8D867A);
    final rr = RRect.fromRectAndRadius(Rect.fromLTWH(x - w / 2, y - hh / 2, w, hh), const Radius.circular(9));
    final tri = Path()..moveTo(x - 4, y + hh / 2)..lineTo(x, y + hh / 2 + 5)..lineTo(x + 4, y + hh / 2)..close();
    _fill.color = col;
    canvas.drawRRect(rr, _fill);
    _line
      ..color = const Color(0xFF2C2217)
      ..strokeWidth = 1.5;
    canvas.drawRRect(rr, _line);
    canvas.drawPath(tri, _fill);
    canvas.drawPath(tri, _line);
    final ix = x - w / 2 + 11;
    _line.strokeWidth = 1.4;
    canvas.drawLine(Offset(ix - 3, y - 5), Offset(ix - 4.5, y + 5), _line);
    canvas.drawLine(Offset(ix + 3, y - 5), Offset(ix + 4.5, y + 5), _line);
    for (final t in const [-3.0, 0.0, 3.0]) {
      canvas.drawLine(Offset(ix - 4.2 - (t + 3) * .1, y + t), Offset(ix + 4.2 + (t + 3) * .1, y + t), _line);
    }
    tp.paint(canvas, Offset(ix + 8, y + .5 - tp.height / 2));
  }


  // ---------- 노선 역 앞을 가리는 건물 (웹 lnFade · bldH · hitCol) ----------
  Set<int> _fadeSoft = const {};
  /// 그림의 실제 높이 (웹 TTCFinal·TTCDesign·TTCSettlement 의 *Height): 그리는 폭 × 칸 세로/가로
  static double _artH(Rect? f, double w, {double k = 1, double sub = 0, double min = 10}) => f == null || f.width <= 0 ? 0 : math.max(min, w * f.height / f.width * k - sub);
  static double _propH(int id) => _artH(Atlas.fr(Atlas.propFrames[id]), Atlas.propWidth[id], sub: 13, min: 0);

  /// 누른 곳(세계 좌표)이 건물 그림(칸 마름모 + 위로 솟은 높이 + 이름표) 안이면 그 칸. 앞(아래) 칸부터 본다
  int bldAt(Offset w) {
    final i0 = pickTile(w);
    if (i0 < 0) return -1;
    final x0 = i0 % W, y0 = i0 ~/ W;
    var best = -1;
    var bestD = 1e9;
    for (var dy = 0; dy <= 3; dy++) {
      for (var dx = 0; dx <= 3; dx++) {
        final x = x0 + dx, y = y0 + dy;
        if (x >= W || y >= H) continue;
        final t = y * W + x;
        if (g.S.rev[t] != 1) continue;
        if (!(t == C0 || g.modAtTile(t) != null || g.S.ter[t] == T.lm)) continue;
        // 쉘터 그림은 칸보다 넓다 (그리는 폭 84~112) → 폭의 절반, 높이는 폭만큼 + 이름표. 모듈은 위로 갈수록 좁아 폭을 조금 줄인다
        final c = tileC(t), hw = t == C0 ? const [84.0, 84.0, 90.0, 100.0, 112.0][g.S.lv - 1] / 2 : 34.0;
        final h = t == C0 ? math.max(_bldH(t), hw * 1.5) + 30 : _bldH(t) + 16;
        final ddx = (w.dx - c.dx).abs();
        if (ddx > hw || w.dy > c.dy + TH * .5 || w.dy < c.dy - TH * .5 - h) continue;
        // 여러 그림이 겹치면 누른 곳이 그림 가운데(가로·세로 모두)에 가장 가까운 건물 (같으면 앞 칸)
        final halfH = (h + TH) / 2, cy = c.dy + TH * .5 - halfH;
        final d = math.sqrt(math.pow(ddx / hw, 2) + math.pow((w.dy - cy) / halfH, 2)) - (x + y) * .001;
        if (d < bestD) {
          bestD = d;
          best = t;
        }
      }
    }
    return best;
  }

  /// 누른 곳(세계 좌표)이 아직 뒤질 게 남은 폐허 그림 안이면 그 칸 (앞 칸부터, 겹치면 그림 가운데에 가까운 쪽). 없으면 -1
  int siteAt(Offset w) {
    final i0 = pickTile(w);
    if (i0 < 0) return -1;
    final x0 = i0 % W, y0 = i0 ~/ W;
    var best = -1;
    var bestD = 1e9;
    for (var dy = 0; dy <= 2; dy++) {
      for (var dx = 0; dx <= 2; dx++) {
        final x = x0 + dx, y = y0 + dy;
        if (x >= W || y >= H) continue;
        final t = y * W + x;
        if (g.S.rev[t] != 1 || !g.siteLive(t)) continue;
        final c = tileC(t), hw = 28.0, h = math.max(20.0, _bldH(t)) + 10;
        final ddx = (w.dx - c.dx).abs();
        if (ddx > hw || w.dy > c.dy + TH * .5 || w.dy < c.dy - TH * .5 - h) continue;
        final halfH = (h + TH) / 2, cy = c.dy + TH * .5 - halfH;
        final d = math.sqrt(math.pow(ddx / hw, 2) + math.pow((w.dy - cy) / halfH, 2)) - (x + y) * .001;
        if (d < bestD) {
          bestD = d;
          best = t;
        }
      }
    }
    return best;
  }

  /// 칸 위 건물 높이 (웹 bldH 3005): 노선 역 앞을 가리는지 판단할 때 쓴다
  double _bldH(int i) {
    final S = g.S;
    if (S.rev[i] == 0) return 0;
    if (i == C0) return const [22.0, 30.0, 40.0, 64.0, 110.0][S.lv - 1]; // 웹 SHELTER[].h
    final m = g.modAtTile(i);
    if (m != null) {
      final idx = modOrder.indexOf(m.id);
      if (idx < 0) return 0;
      if (m.l >= 1 && Atlas.image('module-upgrades.webp') != null) {
        final w = m.id == 8 ? 40.0 + m.l * 4 : m.id == 7 ? 78.0 + m.l * 3 : 76.0 + m.l * 3;
        return _artH(Atlas.fr(Atlas.moduleUpFrames[idx * 2 + math.min(1, m.l - 1)]), w, sub: 16);
      }
      final h = _artH(Atlas.cell('modules.webp', idx, 3, 3), (m.id == 8 || m.id == 7 ? 94.0 : 78.0) + m.l * 3, k: .9, sub: 14);
      return h > 0 ? h : 44;
    }
    const decoIds = {'pot': 8, 'flag': 9, 'bench': 10, 'lamp': 11, 'chime': 12, 'string': 13, 'mural': 14, 'statue': 15};
    final dk = g.deco['$i'];
    if (dk != null && decoIds[dk] != null) return _propH(decoIds[dk]!);
    final camp = S.camp[i];
    if (camp != null) return _propH(((camp['hp'] as num?) ?? 0) > 0 ? 1 : 0);
    if (g.band != null && g.band!['tile'] == i) return _propH(0);
    if (S.ter[i] == T.silo && g.siteLive(i)) return _propH(4 + (((speck[i] * 7.31 + speck2[i] * 3.17) % 1) * 3).floor());
    if (S.ter[i] == T.lm) {
      final l = S.lm[i];
      if (l == null) return 44;
      final (_, f, w) = _lmArt(l.k, l.ok);
      final h = _artH(f, w, sub: 16);
      return h > 0 ? h : 44;
    }
    if (g.siteLive(i)) {
      final t = S.ter[i], kind = t == T.car ? 0 : t == T.ruin ? 1 : t == T.crate ? 2 : -1;
      if (kind >= 0) {
        final v = (((speck[i] * 7.31 + speck2[i] * 3.17) % 1) * 5).floor();
        return _artH(Atlas.fr(Atlas.siteFrames[kind * 6 + math.min(4, v)]), kind == 0 ? 60 : 62, sub: 16);
      }
    }
    return 0;
  }


  bool _hitCol(int j, Offset p, double h) {
    final c = tileC(j), dx = p.dx - c.dx;
    if (dx.abs() > TW * .44) return false;
    final sl = dx.abs() * (TH / TW);
    return p.dy >= c.dy - TH / 2 - h + sl && p.dy <= c.dy + TH / 2 - sl;
  }

  void _lnFade() {
    final out = <int>{};
    final S = g.S;
    for (final e in S.lm.entries) {
      final f = e.key;
      if (S.rev[f] == 0 || landmarks[e.value.k].key != 'station') continue;
      final fx = f % W, fy = f ~/ W, c = tileC(f, 6);
      final pts = [c, c.translate(-TW * .22, TH * .12), c.translate(TW * .22, TH * .12), c.translate(0, TH * .25)];
      for (var dy = 0; dy <= 3; dy++) {
        for (var dx = 0; dx <= 3; dx++) {
          if (dx == 0 && dy == 0) continue;
          final x = fx + dx, y = fy + dy;
          if (x >= W || y >= H) continue;
          final j = y * W + x, h = _bldH(j);
          if (h >= 8 && pts.any((p) => _hitCol(j, p, h))) out.add(j);
        }
      }
    }
    _fadeSoft = out;
  }

  // ---------- 등불 탑 (웹 towerBody · ltDraw: 손그림 토대·기둥·전선·렌즈·점화 5칸, 쉘터 뒤에) ----------
  double _ltDraw(Canvas canvas, int n, double x, double y) {
    final b = Atlas.boxes('lantern-tower.webp', 5, 1, thr: 40), im = Atlas.image('lantern-tower.webp'); // 웹 SNOW_FILES에 없음
    if (b == null || im == null || b.length < 5 || b[4] == null) return 0;
    final st = n >= 5 ? 4 : math.max(0, n - 1), src = b[st];
    if (src == null) return 0;
    final k = 130 / b[4]!.height * (n > 5 ? 1 + (math.min(n, 12) - 5) * .06 : 1), w = src.width * k, h = src.height * k;
    canvas.drawImageRect(im, src, Rect.fromLTWH(x - w / 2, y - h, w, h), _img..color = const Color(0xFFFFFFFF));
    return h;
  }

  void _towerBody(Canvas canvas) {
    final n0 = g.towerN;
    if (n0 <= 0) return;
    final n = math.min(n0, 12), c = tileC(C0), x = c.dx - 14, y = c.dy - 30, lit = n0 >= 5;
    final spH = _ltDraw(canvas, n0, x, y + 6), h = spH > 0 ? spH * .8 : 26 + n * 20.0;
    if (spH <= 0) {
      final st = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF4A4A52);
      final p = Path()
        ..moveTo(x - 7, y)
        ..lineTo(x - 2, y - h)
        ..moveTo(x + 7, y)
        ..lineTo(x + 2, y - h);
      for (var q = 1; q < n * 3; q++) {
        final f = q / (n * 3), a = y - h * f, w = 7 - 5 * f, f2 = (q + 1) / (n * 3), b2 = y - h * f2, w2 = 7 - 5 * f2;
        p
          ..moveTo(x - w, a)
          ..lineTo(x + w2, b2)
          ..moveTo(x + w, a)
          ..lineTo(x - w2, b2);
      }
      canvas.drawPath(p, st);
      canvas.drawRect(Rect.fromLTWH(x - 9, y - 3, 18, 4), Paint()..color = const Color(0xFF6A6A72));
      if (n >= 4) {
        canvas.drawCircle(Offset(x, y - h - 4), 5, Paint()..color = lit ? const Color(0xFFFFF4C8) : const Color(0xFF9AB4C8));
        canvas.drawCircle(
            Offset(x, y - h - 4),
            5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = const Color(0xFF3B2A1A));
      }
    }
    if (lit) {
      final beam = Path()
        ..moveTo(x - 4, y - h - 4)
        ..lineTo(x - 26, y - h - 420)
        ..lineTo(x + 26, y - h - 420)
        ..lineTo(x + 4, y - h - 4)
        ..close();
      canvas.drawPath(beam, Paint()..shader = ui.Gradient.linear(Offset(x, y - h), Offset(x, y - h - 420), const [Color(0x8CFFECAA), Color(0x00FFECAA)]));
      _glows.add((Offset(x, y - h - 4), 90.0, const Color(0xFFFFE6A0), .9));
    }
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
    final tp = TextPainter(text: TextSpan(text: '★', style: Ttc.t(11, color: const Color(0xFF3B2A1A), weight: FontWeight.w700, height: 1)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2 + .5));
  }

  void _prop(Canvas canvas, int id, Offset c, {double alpha = 1}) {
    final f = Atlas.fr(Atlas.propFrames[id]);
    _sprite(canvas, Atlas.mapImage('settlement-props.webp'), f, c, Atlas.propWidth[id], 1, dy: 5, alpha: alpha);
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
  final List<Toast> toasts = [];
  Size viewSize = Size.zero;
  final math.Random _r = math.Random();
  void Function(Fx fx)? onFx;

  /// 대형 재폭풍 중: 알림을 괴물이 나오는 지도 가운데가 아니라 스킬 바 바로 위에 작게 띄운다
  bool low = false;

  /// 건물 설명 창(빠른 메뉴)이 떠 있는 동안 알림을 잠시 숨긴다 (창 안 버튼과 겹치지 않게 · 2026-10-21). 알림 시간은 그대로 흐른다
  bool _quiet = false;
  bool get quiet => _quiet;
  set quiet(bool v) {
    if (_quiet == v) return;
    _quiet = v;
    scheduleMicrotask(notifyListeners);
  }

  void toast(String t) {
    // 같은 안내가 이미 떠 있으면 새로 쌓지 않고 그 안내를 다시 2.6초 보여 준다 (2026-10-20 겹쳐 쌓임 신고)
    final same = toasts.where((x) => x.h == null && x.t == t).toList();
    if (same.isNotEmpty) {
      same.first.life = 2.6;
      notifyListeners();
      return;
    }
    toasts.add(Toast(null, t, 2.6));
    if (toasts.length > 3) toasts.removeAt(0);
    notifyListeners();
  }

  /// 한꺼번에 보이는 제목 카드 수: 평소 둘, 대형 재폭풍 중 하나. 넘치는 카드는 줄 세웠다가 앞 카드가 지면 띄운다
  final List<Toast> _noteQ = [];
  int get _noteMax => low ? 1 : 2;
  int get _notesShown => toasts.where((x) => x.h != null).length;

  /// 제목이 있는 알림 카드 (웹 note)
  void note(String h, String t, {int ms = 4500}) {
    toasts.removeWhere((x) => x.h == h);
    _noteQ.removeWhere((x) => x.h == h);
    if (_notesShown >= _noteMax) {
      _noteQ.add(Toast(h, t, ms / 1000));
      if (_noteQ.length > 6) _noteQ.removeAt(0);
    } else {
      toasts.add(Toast(h, t, ms / 1000));
      while (toasts.length > 3) {
        toasts.removeAt(0);
      }
    }
    notifyListeners();
  }

  /// 줄 선 카드 올리기 · 넘친 카드(재폭풍이 시작되어 한도가 줄었을 때)는 먼저 온 것부터 흐리게 지운다
  void _flowNotes() {
    var over = _notesShown - _noteMax;
    for (final x in toasts) {
      if (over <= 0) break;
      if (x.h == null) continue;
      if (x.life > .3) x.life = .3;
      over--;
    }
    while (_noteQ.isNotEmpty && _notesShown < _noteMax) {
      toasts.add(_noteQ.removeAt(0));
      while (toasts.length > 3) {
        toasts.removeAt(0);
      }
    }
  }

  /// 게임에서 나온 연출 신호를 받아 파티클로 바꾼다.
  void pull(Game g) {
    low = g.defn != null;
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
          if (!g.quietToast(text)) toast(text);
        case FxToastLater(:final ms, :final text):
          Future.delayed(Duration(milliseconds: ms), () {
            if (!g.quietToast(text)) toast(text);
          });
        case FxNoteLater(:final wait, :final h, :final t, :final ms):
          Future.delayed(Duration(milliseconds: wait), () => note(h, t, ms: ms));
        case FxNote(:final h, :final t, :final ms):
          note(h, t, ms: ms);
        case FxBurstAt(:final x, :final y, :final color, :final n):
          for (var k = 0; k < math.min(n, 16); k++) {
            final a = _r.nextDouble() * math.pi * 2, sp = 20 + _r.nextDouble() * 50;
            parts.add(_Particle(Offset(x, y), Offset(math.cos(a) * sp, math.sin(a) * sp * .6 - 40), color, .5 + _r.nextDouble() * .3));
          }
        case FxFloatAt(:final x, :final y, :final text, :final color):
          parts.add(_Particle(Offset(x, y), const Offset(0, -26), color, 1.1, text: text));
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
    for (final t in toasts) {
      t.life -= dt;
    }
    toasts.removeWhere((t) => t.life <= 0);
    _flowNotes();
    return parts.isNotEmpty || toasts.isNotEmpty || _noteQ.isNotEmpty;
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
        // 알림은 지도 아래쪽 (웹 #toasts: 아래에서 196px, 폭 100%-110 최대 340)
        if (!c.quiet)
        Positioned(
          left: 0,
          right: 0,
          // 방어 중에는 스킬 바(아래 메뉴 위 84 + 얼굴 줄) 바로 위로 내린다
          bottom: c.low ? 154 + MediaQuery.of(context).padding.bottom : 196,
          child: Center(
            child: SizedBox(
              width: math.min(c.low ? 300 : 340, math.max(0, MediaQuery.of(context).size.width - (c.low ? 40 : 110))).toDouble(),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final t in c.toasts)
                  Opacity(
                    opacity: t.life.clamp(0, .3) / .3,
                    child: Container(
                      width: t.h != null ? double.infinity : null,
                      margin: const EdgeInsets.only(top: 6),
                      padding: t.h != null ? (c.low ? const EdgeInsets.fromLTRB(9, 5, 10, 5) : const EdgeInsets.fromLTRB(8, 6, 11, 6)) : const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEE5D3),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Ttc.line),
                        boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 14, offset: Offset(0, 4))],
                      ),
                      child: t.h == null
                          ? Text(t.t, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ttc.t(13, color: Ttc.sepia, height: 1.4))
                          : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              Text(t.h!, style: Ttc.serif(c.low ? 12.5 : 13.5, color: Ttc.sepia, weight: FontWeight.w700, height: 1.3)),
                              if (t.t.isNotEmpty && !t.folded)
                                Text(t.t, maxLines: c.low ? 2 : 3, overflow: TextOverflow.ellipsis, style: Ttc.t(c.low ? 12.5 : 13, color: Ttc.sepia2, height: c.low ? 1.4 : 1.5)),
                            ]),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class Toast {
  Toast(this.h, this.t, this.life) : max = life;
  final String? h;
  final String t;
  double life;
  final double max;

  /// 제목 카드는 2.4초 뒤 제목 한 줄로 접힌다 (지도·얼굴 줄을 오래 가리지 않게 · 2026-10-20)
  bool get folded => h != null && max - life > 2.4;
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
