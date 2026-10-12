// 지도 위를 걷는 생존자 (웹 tickLife 3907 · drawLife · drawWorker · drawBubbles, 그림은 people.js).
// 보여 주기만 한다: 게임 상태를 바꾸지 않는다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/web_data.g.dart' as web;
import '../game/data.dart';
import '../game/engine.dart';
import 'map_view.dart';

class Walk {
  Walk(this.x, this.y, {this.idle = 0, this.brk = 0}) : tx = x, ty = y;
  double x, y, tx, ty, idle, brk;
  double face = 1;
  bool mv = false;
}

class Chat {
  Chat(this.a, this.b, this.dur, this.lines, {this.solo = false});
  final int a, b;
  final double dur;
  final List<(int, String)> lines;
  final bool solo;
  double t = 0;
}

class Life {
  Life(this.g);
  final Game g;
  final Map<int, Walk> walk = {};
  final _r = math.Random();
  double _chatT = 8;
  Chat? chat;

  List<int> _lifeTiles() {
    final S = g.S, R = S.lv + 1, o = <int>[];
    for (var y = CY - R; y <= CY + R; y++) {
      for (var x = CX - R; x <= CX + R; x++) {
        if (x < 0 || y < 0 || x >= W || y >= H) continue;
        final i = y * W + x;
        if (S.rev[i] == 0 || S.ter[i] == T.water || i == C0 || g.modAt.containsKey(i)) continue;
        o.add(i);
      }
    }
    return o;
  }

  Offset _spot(bool night) {
    if (night) {
      final c = tileC(C0), a = _r.nextDouble() * math.pi * 2;
      return Offset(c.dx + math.cos(a) * 44, c.dy + 14 + math.sin(a) * 18);
    }
    final L = _lifeTiles();
    if (L.isEmpty) return tileC(C0) + const Offset(20, 20);
    final c = tileC(L[_r.nextInt(L.length)]);
    return Offset(c.dx + (_r.nextDouble() - .5) * 22, c.dy + (_r.nextDouble() - .5) * 8);
  }

  void step(double dt) {
    final night = g.isNight && g.defn == null;
    final ids = g.svIds.toList();
    walk.removeWhere((id, _) => !ids.contains(id));
    for (final id in ids) {
      final r = g.rec(id)!;
      final free = r['away'] != true && !(((r['hurt'] as num?) ?? 0) > 0), working = g.atOf(id) >= 0;
      var w = walk[id];
      if (!free) {
        walk.remove(id);
        continue;
      }
      if (w == null) {
        if (working && !night) continue;
        final p = working ? tileC(g.atOf(id)) : _spot(night);
        w = walk[id] = Walk(p.dx, p.dy, idle: 1 + _r.nextDouble() * 3, brk: working ? 12 + _r.nextDouble() * 10 : 0);
      }
      if (working && !night && w.brk <= 0) {
        walk.remove(id);
        continue;
      }
      if (w.brk > 0) w.brk -= dt;
      final dx = w.tx - w.x, dy = w.ty - w.y, d = math.sqrt(dx * dx + dy * dy);
      if (d > 2) {
        final sp = (night ? 26 : 18) * dt;
        w.x += dx / d * math.min(sp, d);
        w.y += dy / d * math.min(sp, d);
        w.face = dx >= 0 ? 1 : -1;
        w.mv = true;
      } else {
        w.mv = false;
        w.idle -= dt;
        if (w.idle <= 0) {
          final p = _spot(night);
          w.tx = p.dx;
          w.ty = p.dy;
          w.idle = 2 + _r.nextDouble() * 4;
        }
      }
    }
    // 일하던 사람도 가끔 쉬러 나온다
    for (final id in ids) {
      final r = g.rec(id)!, at = g.atOf(id);
      if (at >= 0 && r['away'] != true && !(((r['hurt'] as num?) ?? 0) > 0) && !walk.containsKey(id) && !g.isNight && _r.nextDouble() < dt / 55) {
        final c = tileC(at);
        walk[id] = Walk(c.dx, c.dy, brk: 14 + _r.nextDouble() * 10);
      }
    }
    final c = chat;
    if (c != null) {
      c.t += dt;
      if (c.t > c.dur || !walk.containsKey(c.a) || !walk.containsKey(c.b)) chat = null;
    } else if (g.defn == null) {
      _chatT -= dt;
      if (_chatT <= 0) {
        _chatT = 9 + _r.nextDouble() * 9;
        final ws = walk.keys.toList();
        (int, int)? best;
        var bd = 1e9;
        for (var i = 0; i < ws.length; i++) {
          for (var j = i + 1; j < ws.length; j++) {
            final k = _pair(ws[i], ws[j]);
            if (k == '10-13') continue;
            final a = walk[ws[i]]!, b = walk[ws[j]]!;
            final d = math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2)) + (web.pairs.containsKey(k) ? -60 : 0) + _r.nextDouble() * 30;
            if (d < bd) {
              bd = d;
              best = (ws[i], ws[j]);
            }
          }
        }
        if (best != null && bd < 120) {
          final (a, b) = best;
          final wa = walk[a]!, wb = walk[b]!, mx = (wa.x + wb.x) / 2, my = (wa.y + wb.y) / 2;
          wa
            ..tx = mx - 12
            ..ty = my
            ..idle = 9;
          wb
            ..tx = mx + 12
            ..ty = my
            ..idle = 9;
          chat = Chat(a, b, 8, _convo(a, b));
        } else if (ws.isNotEmpty) {
          final a = ws[_r.nextInt(ws.length)];
          final sm = _small(a);
          final nl = [for (final t in web.nightLine) t as String];
          if (g.isNight) {
            chat = Chat(a, a, 4, [(a, nl[_r.nextInt(nl.length)])], solo: true);
          } else if (sm.isNotEmpty) {
            chat = Chat(a, a, 4, [(a, sm[_r.nextInt(sm.length)])], solo: true);
          }
        }
      }
    }
  }

  static String _pair(int a, int b) => a < b ? '$a-$b' : '$b-$a';
  List<String> _small(int id) => [for (final s in (web.small['$id'] as List?) ?? const []) s as String];
  List<(int, String)> _convo(int a, int b) {
    final p = web.pairs[_pair(a, b)] as List?;
    if (p != null) return [for (final l in p) ((l as List)[0] as int, l[1] as String)];
    final r = _r.nextInt(3), sa = _small(a), sb = _small(b);
    return [if (sa.isNotEmpty) (a, sa[r % sa.length]), if (sb.isNotEmpty) (b, sb[(r + 1) % sb.length])];
  }

  bool get busy => walk.isNotEmpty || g.S.asg.isNotEmpty;

  /// 세계 좌표 가까이의 사람 (웹 personAt)
  int? personAt(Offset w, double reach) {
    int? best;
    var bd = reach * reach;
    walk.forEach((id, p) {
      final d = (Offset(p.x, p.y - 8) - w).distanceSquared;
      if (d < bd) {
        bd = d;
        best = id;
      }
    });
    return best;
  }
}

// ======================= 사람 그림 (people.js person) =======================
const _ink = Color(0xFF24282A), _cream = Color(0xFFD7CBB0);
const _styles = [
  (0xFF445665, 'cap', 'short', 1.08), (0xFF41494B, 'helmet', 'short', .96),
  (0xFF527C78, 'mask', 'bun', .91), (0xFFA64E3E, 'hood', 'bob', .9),
  (0xFF53695A, 'scarf', 'bun', 1.02), (0xFFB7A58A, 'apron', 'curl', 1.13),
  (0xFF4A5B69, 'vest', 'short', 1.12), (0xFF586A78, 'beret', 'bob', .9),
  (0xFF9E5145, 'firehelm', 'short', 1.06), (0xFF858780, 'glasses', 'short', .96),
  (0xFF655E73, 'headphones', 'long', .95), (0xFF4E7878, 'bag', 'long', .9),
  (0xFF74624D, 'waistcoat', 'short', .94), (0xFFBA764A, 'stripe', 'bob', .99),
  (0xFFB39A58, 'scarf', 'bun', .9), (0xFF4D606D, 'goggles', 'short', 1.1),
  (0xFFA75043, 'pack', 'bob', .93), (0xFF4D5050, 'scarf', 'short', .86),
];

Color _hex(Object? s, Color d) => s is String && s.startsWith('#') && s.length == 7 ? Color(int.parse(s.substring(1), radix: 16) | 0xFF000000) : d;

void drawPerson(Canvas g, int id, double x, double y, double time, bool moving, double face, String? job) {
  final sv = survivors[id];
  final L = (id < web.surv.length ? web.surv[id]['look'] : null) as Map? ?? const {};
  final st = id < _styles.length ? _styles[id] : null;
  final top = st != null ? Color(st.$1) : _hex(L['top'], const Color(0xFF6E7B77));
  final acc = st?.$2 ?? (L['acc'] as String? ?? '');
  final hair = st?.$3 ?? 'short';
  final skin = _hex(L['skin'], const Color(0xFFD5AC88)), hairC = _hex(L['hair'], _ink);
  final child = sv.age < 13, scale = child ? .78 : sv.age < 18 ? .9 : 1.0, width = st?.$4 ?? .94;
  final phase = time / (child ? 135 : 165) + id * .71;
  final stride = moving ? math.sin(phase) * 2.1 : 0.0, work = job != null ? math.sin(phase * .7) : 0.0;
  final bob = moving ? (math.sin(phase)).abs() * .65 : 0.0;
  g.save();
  g.translate(x, y);
  g.scale(scale, scale);
  g.drawOval(Rect.fromCenter(center: const Offset(0, .5), width: 11.6, height: 4), Paint()..color = const Color(0x420F1519));
  g.scale(face < 0 ? -1 : 1, 1);
  g.translate(0, -bob);
  final fill = Paint(), stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  void poly(List<List<double>> p, Color c, {Color? line = _ink}) {
    final path = Path()..moveTo(p[0][0], p[0][1]);
    for (var i = 1; i < p.length; i++) {
      path.lineTo(p[i][0], p[i][1]);
    }
    path.close();
    g.drawPath(path, fill..color = c);
    if (line != null) {
      g.drawPath(
          path,
          stroke
            ..color = line
            ..strokeWidth = .65);
    }
  }

  void line(List<List<double>> p, Color c, double w) {
    final path = Path()..moveTo(p[0][0], p[0][1]);
    for (var i = 1; i < p.length; i++) {
      path.lineTo(p[i][0], p[i][1]);
    }
    g.drawPath(
        path,
        stroke
          ..color = c
          ..strokeWidth = w);
  }

  void oval(double x, double y, double rx, double ry, Color c) => g.drawOval(Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2), fill..color = c);

  for (final side in const [-1.0, 1.0]) {
    final step = stride * side;
    line([[side * 1.7, -9], [side * 1.7 + step * .4, -4.5], [side * 1.7 + step, 0]], _ink, 3.1);
    line([[side * 1.7, -8], [side * 1.7 + step * .4, -4.5]], const Color(0xFF59636A), 1.8);
    line([[side * 1.7 + step, 0], [side * 1.7 + step + 1.7, .1]], const Color(0xFF303235), 2.1);
  }
  if (const ['pack', 'bag', 'helmet'].contains(acc)) poly([[-5, -19], [-7, -17], [-6.5, -10], [-3, -10], [-3, -18]], const Color(0xFF665C4D));
  if (hair == 'long' || hair == 'bob') poly([[-3.5, -25], [-5, -23], [-4.5, hair == 'long' ? -14 : -19], [1, -18], [3, -23]], hairC);
  final w = 4.1 * width;
  poly([[-w, -18.5], [-2, -20], [2, -20], [w, -18], [w + .5, -9], [-w, -8.5]], top);
  poly([[-w, -18], [-w + .8, -10], [-1, -9], [-1, -19]], const Color(0x33141D21), line: null);
  poly([[-2, -20], [0, -17.6], [2, -20], [1, -15]], const Color(0xFFC2B7A0));
  line([[.4, -17], [.4, -10]], const Color(0x991C2121), .65);
  line([[-3, -13], [-1.5, -13]], _cream, .6);
  if (acc == 'apron' || acc == 'waistcoat') poly([[-2.8, -17], [2.8, -17], [3.2, -9], [-3, -9]], acc == 'apron' ? const Color(0xFF9B5141) : const Color(0xFF5D5143));
  if (acc == 'vest') {
    for (final a in const [-1.0, 1.0]) {
      poly([[a * 1.8, -19], [a * 3.5, -18], [a * 3.9, -10], [a * 1.5, -10]], const Color(0xFFB57C47));
    }
  }
  if (const ['helmet', 'firehelm', 'stripe', 'vest'].contains(acc)) line([[-3.8, -12], [3.8, -12]], const Color(0xFFCBBD87), 1.3);
  if (const ['scarf', 'hood', 'pack'].contains(acc)) {
    poly([[-3, -20], [3, -20], [2, -16.5], [-2, -17]], acc == 'scarf' ? const Color(0xFF929084) : const Color(0xFF3A4448));
    if (acc == 'scarf') poly([[-2, -18], [0, -18], [-.8, -12], [-2.5, -13]], const Color(0xFF81867F));
  }
  final handY = job != null ? -12 + work * 1.4 : -10 + stride * .4;
  line([[-w, -18], [-w - 1, -14], [-w - 1 - stride * .3, -10]], _ink, 3.3);
  line([[-w, -18], [-w - 1, -14]], top, 2.3);
  oval(-w - 1 - stride * .3, -9.8, 1.15, 1.35, skin);
  line([[w, -18], [w + 1, -14], [w + 1.3 + stride * .3, handY]], _ink, 3.3);
  line([[w, -18], [w + 1, -14]], top, 2.3);
  oval(w + 1.3 + stride * .3, handY, 1.15, 1.4, skin);
  poly([[-2.5, -25.5], [1, -26], [3.5, -24], [3.5, -21.5], [1.6, -19.5], [-1.8, -20], [-3.1, -22]], skin);
  poly([[-3.2, -23], [-3.7, -25], [-1.6, -27], [1.5, -27.2], [3.2, -25], [1, -24.7], [-1.5, -25.1]], hairC);
  if (hair == 'bun') oval(-3.7, -24, 2.3, 2.5, hairC);
  if (hair == 'curl') {
    for (final a in const [-3.0, -1.0, 1.0, 3.0]) {
      oval(a, -25.8, 1.8, 1.6, hairC);
    }
  }
  line([[1.3, -23], [2.2, -23]], _ink, .75);
  if (sv.age > 55) line([[-1.5, -20.5], [1, -20]], const Color(0xFFC4BBA8), 1);
  if (const ['cap', 'beret', 'helmet', 'firehelm', 'vest'].contains(acc)) {
    final c = acc == 'helmet' || acc == 'vest' ? const Color(0xFFC4A153) : acc == 'firehelm' ? const Color(0xFFA05144) : const Color(0xFF3E505E);
    poly([[-4, -25], [-3.5, -28], [.6, -29], [3.5, -27.5], [4, -25]], c);
    line([[-3.5, -25], [4.6, -25.1]], _ink, 1.1);
    if (acc == 'cap' || acc == 'firehelm') poly([[.5, -25], [5.5, -25], [4.4, -24], [1, -24]], c);
    if (acc == 'beret') oval(-2, -27.3, 3.2, 1.6, c);
  }
  if (acc == 'glasses' || acc == 'goggles') {
    final yy = acc == 'glasses' ? -23.0 : -26.0;
    line([[-1.3, yy], [3.8, yy]], _ink, .65);
    for (final xx in const [-.5, 2.5]) {
      poly([[xx - 1, yy - 1], [xx + 1, yy - 1], [xx + 1, yy + .8], [xx - 1, yy + .8]], acc == 'goggles' ? const Color(0xFF758180) : const Color(0x4DE2DABA));
    }
  }
  if (acc == 'mask') poly([[-2.5, -19], [2.5, -19], [2, -17], [-2, -17]], const Color(0xFFBACBC2));
  if (acc == 'headphones') {
    oval(-3, -20, 1.3, 2, const Color(0xFFA8A394));
    oval(3, -20, 1.3, 2, const Color(0xFFA8A394));
  }
  if (acc == 'pack' || acc == 'bag') line([[-3, -18], [2, -10]], const Color(0xFFB6A17D), 1);
  if (job != null) {
    g.save();
    g.translate(w + 1.3, handY);
    g.rotate(-.25 + work * .18);
    if (job == 'grow') {
      line([[0, 0], [2, 7]], const Color(0xFFA99572), 1.2);
      line([[-1, 7], [5, 7]], const Color(0xFF646D6B), 1.6);
    } else if (job == 'care' || job == 'read') {
      poly([[0, -2], [5, -1], [5, 5], [0, 4]], _cream);
      line([[1, 0], [4, .6]], const Color(0xFF747C76), .6);
    } else if (job == 'water') {
      line([[0, 0], [3, 0], [4, 3]], const Color(0xFFA7AEA3), .8);
      poly([[0, 2], [5, 2], [4, 7], [1, 7]], const Color(0xFF718A90));
    } else {
      line([[0, 0], [2, -5]], const Color(0xFFAC9270), 1.4);
      line([[0, -5], [4, -4]], const Color(0xFF9BA6A2), 2.1);
    }
    g.restore();
  }
  g.restore();
}
