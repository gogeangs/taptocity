// 지도 위층: 사람들, 대형 재폭풍 괴물, 밤 어둠, 불빛, 말풍선, 재 눈·날씨, 가장자리 어둠.
// 웹 render 2370–2385 순서(사람 → 괴물 → 밤 어둠 → 불빛 → 말풍선 → 날림 → 비네트)를 그대로 따른다.
// 움직이는 것이 있을 때만 30fps 남짓으로 그리고, 없으면 지도·카메라가 바뀔 때만 다시 그린다.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/web_data.g.dart' as web;
import '../game/data.dart';
import '../game/engine.dart';
import 'atlas.dart';
import 'map_view.dart';
import 'people.dart';
import 'sound.dart';
import 'theme.dart';

class LiveLayer extends StatefulWidget {
  const LiveLayer({super.key, required this.game, required this.camera, required this.life});
  final Game game;
  final Camera camera;
  final Life life;
  @override
  State<LiveLayer> createState() => _LiveLayerState();
}

class _Flake {
  _Flake(math.Random r)
      : x = r.nextDouble(),
        y = r.nextDouble(),
        v = r.nextDouble(),
        s = r.nextDouble(),
        p = r.nextDouble() * 7;
  double x, y, v, s, p;
}

class _LiveLayerState extends State<LiveLayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<int> _frame = ValueNotifier(0);
  Duration _last = Duration.zero, _drawn = Duration.zero;
  double time = 0;
  final _r = math.Random();
  late final List<_Flake> flakes = List.generate(70, (_) => _Flake(_r));
  late final List<_Flake> wparts = List.generate(90, (_) => _Flake(_r));
  late final List<_Flake> rair = List.generate(60, (_) => _Flake(_r)); // 동네의 결 (웹 RAIR)
  Game get g => widget.game;

  bool get _wants {
    final w = g.wxK;
    return g.S.sv.isNotEmpty || g.kids.isNotEmpty || g.pets.isNotEmpty || g.stray != null || g.defn != null || (g.nightness > 0 && g.stormOn) || w == 'acid' || w == 'cold' || w == 'wind' || g.duskWarn || g.shadow != null || g.S.rest['oddSteps'] != null || g.S.gen != 0;
  }

  @override
  void initState() {
    super.initState();
    g.addListener(_wake);
    _wake();
  }

  void _wake() {
    if (!_ticker.isActive && _wants) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration t) {
    final dt = (_last == Duration.zero ? 1 / 30 : (t - _last).inMicroseconds / 1e6).clamp(0.0, .1).toDouble();
    _last = t;
    time += dt * 1000;
    widget.life.step(dt);
    widget.life.stepKidsPets(dt);
    final tr = g.petTrick;
    if (tr != null) {
      g.petTrick = null;
      final w = widget.life.pets[tr.$1];
      if (w != null) {
        g.fx.add(FxFloatAt(w.x, w.y - 30, tr.$3, 0xFFFFE6A0));
        var dy = 46.0;
        tr.$2.forEach((k, v) {
          g.fx.add(FxFloatAt(w.x, w.y - dy, '+$v ${matOf[k]?.n ?? k}', 0xFFFFE6A0));
          dy += 16;
        });
      }
    }
    if (g.defn != null) {
      g.tickDefense(dt);
      if (g.fx.isNotEmpty) g.poke();
    }
    _stepParts(dt);
    if ((t - _drawn).inMilliseconds >= (Prefs.eco ? 66 : 33)) {
      _drawn = t;
      _frame.value++;
    }
    if (!_wants) _ticker.stop();
  }

  void _stepParts(double dt) {
    final fs = dt * 60;
    // 동네의 결: 사막 모래바람 · 공단 재 조각과 불티 · 산골 눈송이 (웹 drawRegionAir 6060)
    final r = g.S.region, tt = time / 1000;
    if (r != null && !Prefs.calm) {
      for (final q in rair) {
        if (r == 'desert') {
          q.x += (.0018 + q.v * .0016) * fs;
          q.y += math.sin(tt + q.p) * .0003 * fs;
          if (q.x > 1.05) {
            q.x = -.05;
            q.y = _r.nextDouble();
          }
        } else if (r == 'factory') {
          q.y += (.0006 + q.v * .0006) * fs;
          q.x += (math.sin(tt * .7 + q.p) * .0004 + .0003) * fs;
          if (q.y > 1.02) {
            q.y = -.02;
            q.x = _r.nextDouble();
          }
        } else if (r == 'snow') {
          q.y += (.0007 + q.v * .0006) * fs;
          q.x += math.sin(tt * .8 + q.p) * .0005 * fs;
          if (q.y > 1.02) {
            q.y = -.02;
            q.x = _r.nextDouble();
          }
        }
      }
    }
    if (g.nightness > 0 && g.stormOn) {
      for (final f in flakes) {
        f.y += (.04 + f.v * .06) * .016 * 6 * fs;
        f.x += .0015 * fs;
        if (f.y > 1) {
          f.y = 0;
          f.x = _r.nextDouble();
        }
        if (f.x > 1) f.x = 0;
      }
    }
    final w = g.wxK;
    for (final p in wparts) {
      final v = .5 + p.v * .6;
      if (w == 'acid') {
        p.y += v * .02 * fs;
        p.x -= .004 * fs;
        if (p.y > 1) {
          p.y = 0;
          p.x = _r.nextDouble();
        }
        if (p.x < 0) p.x = 1;
      } else if (w == 'cold') {
        p.y += v * .004 * fs;
        p.x += math.sin(p.y * 20 + p.s * 6) * .0008 * fs;
        if (p.y > 1) {
          p.y = 0;
          p.x = _r.nextDouble();
        }
      } else if (w == 'wind') {
        p.x += v * .012 * fs;
        if (p.x > 1) {
          p.x = 0;
          p.y = _r.nextDouble();
        }
      }
    }
  }

  @override
  void dispose() {
    g.removeListener(_wake);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(
          painter: _LivePainter(this, Listenable.merge([_frame, widget.camera, g.mapVersion])),
          size: Size.infinite,
        ),
      );
}

/// 새 동네: 숨겨진 자리 표시(웹 townDraw), 잃은 사람의 초(memoDraw), 신기루·멈추지 않은 기계(rspotDraw)
extension on _LivePainter {
  void _region(Canvas canvas, double time, List<(Offset, double, Color, double)> glows) {
    if (g.S.gen == 0) return;
    final Q = g.S.rest['rq'];
    if (Q is Map && Q['spotI'] != null && Q['spot'] == null && g.curRegK == 'spot') {
      final c = tileC((Q['spotI'] as num).toInt(), 14), b = math.sin(time / 320) * 3;
      canvas.drawRect(Rect.fromLTWH(c.dx - 5, c.dy - 90, 10, 90),
          Paint()..shader = ui.Gradient.linear(c, c.translate(0, -90), [const Color(0x80FFE6AA), const Color(0x00FFE6AA)]));
      final o = Offset(c.dx, c.dy - 30 + b);
      canvas.drawCircle(o, 11, Paint()..color = const Color(0xFFFFF8E6));
      canvas.drawCircle(
          o,
          11,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = const Color(0xFF3B2A1A));
      final ico = (web.regionMisc['spotIco'] as Map)[g.S.region] as String? ?? '?';
      final tp = TextPainter(text: TextSpan(text: ico, style: const TextStyle(fontSize: 12, height: 1)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
      glows.add((Offset(c.dx, c.dy - 20), 40.0, const Color(0xFFFFDC96), .5));
    }
    final memo = (g.S.rest['memo'] as Map?)?['${g.S.gen}'];
    if (memo is Map && memo['i'] != null && g.S.rev[(memo['i'] as num).toInt()] == 1) {
      final i = (memo['i'] as num).toInt(), c = tileC(i, 2), f = .85 + .15 * math.sin(time / 180 + i);
      final r = Rect.fromLTWH(c.dx + 12, c.dy - 9, 3.2, 7);
      canvas.drawRect(r, Paint()..color = const Color(0xFFEFE6D2));
      canvas.drawRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .9
            ..color = const Color(0xFF231A14));
      final x = c.dx + 13.6, y = c.dy;
      canvas.drawPath(
          Path()
            ..moveTo(x, y - 15 * f)
            ..quadraticBezierTo(x + 2.4, y - 11, x, y - 9.5)
            ..quadraticBezierTo(x - 2.4, y - 11, x, y - 15 * f)
            ..close(),
          Paint()..color = Color.fromRGBO(255, 207, 122, f));
      glows.add((Offset(x, y - 11), 16.0, const Color(0xFFFFC878), .35 * f));
    }
    final sp = g.rspot;
    if (sp == null) return;
    final i = (sp['i'] as num).toInt();
    if (g.S.rev[i] != 1) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final lf = math.min(1.0, math.min((now - (sp['start'] as num)) / 900, ((sp['end'] as num) - now) / 1500));
    if (lf <= 0) return;
    final c = tileC(i, 4), x = c.dx, y = c.dy;
    if (sp['k'] == 'mirage') {
      final w = math.sin(time / 260);
      for (var q = 0; q < 3; q++) {
        canvas.drawOval(
            Rect.fromCenter(center: c, width: (16 + q * 5 + w * 1.5) * 2, height: (6 + q * 2) * 2),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = Color.fromRGBO(235, 250, 255, .55 * lf * (.55 - q * .15) / .55));
      }
      final wav = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Color.fromRGBO(255, 246, 220, .7 * .8 * lf);
      for (var q = -1; q <= 1; q++) {
        final p = Path();
        for (var k = 0; k < 6; k++) {
          final yy = y - 6 - k * 4, xx = x + q * 8 + math.sin(time / 200 + k + q) * 2;
          k == 0 ? p.moveTo(xx, yy) : p.lineTo(xx, yy);
        }
        canvas.drawPath(p, wav);
      }
      final gl = .6 + .4 * math.sin(time / 180);
      canvas.drawPath(
          Path()
            ..moveTo(x, y - 26)
            ..lineTo(x + 2, y - 21)
            ..lineTo(x + 7, y - 19)
            ..lineTo(x + 2, y - 17)
            ..lineTo(x, y - 12)
            ..lineTo(x - 2, y - 17)
            ..lineTo(x - 7, y - 19)
            ..lineTo(x - 2, y - 21)
            ..close(),
          Paint()..color = Color.fromRGBO(255, 250, 230, gl * lf));
      glows.add((Offset(x, y - 10), 30.0, const Color(0xFFFFECBE), .35 * lf));
    } else {
      final n = ((sp['n'] as num?) ?? 0).toDouble(), need = ((sp['need'] as num?) ?? 8).toDouble(), p2 = .5 + .5 * math.sin(time / 140);
      // 점선 고리 (돌아간다)
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Color.fromRGBO(230, 80, 50, (.5 + .4 * p2) * lf);
      final off = (time / 40) % 7;
      for (var a = 0.0; a < 2 * math.pi; a += .35) {
        final a0 = a + off * .05, a1 = a0 + .2;
        canvas.drawLine(Offset(x + math.cos(a0) * 20, y + math.sin(a0) * 8), Offset(x + math.cos(a1) * 20, y + math.sin(a1) * 8), ring);
      }
      final gy = y - 20, rot = time / (n > 0 ? 120 : 300);
      final gear = Path();
      for (var k = 0; k < 16; k++) {
        final a = rot + k * math.pi / 8, rr = k.isOdd ? 7.5 : 10.0;
        k == 0 ? gear.moveTo(x + math.cos(a) * rr, gy + math.sin(a) * rr) : gear.lineTo(x + math.cos(a) * rr, gy + math.sin(a) * rr);
      }
      gear.close();
      canvas.drawPath(gear, Paint()..color = Color.fromRGBO(58, 53, 50, lf));
      canvas.drawPath(
          gear,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Color.fromRGBO(35, 26, 20, lf));
      canvas.drawCircle(Offset(x, gy), 3.2, Paint()..color = Color.fromRGBO(201, 163, 90, lf));
      if (n > 0) {
        canvas.drawArc(
            Rect.fromCircle(center: Offset(x, gy), radius: 14),
            -math.pi / 2,
            n / need * math.pi * 2,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Color.fromRGBO(255, 207, 122, lf));
      }
      glows.add((Offset(x, gy), 26.0, const Color(0xFFFF9650), (.3 + .2 * p2) * lf));
    }
  }
}

/// 수상한 밤: 발자국(아침), 무전실 불빛, 그림자 (웹 towerDraw 덮어쓰기 5958)
extension on _LivePainter {
  void _odd(Canvas canvas, double time, List<(Offset, double, Color, double)> glows) {
    final st = g.S.rest['oddSteps'];
    if (st is Map && !g.isNight && st['n'] == g.num_('nightCount').toInt()) {
      final a = tileC(C0), b = tileC((st['to'] as num).toInt());
      final p = Paint()..color = const Color(0x80281C14);
      for (var q = 1; q < 14; q++) {
        final f = q / 14, x = a.dx + (b.dx - a.dx) * f + (q.isOdd ? 3 : -3), y = a.dy + (b.dy - a.dy) * f;
        canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 4.4, height: 2.6), p);
      }
    }
    final s = g.shadow;
    if (s == null) return;
    if (s.light != null) {
      final a = s.far ? (s.t < 1.6 ? .8 : 0.0) : math.sin(math.min(1, s.t / s.dur) * math.pi);
      if (s.light! >= 0 && a > 0) {
        final c = tileC(s.light!, 18);
        canvas.drawCircle(c, 46, Paint()..shader = ui.Gradient.radial(c, 46, [Color.fromRGBO(255, 226, 150, .85 * a), const Color(0x00FFE296)]));
        glows.add((c, 40.0, const Color(0xFFFFE296), .6 * a));
      }
      return;
    }
    final (x, y) = s.pos;
    final a = math.max(0.0, math.min(1.0, math.min(s.t / 1.2, (s.dur - s.t) / 1.5)) * .9), bob = math.sin(time / 140) * 1.2;
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y + 1), width: 18, height: 6), Paint()..color = const Color(0x59000000));
    final body = Path()
      ..moveTo(x - 7, y)
      ..quadraticBezierTo(x - 8, y - 18 + bob, x - 4, y - 22 + bob)
      ..lineTo(x + 4, y - 22 + bob)
      ..quadraticBezierTo(x + 8, y - 18 + bob, x + 7, y)
      ..close();
    final fill = Paint()..color = const Color(0xEB08060A);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x73F0E1C8);
    canvas.drawPath(body, fill);
    canvas.drawPath(body, line);
    canvas.drawCircle(Offset(x, y - 27 + bob), 5, fill);
    canvas.drawCircle(Offset(x, y - 27 + bob), 5, line);
    canvas.restore();
  }
}

class _LivePainter extends CustomPainter {
  _LivePainter(this.st, Listenable repaint) : super(repaint: repaint);
  final _LiveLayerState st;
  Game get g => st.g;
  Camera get cam => st.widget.camera;
  Life get life => st.widget.life;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.clipRect(rect);
    final time = st.time, nt = g.nightness;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(cam.z);
    canvas.translate(-cam.x, -cam.y);
    // 일터에서 일하는 사람 (모듈 앞 모서리)
    for (final e in g.S.asg.entries) {
      final id = e.value, m = g.modAtTile(e.key);
      if (!g.hasSv(id) || g.busy(id) || life.walk.containsKey(id) || m == null) continue;
      final p = MapPainter.P(e.key, .9, .9);
      const jobs = {2: 'grow', 3: 'water', 4: 'read', 6: 'care', 7: 'read'};
      drawPerson(canvas, id, p.dx, p.dy, time, false, 1, jobs[m.id] ?? 'repair');
    }
    final glows = [...MapPainter.glows];
    // 노선 역 입구 빛: 숨 쉬듯 (웹 k=.55+.45·sin(t/700) → 반지름 26+8k, 세기 .25+.2k)
    final lk = Prefs.calm ? .7 : .55 + .45 * math.sin(time / 700);
    for (final p in MapPainter.stationGlows) {
      glows.add((p, 26 + 8 * lk, const Color(0xFFFFC46E), .25 + .2 * lk));
    }
    final list = life.walk.entries.toList()..sort((a, b) => a.value.y.compareTo(b.value.y));
    if (g.isNight && list.isNotEmpty) {
      final c = tileC(C0);
      glows.add((Offset(c.dx, c.dy + 14), 70.0, const Color(0xFFFFAA50), .25));
    }
    for (final e in list) {
      drawPerson(canvas, e.key, e.value.x, e.value.y, time, e.value.mv, e.value.face, null);
    }
    // 아이들
    final ks = g.kids;
    for (var n = 0; n < ks.length && n < life.kids.length; n++) {
      final w = life.kids[n];
      drawPerson(canvas, -1, w.x, w.y, time, w.mv, w.face, null,
          look: ks[n]['look'] as Map?, age: ((ks[n]['g'] as num?) ?? 0) < 1 ? 8 : 18, name: ks[n]['n'] as String?, kidJob: ks[n]['job'] as String?);
    }
    // 노친네가 온 날: 수레를 세워 두고 쉘터 앞에 서 있다 (웹 pedMapDraw, walkers-2 17번 칸)
    if (g.pedHere) {
      final c = tileC(C0);
      figureAt(canvas, (1, 16), c.dx + 46, c.dy + 30, time, face: -1);
    }
    // 펫
    final night = g.isNight;
    life.pets.forEach((k, w) {
      final p = g.pets[k];
      if (p == null) return;
      canvas.save();
      canvas.translate(w.x, w.y);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: k == 'owl' ? 8 : 12, height: 4), Paint()..color = const Color(0x470A0805));
      canvas.scale(w.face * 1.15, 1.15);
      drawPet(canvas, k, time, w.mv, Color(collarColors[((p['c'] as num?) ?? 0).toInt() % collarColors.length]), night);
      canvas.restore();
      if (k == 'fox' && night) glows.add((Offset(w.x, w.y - 6), 26.0, const Color(0xFFC8DCFF), .45));
    });
    for (final h in life.hearts) {
      if (h.$3 < 0) continue;
      final a = 1 - h.$3 / 1.2, x = h.$1 + math.sin(h.$3 * 6 + h.$4) * 3, y = h.$2 - h.$3 * 24;
      final path = Path()
        ..moveTo(x, y + 2.5)
        ..cubicTo(x - 4, y - 1, x - 2, y - 4, x, y - 1.6)
        ..cubicTo(x + 2, y - 4, x + 4, y - 1, x, y + 2.5);
      canvas.drawPath(path, Paint()..color = Color.fromRGBO(230, 90, 90, a));
    }
    // 떠돌이 동물: 발자국과 흐릿한 모습
    final s0 = g.stray;
    if (s0 != null && g.strayVis) {
      final k = s0['k'] as String, c = tileC((s0['i'] as num).toInt()), n = ((s0['n'] as num?) ?? 0), need = ((s0['need'] as num?) ?? 3);
      final a = .35 + .6 * math.min(1, n / math.max(1, need - 1));
      final fp = Paint()..color = k == 'fox' ? const Color(0xCCD7E6FF) : const Color(0x8C3C2819);
      for (var q = 0; q < 5; q++) {
        final px = c.dx - 30 + q * 7, py = c.dy + 10 - q * 2.5 + (q.isOdd ? 2 : -1);
        canvas.drawOval(Rect.fromCenter(center: Offset(px, py), width: 3.2, height: 2), fp);
        canvas.drawOval(Rect.fromCenter(center: Offset(px - 1.4, py - 1.8), width: 1.2, height: 1), fp);
        canvas.drawOval(Rect.fromCenter(center: Offset(px + 1.4, py - 1.8), width: 1.2, height: 1), fp);
      }
      canvas.save();
      canvas.translate(c.dx + 4, c.dy + 4);
      canvas.scale(-1.25, 1.25);
      drawPet(canvas, k, time, false, const Color(0xFF8A7A64), k == 'fox', alpha: a);
      canvas.restore();
      final by = c.dy - 24 - (math.sin(time / 300)).abs() * 4;
      canvas.drawCircle(Offset(c.dx + 4, by), 7, Paint()..color = const Color(0xFFFFF8E6));
      canvas.drawCircle(
          Offset(c.dx + 4, by),
          7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(0xFF3B2A1A));
      final tp = TextPainter(text: TextSpan(text: n > 0 ? '♥' : '?', style: Ttc.t(10, color: Ttc.no, weight: FontWeight.w700, height: 1)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(c.dx + 4 - tp.width / 2, by - tp.height / 2));
      if (k == 'fox') glows.add((Offset(c.dx, c.dy - 6), 30.0, const Color(0xFFC8DCFF), .4));
    }
    // 보급 더미 ✦: 퍼지는 고리 두 겹 + 반짝임 (앱 시즌 1 다듬기)
    final sp = g.supply;
    if (sp != null) {
      final c = MapPainter.P((sp['i'] as num).toInt(), .5, .5, 10);
      final calm = Prefs.calm;
      for (var q = 0; q < 2; q++) {
        final p = calm ? .5 : ((time / 1400 + q * .5) % 1);
        canvas.drawOval(Rect.fromCenter(center: c, width: (18 + p * 26) * 2, height: (9 + p * 13) * 2),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Color.fromRGBO(255, 214, 120, (1 - p) * .85));
      }
      final tw = calm ? 1.0 : .75 + .25 * math.sin(time / 260);
      final star = Path();
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4, r = k.isEven ? 9.0 * tw : 3.2;
        final pt = c.translate(math.cos(a) * r, -26 + math.sin(a) * r);
        if (k == 0) {
          star.moveTo(pt.dx, pt.dy);
        } else {
          star.lineTo(pt.dx, pt.dy);
        }
      }
      star.close();
      canvas.drawPath(star, Paint()..color = const Color(0xFFFFE08A));
      canvas.drawPath(
          star,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(0xFF6B4A1C));
      glows.add((c, 34.0, const Color(0xFFFFD27A), .45));
    }
    // 노선 역 '노선' 표식 (웹 lnBadge — 지도 그림과 같이 밤 어둠 아래)
    for (final b in MapPainter.badges) {
      MapPainter.lnBadge(canvas, b.$1, b.$2, time, b.$3, b.$4, calm: Prefs.calm);
    }
    _odd(canvas, time, glows);
    _region(canvas, time, glows);
    _foes(canvas, time, glows);
    canvas.restore();

    // 밤 어둠: 불빛 자리에 구멍을 낸다 (웹 drawNightLight)
    Offset scr(Offset w) => Offset((w.dx - cam.x) * cam.z + size.width / 2, (w.dy - cam.y) * cam.z + size.height / 2);
    if (nt <= .01) {
      canvas.drawRect(rect, Paint()..color = const Color(0x14281E50));
    } else {
      canvas.saveLayer(rect, Paint());
      // 앱 시즌 1 다듬기(2026-10-17): 밤을 조금 더 어둡게, 대형 재폭풍 밤은 더 (웹 .1 + .58·nt). 불빛 구멍은 그대로라 길은 보인다
      final na = math.min(.82, .1 + (.64 + (g.defn != null ? .1 : g.stormOn ? .03 : 0)) * nt);
      canvas.drawRect(rect, Paint()..color = Color.fromRGBO((30 - 16 * nt).round(), (26 - 8 * nt).round(), (70 - 24 * nt).round(), na));
      void hole(Offset w, double r0, double a0) {
        final s = scr(w), r = r0 * cam.z;
        if (s.dx < -r || s.dy < -r || s.dx > size.width + r || s.dy > size.height + r) return;
        canvas.drawCircle(
            s,
            r,
            Paint()
              ..blendMode = BlendMode.dstOut
              ..shader = ui.Gradient.radial(s, r, [Color.fromRGBO(0, 0, 0, a0), Color.fromRGBO(0, 0, 0, a0 * .55), const Color(0x00000000)], [0, .55, 1]));
      }

      for (final (c, r0, _, a0) in glows) {
        hole(c.translate(0, 6), r0 * 2.3, math.min(.95, a0 * 1.7));
      }
      hole(tileC(C0, 10), 110.0 + g.S.lv * 28, .9);
      if (g.aimValid) hole(tileC(g.aim, 8), 70, .6);
      for (final k in g.S.ash.keys) {
        hole(tileC(int.parse(k), 6), 40, .55);
      }
      if (g.defn != null) hole(tileC(C0), 400, .5);
      canvas.restore();
    }
    // 불빛 (더하기 합성)
    for (final (c, r0, col, a0) in glows) {
      final s = scr(c), r = r0 * (1 + nt * .2) * cam.z, a = math.min(.85, a0 * (.75 + nt * .45));
      canvas.drawCircle(
          s,
          r,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = ui.Gradient.radial(s, r, [col.withValues(alpha: a), col.withValues(alpha: 0)]));
    }
    _bubble(canvas, size);
    // 재폭풍 밤의 재 눈송이 · 날씨
    if (nt > 0 && g.stormOn) {
      final p = Paint()..color = Color.fromRGBO(170, 165, 158, .45 * nt);
      for (final f in st.flakes) {
        final s = 1 + f.s * 2;
        canvas.drawRect(Rect.fromLTWH(f.x * size.width, f.y * size.height, s, s), p);
      }
    }
    _regionAir(canvas, size);
    if (!Prefs.calm) _weather(canvas, size);
    // 큰 밤이 다가오면 가장자리가 붉게 (웹 #stage.danger)
    if (g.duskWarn) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..color = const Color(0x47AB5145)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawRect(rect.deflate(4), p);
    }
    // 가장자리 어둡게 (웹 비네트, 피버 중엔 주황)
    final c = size.center(Offset.zero), mn = math.min(size.width, size.height), mx = math.max(size.width, size.height);
    canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
              c, mx * .75, [const Color(0x00000000), const Color(0x00000000), g.fever > 0 ? const Color(0x73783C0A) : const Color(0x80000000)], [0, (mn * .35) / (mx * .75), 1]));
  }

  /// 동네마다 하늘빛(아지랑이)과 날리는 것 (웹 HAZE·drawRegionAir)
  void _regionAir(Canvas canvas, Size size) {
    final r = g.S.region;
    if (r == null || g.ug != null) return;
    const haze = {
      'desert': [(255, 214, 150, .16), (255, 190, 120, 0.0)],
      'factory': [(96, 70, 52, .28), (60, 52, 48, .1)],
      'snow': [(220, 232, 245, .14), (200, 215, 232, 0.0)],
    };
    final hz = haze[r];
    if (hz != null) {
      final nt = g.isNight ? .45 : 1.0, a = hz[0], b = hz[1];
      canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
              Color.fromRGBO(a.$1, a.$2, a.$3, a.$4 * nt),
              Color.fromRGBO(b.$1, b.$2, b.$3, b.$4 * nt),
              Color.fromRGBO(b.$1, b.$2, b.$3, (r == 'factory' ? .16 : 0) * nt),
            ], [0, .55, 1]));
    }
    if (Prefs.calm) return;
    final n = Prefs.eco ? 30 : st.rair.length, W0 = size.width, H0 = size.height;
    if (r == 'desert') {
      final p = Paint()
        ..color = const Color.fromRGBO(214, 184, 128, .17)
        ..strokeWidth = 1.3;
      for (var k = 0; k < n; k++) {
        final q = st.rair[k], x = q.x * W0, y = q.y * H0;
        canvas.drawLine(Offset(x, y), Offset(x + 18 + q.s * 26, y), p);
      }
    } else if (r == 'factory') {
      final ash = Paint()..color = const Color.fromRGBO(58, 54, 52, .45), em = Paint()..color = const Color.fromRGBO(255, 170, 80, .8);
      for (var k = 0; k < n; k++) {
        final q = st.rair[k];
        if (q.s > .9) {
          canvas.drawRect(Rect.fromLTWH(q.x * W0, q.y * H0, 1.8, 1.8), em);
        } else {
          final z = 1.4 + q.s * 1.8;
          canvas.drawRect(Rect.fromLTWH(q.x * W0, q.y * H0, z, z * .7), ash);
        }
      }
    } else if (r == 'snow' && g.wxK != 'cold') {
      final p = Paint()..color = const Color.fromRGBO(244, 248, 252, .6);
      for (var k = 0; k < n; k++) {
        final q = st.rair[k], z = 1.4 + q.s * 1.6;
        canvas.drawRect(Rect.fromLTWH(q.x * W0, q.y * H0, z, z), p);
      }
    }
  }

  void _weather(Canvas canvas, Size size) {
    final w = g.wxK;
    if (w == 'acid') {
      final p = Paint()
        ..color = const Color(0x59AAC896)
        ..strokeWidth = 1;
      for (final q in st.wparts) {
        canvas.drawLine(Offset(q.x * size.width, q.y * size.height), Offset(q.x * size.width - 3, q.y * size.height + 10), p);
      }
    } else if (w == 'cold') {
      final p = Paint()..color = const Color(0xB3F0F5FF);
      for (final q in st.wparts) {
        final s = 1.6 + q.s * 1.4;
        canvas.drawRect(Rect.fromLTWH(q.x * size.width, q.y * size.height, s, s), p);
      }
    } else if (w == 'wind') {
      final p = Paint()
        ..color = const Color(0x47C8BEAA)
        ..strokeWidth = 1;
      for (final q in st.wparts) {
        canvas.drawLine(Offset(q.x * size.width, q.y * size.height), Offset(q.x * size.width + 14 + q.s * 10, q.y * size.height + 1), p);
      }
    }
  }

  /// 대형 재폭풍 괴물 (웹 drawFoes)
  // ash-foes.webp 칸 (웹 chapter-design.js ff: x, y, 폭, 높이) — 보통 다가옴 · 보통 공격 · 덩치 다가옴 · 덩치 공격
  static const _foeFrames = [Rect.fromLTWH(121, 52, 465, 539), Rect.fromLTWH(648, 66, 572, 524), Rect.fromLTWH(33, 635, 575, 573), Rect.fromLTWH(647, 655, 573, 561)];

  void _foes(Canvas canvas, double time, List<(Offset, double, Color, double)> glows) {
    final D2 = g.defn;
    if (D2 == null) return;
    final c = tileC(C0);
    final stroke = Paint()..style = PaintingStyle.stroke;
    stroke
      ..color = Color.fromRGBO(226, 100, 79, .35 + .25 * math.sin(time / 200))
      ..strokeWidth = 2;
    _dashedOval(canvas, Rect.fromCenter(center: c, width: 68, height: 34), stroke, 6, 6, 0);
    final uf = g.urgentFoe;
    if (uf != null) {
      stroke
        ..color = const Color(0xD9FF5A3C)
        ..strokeWidth = 2;
      final rx = uf.brute ? 26.0 : 18.0, ry = uf.brute ? 26.0 : 19.0;
      _dashedOval(canvas, Rect.fromCenter(center: Offset(uf.x, uf.y - (uf.brute ? 24 : 17)), width: rx * 2, height: ry * 2), stroke, 4, 4, time / 50);
    }
    if (D2.trail.length > 1) {
      final path = Path()..moveTo(D2.trail.first.$1, D2.trail.first.$2);
      for (final p in D2.trail.skip(1)) {
        path.lineTo(p.$1, p.$2);
      }
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xCCFFE6AA));
    }
    final fill = Paint();
    // 손그림 재 괴물 (웹 chapter-design.js foe): 보통·덩치 × 다가옴·공격. 그림이 아직 없으면 아래 덩어리 그림으로
    final art = Atlas.image('ash-foes.webp');
    if (art != null) {
      for (final f in D2.foes) {
        if (f.delay > 0) continue;
        final attack = f.hit > 0, idx = (f.brute ? 2 : 0) + (attack ? 1 : 0), a = _foeFrames[idx];
        final h = f.brute ? 49.0 : 35.0, w = h * a.width / a.height, bob = math.sin(time / 230 + f.ph) * 1.1;
        fill.color = const Color(0x590A0805);
        canvas.drawOval(Rect.fromCenter(center: Offset(f.x, f.y), width: w * .7, height: w * .22), fill);
        canvas.save();
        canvas.translate(f.x, f.y + bob);
        final facing = idx == 3 ? 1.0 : -1.0;
        canvas.scale((c.dx >= f.x ? 1.0 : -1.0) * facing, 1);
        canvas.drawImageRect(art, a, Rect.fromLTWH(-w / 2, -h, w, h), Paint()..filterQuality = FilterQuality.medium);
        canvas.restore();
        if (attack) {
          canvas.drawOval(
              Rect.fromCenter(center: Offset(f.x, f.y - h * .45), width: w * .68, height: h * .54),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.6
                ..color = Color.fromRGBO(255, 224, 161, math.min(.9, f.hit.toDouble())));
        }
        glows.add((Offset(f.x, f.y - h * .7), f.brute ? 12.0 : 9.0, const Color(0xFFFF5032), .35));
        final bw = f.brute ? 40.0 : 28.0;
        fill.color = const Color(0xB30D0B08);
        canvas.drawRect(Rect.fromLTWH(f.x - bw / 2, f.y - h - 7, bw, 3.5), fill);
        fill.color = const Color(0xFFE2644F);
        canvas.drawRect(Rect.fromLTWH(f.x - bw / 2, f.y - h - 7, bw * math.max(0, f.hp / f.max), 3.5), fill);
      }
    }
    for (final f in D2.foes) {
      if (art != null) break;
      if (f.delay > 0) continue;
      final s = f.brute ? 2.0 : 1.3, bob = math.sin(time / 180 + f.ph) * 2, x = f.x, y = f.y - 10 * s + bob;
      fill.color = const Color(0x590A0805);
      canvas.drawOval(Rect.fromCenter(center: Offset(f.x, f.y), width: 20 * s, height: 8 * s), fill);
      for (var k = 0; k < 5; k++) {
        final a = time / 300 + k * 1.3 + f.ph, r = (6 + k % 3 * 2) * s;
        fill.color = k.isOdd ? const Color(0xFF2E2A26) : const Color(0xFF45403A);
        canvas.drawCircle(Offset(x + math.cos(a) * 3 * s, y + math.sin(a) * 2 * s - k * 1.5 * s), r, fill);
      }
      fill.color = f.hit > 0 ? Colors.white : const Color(0xFFFF5A3C);
      canvas.drawCircle(Offset(x - 3 * s, y - 4 * s), 1.8 * s, fill);
      canvas.drawCircle(Offset(x + 3 * s, y - 4 * s), 1.8 * s, fill);
      glows.add((Offset(x, y - 4 * s), 10 * s, const Color(0xFFFF5032), .5));
      final bw = 22 * s;
      fill.color = const Color(0xB30D0B08);
      canvas.drawRect(Rect.fromLTWH(x - bw / 2, y - 18 * s, bw, 3.5), fill);
      fill.color = const Color(0xFFE2644F);
      canvas.drawRect(Rect.fromLTWH(x - bw / 2, y - 18 * s, bw * math.max(0, f.hp / f.max), 3.5), fill);
    }
    for (final b in D2.beams) {
      canvas.drawLine(
          Offset(b.x0, b.y0),
          Offset(b.x1, b.y1),
          Paint()
            ..strokeWidth = 2
            ..color = Color(b.color).withValues(alpha: math.min(1, b.t * 5)));
    }
  }

  void _dashedOval(Canvas canvas, Rect r, Paint p, double on, double off, double offset) {
    final path = Path()..addOval(r);
    for (final m in path.computeMetrics()) {
      var d = -(offset % (on + off));
      while (d < m.length) {
        final a = math.max(0.0, d), b = math.min(m.length, d + on);
        if (b > a) canvas.drawPath(m.extractPath(a, b), p);
        d += on + off;
      }
    }
  }

  /// 말풍선 (웹 drawBubbles)
  void _bubble(Canvas canvas, Size size) {
    final c = life.chat;
    life.bubbleRect = null;
    if (c == null || c.lines.isEmpty) return;
    final k = math.min(c.lines.length - 1, (c.t / (c.dur / c.lines.length)).floor());
    final (who, txt0) = c.lines[k];
    final w = life.walk[who];
    if (w == null) return;
    final sx = (w.x - cam.x) * cam.z + size.width / 2, sy = (w.y - 26 - cam.y) * cam.z + size.height / 2;
    final t = txt0.length > 18 ? '${txt0.substring(0, 17)}…' : txt0;
    final tp = TextPainter(text: TextSpan(text: t, style: Ttc.t(12, color: const Color(0xFF3B2A1A), weight: FontWeight.w600, height: 1)), textDirection: TextDirection.ltr)..layout();
    final tw = tp.width + (c.solo ? 16 : 30), bx = (sx - tw / 2).clamp(8.0, math.max(8.0, size.width - tw - 8)).toDouble(), by = sy - 26;
    final rr = RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, tw, 22), const Radius.circular(9));
    final fill = Paint()..color = const Color(0xF5EFE3C4);
    canvas.drawRRect(rr, fill);
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFF3B2A1A));
    canvas.drawPath(Path()..moveTo(sx - 4, by + 21)..lineTo(sx, by + 28)..lineTo(sx + 4, by + 21)..close(), fill);
    tp.paint(canvas, Offset(bx + 8, by + 11.5 - tp.height / 2));
    life.bubbleRect = c.solo ? null : Rect.fromLTWH(bx, by, tw, 28);
    if (!c.solo) {
      final ar = TextPainter(text: TextSpan(text: '›', style: Ttc.t(14, color: Ttc.no, weight: FontWeight.w600, height: 1)), textDirection: TextDirection.ltr)..layout();
      ar.paint(canvas, Offset(bx + tw - 18, by + 11.5 - ar.height / 2));
    }
  }

  @override
  bool shouldRepaint(_LivePainter old) => true;
}
