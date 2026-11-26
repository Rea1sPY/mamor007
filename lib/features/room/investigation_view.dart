import 'dart:math';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../network/client.dart';
import '../../widgets/effects.dart';
import '../../widgets/evidence_art.dart';
import '../../widgets/hud.dart';
import '../../widgets/ui.dart';
import 'evidence_viewers.dart';
import 'interrogation_tab.dart';
import 'lab_tab.dart';
import 'notes_sheet.dart';

class InvestigationView extends StatefulWidget {
  const InvestigationView({super.key});

  @override
  State<InvestigationView> createState() => _InvestigationViewState();
}

class _InvestigationViewState extends State<InvestigationView> {
  final cl = GameClient.i;
  int _tab = 0;

  static const _tabs = [
    (Icons.dashboard_customize_outlined, 'میز تحقیقات'),
    (Icons.description_outlined, 'اسناد'),
    (Icons.photo_library_outlined, 'تصاویر'),
    (Icons.record_voice_over_outlined, 'بازجویی'),
    (Icons.fingerprint, 'آزمایشگاه'),
    (Icons.forum_outlined, 'گفتگو'),
  ];

  Widget _body() {
    switch (_tab) {
      case 0:
        return const BoardTab();
      case 1:
        return const DocsTab();
      case 2:
        return const GalleryTab();
      case 3:
        return const InterrogationTab();
      case 4:
        return const LabTab();
      default:
        return const ChatTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tab == 5) cl.chatSeen = cl.chat.length;
    final unread = _tab != 5 && cl.chat.length > cl.chatSeen;
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cl.caseTitle, style: ts(16, w: FontWeight.w800)),
              Text('مرحله بررسی · مدارک را بررسی و با دیگران تبادل کنید', style: ts(10, color: C.muted)),
            ]),
          ),
          HudIconBtn(
            tooltip: 'دفترچه یادداشت',
            icon: Icons.edit_note,
            onTap: () => showNotesSheet(context, cl.caseId, cl.caseTitle),
          ),
          const SizedBox(width: 8),
          if (cl.isHost)
            AppBtn('ثبت نظریه', expand: false, height: 38, icon: Icons.gavel, onTap: () async {
              final ok = await confirm(context, 'پایان بررسی', 'همه بازیکنان به مرحله ثبت نظریه می‌روند. ادامه می‌دهید؟');
              if (ok) cl.hostAdvance();
            }),
        ]),
      ),
      Expanded(child: _body()),
      Container(
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.panel, C.bg2]),
          border: const Border(top: BorderSide(color: C.line)),
          boxShadow: [BoxShadow(color: C.blue.withAlpha(14), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: Row(children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_tab != i) Fx.tab();
                  setState(() => _tab = i);
                },
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    height: 3,
                    width: _tab == i ? 28 : 0,
                    margin: const EdgeInsets.only(bottom: 5),
                    decoration: BoxDecoration(
                      color: C.blue,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: _tab == i ? [BoxShadow(color: C.blue.withAlpha(160), blurRadius: 8)] : null,
                    ),
                  ),
                  Stack(clipBehavior: Clip.none, children: [
                    Icon(
                      _tabs[i].$1,
                      size: 22,
                      color: _tab == i ? C.blue : C.dim,
                      shadows: _tab == i ? [Shadow(color: C.blue.withAlpha(170), blurRadius: 12)] : null,
                    ),
                    if (i == 5 && unread)
                      Positioned(top: -2, right: -4, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: C.red, shape: BoxShape.circle))),
                  ]),
                  const SizedBox(height: 3),
                  Text(_tabs[i].$2, style: ts(10, color: _tab == i ? C.blue : C.dim, w: FontWeight.w600)),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }
}

Color _typeColor(String t) =>
    t == 'photo' ? C.amber : (t == 'print' ? C.blue : (t == 'note' ? C.green : C.red));

IconData _icon(String t) => t == 'photo'
    ? Icons.photo_camera_outlined
    : t == 'note'
        ? Icons.sticky_note_2_outlined
        : t == 'print'
            ? Icons.fingerprint
            : Icons.description_outlined;

class BoardTab extends StatefulWidget {
  const BoardTab({super.key});

  @override
  State<BoardTab> createState() => _BoardTabState();
}

class _BoardTabState extends State<BoardTab> {
  final cl = GameClient.i;
  bool _link = false;
  String? _from;
  static const cw = 150.0;
  static const ch = 92.0;

  void _layout() {
    var n = 0;
    for (final e in cl.evidence) {
      final id = '${e['id']}';
      if (!cl.pos.containsKey(id)) {
        final k = cl.pos.length;
        cl.pos[id] = Offset(14.0 + (k % 2) * 170, 14.0 + (k ~/ 2) * 112);
      }
      n++;
    }
    if (n == 0) return;
  }

  String _key(String a, String b) => a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

  void _tapCard(String id) {
    if (!_link) {
      openEvidence(context, id);
      return;
    }
    if (_from == null) {
      setState(() => _from = id);
    } else if (_from == id) {
      setState(() => _from = null);
    } else {
      final k = _key(_from!, id);
      setState(() {
        if (!cl.links.remove(k)) cl.links.add(k);
        _from = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _layout();
    if (cl.evidence.isEmpty) {
      return Center(child: Text('مدرکی در اختیار شما نیست.', style: ts(13, color: C.muted)));
    }
    final s = cl.boardScale;
    final o = cl.boardOff;
    return ClipRect(
      child: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanUpdate: (d) => setState(() => cl.boardOff += d.delta),
            child: const SizedBox.expand(),
          ),
        ),
        Transform(
          transform: Matrix4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, o.dx, o.dy, 0, 1),
          child: SizedBox(
            width: 1400,
            height: 1800,
            child: Stack(children: [
              IgnorePointer(child: CustomPaint(size: const Size(1400, 1800), painter: _DotGrid())),
              IgnorePointer(child: CustomPaint(size: const Size(1400, 1800), painter: _LinkPainter(cl.links, cl.pos))),
              for (final e in cl.evidence) _card(e),
            ]),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: Column(children: [
            _tool(Icons.link, _link, () => setState(() {
                  _link = !_link;
                  _from = null;
                })),
            _tool(Icons.add, false, () => setState(() => cl.boardScale = min(1.6, cl.boardScale + 0.15))),
            _tool(Icons.remove, false, () => setState(() => cl.boardScale = max(0.4, cl.boardScale - 0.15))),
            _tool(Icons.grid_view, false, () => setState(() {
                  cl.pos.clear();
                  cl.boardOff = Offset.zero;
                  cl.boardScale = 0.9;
                })),
          ]),
        ),
        if (_link)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Tag(_from == null ? 'حالت اتصال: مدرک اول را انتخاب کنید' : 'مدرک دوم را انتخاب کنید', color: C.red, icon: Icons.link),
            ),
          ),
      ]),
    );
  }

  Widget _tool(IconData i, bool on, VoidCallback f) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: f,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: on ? const [C.red, C.redDeep] : const [C.panel2, C.panel],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? C.red : C.line2),
              boxShadow: on ? [BoxShadow(color: C.red.withAlpha(110), blurRadius: 14)] : null,
            ),
            child: Icon(i, color: on ? Colors.white : C.text, size: 22),
          ),
        ),
      );

  Widget _card(J e) {
    final id = '${e['id']}';
    final p = cl.pos[id]!;
    final shared = cl.sharedIds.contains(id);
    final sel = _from == id;
    final tc = _typeColor('${e['type']}');
    return Positioned(
      left: p.dx,
      top: p.dy,
      width: cw,
      height: ch,
      child: GestureDetector(
        onTap: () => _tapCard(id),
        onPanUpdate: (d) => setState(() => cl.pos[id] = p + d.delta / cl.boardScale),
        child: Transform.rotate(
          angle: ((seedOf(id) % 7) - 3) * 0.008,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 18, 10, 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.panel2, C.panel]),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? C.red : tc.withAlpha(110), width: sel ? 2 : 1),
                  boxShadow: [
                    const BoxShadow(color: Color(0x99000000), blurRadius: 10, offset: Offset(0, 5)),
                    if (sel) BoxShadow(color: C.red.withAlpha(90), blurRadius: 16),
                  ],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(_icon('${e['type']}'), size: 16, color: tc),
                    const Spacer(),
                    if (shared) const Icon(Icons.groups, size: 14, color: C.green),
                  ]),
                  const SizedBox(height: 6),
                  Expanded(child: Text('${e['title']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: ts(12, w: FontWeight.w700, h: 1.4))),
                ]),
              ),
            ),
            Positioned(
              top: 5,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: C.red,
                    boxShadow: [BoxShadow(color: Color(0x99000000), blurRadius: 3, offset: Offset(1, 2))],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DotGrid extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final pts = <Offset>[];
    for (double x = 14; x < s.width; x += 28) {
      for (double y = 14; y < s.height; y += 28) {
        pts.add(Offset(x, y));
      }
    }
    canvas.drawPoints(
      PointMode.points,
      pts,
      Paint()
        ..color = C.line2.withAlpha(150)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _DotGrid old) => false;
}

class _LinkPainter extends CustomPainter {
  _LinkPainter(this.links, this.pos);
  final Set<String> links;
  final Map<String, Offset> pos;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = C.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final glow = Paint()
      ..color = C.red.withAlpha(70)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final shade = Paint()
      ..color = const Color(0x77000000)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final pin = Paint()..color = C.red;
    for (final k in links) {
      final ids = k.split('|');
      final a = pos[ids[0]];
      final b = pos[ids[1]];
      if (a == null || b == null) continue;
      final pa = a + const Offset(_BoardTabState.cw / 2, 10);
      final pb = b + const Offset(_BoardTabState.cw / 2, 10);
      final mid = Offset((pa.dx + pb.dx) / 2, (pa.dy + pb.dy) / 2 + 34);
      final path = Path()..moveTo(pa.dx, pa.dy)..quadraticBezierTo(mid.dx, mid.dy, pb.dx, pb.dy);
      canvas.drawPath(path.shift(const Offset(2, 5)), shade);
      canvas.drawPath(path, glow);
      canvas.drawPath(path, line);
      canvas.drawCircle(pa, 6, pin);
      canvas.drawCircle(pb, 6, pin);
      canvas.drawCircle(pa + const Offset(-1.5, -1.5), 1.8, Paint()..color = Colors.white.withAlpha(180));
      canvas.drawCircle(pb + const Offset(-1.5, -1.5), 1.8, Paint()..color = Colors.white.withAlpha(180));
    }
  }

  @override
  bool shouldRepaint(covariant _LinkPainter old) => true;
}

class DocsTab extends StatefulWidget {
  const DocsTab({super.key});

  @override
  State<DocsTab> createState() => _DocsTabState();
}

class _DocsTabState extends State<DocsTab> {
  final cl = GameClient.i;
  String _q = '';
  String _f = 'all';

  @override
  Widget build(BuildContext context) {
    final list = cl.evidence.where((e) {
      if (_f == 'shared' && !cl.sharedIds.contains(e['id'])) return false;
      if (_f != 'all' && _f != 'shared' && e['type'] != _f) return false;
      if (_q.isEmpty) return true;
      return '${e['title']} ${e['content']}'.contains(_q);
    }).toList();
    const filters = {'all': 'همه', 'document': 'اسناد', 'note': 'یادداشت‌ها', 'photo': 'تصاویر', 'print': 'اثر انگشت', 'shared': 'مشترک'};
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: TextField(
          onChanged: (v) => setState(() => _q = v.trim()),
          decoration: const InputDecoration(hintText: 'جستجو در مدارک', prefixIcon: Icon(Icons.search, color: C.muted)),
        ),
      ),
      SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          for (final f in filters.entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: ChoiceChip(
                label: Text(f.value),
                selected: _f == f.key,
                onSelected: (_) => setState(() => _f = f.key),
                selectedColor: C.blue.withAlpha(50),
                backgroundColor: C.panel2,
                side: BorderSide(color: _f == f.key ? C.blue : C.line2),
              ),
            ),
        ]),
      ),
      Expanded(
        child: list.isEmpty
            ? Center(child: Text('مدرکی پیدا نشد.', style: ts(13, color: C.muted)))
            : ListView(padding: const EdgeInsets.all(16), children: [
                for (final e in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Panel(
                      onTap: () => openEvidence(context, '${e['id']}'),
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: _typeColor('${e['type']}').withAlpha(28),
                            border: Border.all(color: _typeColor('${e['type']}').withAlpha(130)),
                            boxShadow: [BoxShadow(color: _typeColor('${e['type']}').withAlpha(40), blurRadius: 10)],
                          ),
                          child: Icon(_icon('${e['type']}'), color: _typeColor('${e['type']}'), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${e['title']}', style: ts(14, w: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text('${e['content']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, color: C.muted)),
                          ]),
                        ),
                        if (cl.sharedIds.contains(e['id'])) const Icon(Icons.groups, color: C.green, size: 18),
                      ]),
                    ),
                  ),
              ]),
      ),
    ]);
  }
}

class GalleryTab extends StatelessWidget {
  const GalleryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final photos = GameClient.i.evidence.where((e) => e['type'] == 'photo').toList();
    if (photos.isEmpty) {
      return Center(child: Text('تصویری در اختیار شما نیست.', style: ts(13, color: C.muted)));
    }
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: [
        for (final e in photos)
          GestureDetector(
            onTap: () => openEvidence(context, '${e['id']}'),
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE9E3D1),
                borderRadius: BorderRadius.circular(5),
                boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 12, offset: Offset(0, 5))],
              ),
              child: Column(children: [
                Expanded(child: EvidenceArt(scene: '${e['scene']}', caption: '${e['caption']}', radius: 2)),
                const SizedBox(height: 6),
                Text('${e['title']}',
                    style: ts(12, color: const Color(0xFF1B1B22), w: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ),
      ],
    );
  }
}

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final cl = GameClient.i;
  final _ctl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final t = _ctl.text.trim();
    if (t.isEmpty) return;
    cl.sendChat(t);
    _ctl.clear();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
    return Column(children: [
      Expanded(
        child: cl.chat.isEmpty
            ? Center(child: Text('هنوز پیامی ارسال نشده است.', style: ts(13, color: C.muted)))
            : ListView(controller: _scroll, padding: const EdgeInsets.all(16), children: [
                for (final m in cl.chat)
                  if (m.system)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Center(child: Tag(m.text, color: C.green, icon: Icons.share_outlined)),
                    )
                  else
                    _msg(m),
              ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctl,
              maxLength: 400,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(hintText: 'پیام…', counterText: ''),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'ارسال',
            style: IconButton.styleFrom(backgroundColor: C.red, minimumSize: const Size(48, 48)),
            onPressed: _send,
            icon: const Icon(Icons.send),
          ),
        ]),
      ),
    ]);
  }

  Widget _msg(ChatLine m) {
    final mine = m.pid == cl.myPid;
    return Align(
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 290),
        decoration: bubbleDeco(mine),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!mine) Text(m.name, style: ts(11, color: C.blue, w: FontWeight.w700)),
          Text(m.text, style: ts(13, h: 1.6)),
        ]),
      ),
    );
  }
}

