import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/util.dart';
import '../../network/client.dart';
import '../../widgets/evidence_art.dart';
import '../../widgets/fingerprint_art.dart';
import '../../widgets/ui.dart';

void openEvidence(BuildContext context, String id) {
  final e = GameClient.i.evById(id);
  if (e == null) return;
  Navigator.of(context).push(
    openRoute<void>(e['type'] == 'photo'
        ? PhotoViewer(id: id)
        : (e['type'] == 'print' ? PrintViewer(id: id) : DocViewer(id: id))),
  );
}

Widget _shareBar(BuildContext context, String id) {
  final cl = GameClient.i;
  if (cl.sharedIds.contains(id)) {
    return const Panel(child: Row(children: [Icon(Icons.groups, color: C.green, size: 18), SizedBox(width: 8), Text('این مدرک با همه به اشتراک گذاشته شده است.')]));
  }
  if (!cl.mineIds.contains(id)) return const SizedBox.shrink();
  return AppBtn('اشتراک‌گذاری با همه', icon: Icons.share_outlined, kind: BtnKind.ghost, onTap: () async {
    final ok = await confirm(context, 'اشتراک‌گذاری', 'محتوای این مدرک برای همه بازیکنان نمایش داده می‌شود.', yes: 'اشتراک');
    if (!ok) return;
    cl.share(id);
    if (context.mounted) snack(context, 'مدرک به اشتراک گذاشته شد.');
  });
}

class DocViewer extends StatelessWidget {
  const DocViewer({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final cl = GameClient.i;
    return ListenableBuilder(
      listenable: cl,
      builder: (context, _) {
        final e = cl.evById(id);
        if (e == null) return const SizedBox.shrink();
        return Stage(
          title: 'مدرک',
          child: ListView(padding: const EdgeInsets.all(16), children: [
            PaperDoc(title: '${e['title']}', content: '${e['content']}', note: e['type'] == 'note'),
            const SizedBox(height: 18),
            _shareBar(context, id),
          ]),
        );
      },
    );
  }
}

class PrintViewer extends StatelessWidget {
  const PrintViewer({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final cl = GameClient.i;
    return ListenableBuilder(
      listenable: cl,
      builder: (context, _) {
        final e = cl.evById(id);
        if (e == null) return const SizedBox.shrink();
        final pr = e['print'] is Map ? Map<String, dynamic>.from(e['print'] as Map) : <String, dynamic>{};
        return Stage(
          title: 'اثر انگشت',
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Center(
              child: FingerprintArt(
                pattern: '${pr['p'] ?? 'loop'}',
                seed: (pr['s'] as num?)?.toInt() ?? 1,
                quality: '${pr['q'] ?? 'clear'}',
                size: 220,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
              Tag(
                const {'loop': 'الگوی حلقوی', 'whorl': 'الگوی مارپیچ', 'arch': 'الگوی قوسی'}['${pr['p'] ?? 'loop'}'] ?? 'الگو نامشخص',
                color: C.blue,
                icon: Icons.fingerprint,
              ),
              Tag(
                const {'clear': 'کیفیت: واضح', 'partial': 'کیفیت: ناقص', 'smudged': 'کیفیت: لکه‌دار'}['${pr['q'] ?? 'clear'}'] ?? 'کیفیت نامشخص',
                color: '${pr['q'] ?? 'clear'}' == 'clear' ? C.green : C.amber,
                icon: Icons.high_quality_outlined,
              ),
            ]),
            const SizedBox(height: 14),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${e['title']}', style: ts(15, w: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('${e['content']}', style: ts(13, color: C.muted, h: 1.8)),
                const SizedBox(height: 6),
                Text('برای مقایسه، از تب «آزمایشگاه» استفاده کنید.', style: ts(11, color: C.dim)),
              ]),
            ),
            const SizedBox(height: 18),
            _shareBar(context, id),
          ]),
        );
      },
    );
  }
}

class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.id});
  final String id;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  final _tc = TransformationController();
  Offset _tap = Offset.zero;
  bool _zoomed = false;
  final cl = GameClient.i;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _toggle() {
    const s = 2.5;
    setState(() => _zoomed = !_zoomed);
    _tc.value = _zoomed
        ? Matrix4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, -_tap.dx * (s - 1), -_tap.dy * (s - 1), 0, 1)
        : Matrix4.identity();
  }

  Future<void> _addNote(Offset p, double w, double bh, double oy) async {
    final nx = p.dx / w;
    final ny = (p.dy - oy) / bh;
    if (nx < 0 || nx > 1 || ny < 0 || ny > 1) return;
    final ctl = TextEditingController();
    final t = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: C.panel,
        title: Text('یادداشت روی تصویر', style: ts(16, w: FontWeight.w700)),
        content: TextField(controller: ctl, maxLength: 80, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(d, ctl.text.trim()), child: const Text('ثبت')),
        ],
      ),
    );
    ctl.dispose();
    if (t == null || t.isEmpty) return;
    setState(() => cl.notes.putIfAbsent(widget.id, () => []).add({'x': nx, 'y': ny, 't': t}));
  }

  @override
  Widget build(BuildContext context) {
    final e = cl.evById(widget.id);
    if (e == null) return const SizedBox.shrink();
    final notes = cl.notes[widget.id] ?? [];
    return Stage(
      title: '${e['title']}',
      child: Column(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 4),
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9E3D1),
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 20, offset: Offset(0, 8))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LayoutBuilder(builder: (context, cons) {
              final w = cons.maxWidth;
              final h = cons.maxHeight;
              final bh = min(h, w * 0.75);
              final oy = (h - bh) / 2;
              return InteractiveViewer(
                transformationController: _tc,
                minScale: 1,
                maxScale: 5,
                child: GestureDetector(
                  onDoubleTapDown: (d) => _tap = d.localPosition,
                  onDoubleTap: _toggle,
                  onLongPressStart: (d) => _addNote(d.localPosition, w, bh, oy),
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: Stack(children: [
                      Positioned(
                        left: 0,
                        top: oy,
                        width: w,
                        height: bh,
                        child: EvidenceArt(scene: '${e['scene']}', caption: '${e['caption']}', radius: 0),
                      ),
                      for (final n in notes)
                        Positioned(
                          left: (n['x'] as double) * w - 12,
                          top: oy + (n['y'] as double) * bh - 12,
                          child: Tooltip(
                            message: '${n['t']}',
                            triggerMode: TooltipTriggerMode.tap,
                            child: const Icon(Icons.location_on, color: C.red, size: 24),
                          ),
                        ),
                    ]),
                  ),
                ),
              );
            }),
                  ),
                ),
              ),
              Positioned(
                top: -10,
                left: 0,
                right: 0,
                child: Center(
                  child: Transform.rotate(
                    angle: -0.03,
                    child: Container(width: 84, height: 20, color: const Color(0xAAF1E2A0)),
                  ),
                ),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text('${e['content']}', style: ts(13, color: C.muted, h: 1.8)),
            const SizedBox(height: 6),
            Text('دوبار لمس: بزرگ‌نمایی · لمس طولانی: افزودن یادداشت', style: ts(10, color: C.dim)),
            const SizedBox(height: 12),
            _shareBar(context, widget.id),
          ]),
        ),
      ]),
    );
  }
}

List<J> allEvidence() => GameClient.i.evidence;
