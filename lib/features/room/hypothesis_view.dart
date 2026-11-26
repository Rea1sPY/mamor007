import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/util.dart';
import '../../network/client.dart';
import '../../widgets/ui.dart';

class HypothesisView extends StatefulWidget {
  const HypothesisView({super.key});

  @override
  State<HypothesisView> createState() => _HypothesisViewState();
}

class _HypothesisViewState extends State<HypothesisView> {
  final cl = GameClient.i;
  String? _su;
  String? _mo;
  final Set<String> _ev = {};
  final _why = TextEditingController();

  @override
  void dispose() {
    _why.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_su == null || _mo == null || _ev.isEmpty) {
      snack(context, 'متهم، انگیزه و حداقل یک مدرک را انتخاب کنید.');
      return;
    }
    final ok = await confirm(context, 'ثبت نظریه', 'پس از ثبت، امکان تغییر نظریه وجود ندارد.', yes: 'ثبت');
    if (!ok) return;
    cl.submitHypothesis(_su!, _mo!, _ev.toList(), _why.text);
  }

  @override
  Widget build(BuildContext context) {
    if (cl.submitted) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        const SecTitle('نظریه ثبت شد'),
        Panel(
          accent: C.green,
          child: Column(children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, t, child) => Transform.scale(scale: t, child: child),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: C.green.withAlpha(24),
                  border: Border.all(color: C.green.withAlpha(140)),
                  boxShadow: [BoxShadow(color: C.green.withAlpha(70), blurRadius: 24)],
                ),
                child: const Icon(Icons.task_alt, color: C.green, size: 44),
              ),
            ),
            const SizedBox(height: 10),
            Text('منتظر ثبت نظریه بقیه ${fa(cl.done)} / ${fa(cl.total)}', style: ts(14, color: C.muted)),
          ]),
        ),
        const SizedBox(height: 16),
        if (cl.isHost)
          AppBtn('انتقال به رأی‌گیری', icon: Icons.how_to_vote_outlined, kind: BtnKind.ghost, onTap: () async {
            if (cl.done < cl.total) {
              final ok = await confirm(context, 'انتقال به رأی‌گیری', 'همه نظریه‌ها ثبت نشده است. ادامه می‌دهید؟');
              if (!ok) return;
            }
            cl.hostAdvance();
          }),
      ]);
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SecTitle('ثبت نظریه نهایی'),
      Text('بر اساس مدارک و گفتگوها، حقیقت پرونده را مشخص کنید.', style: ts(13, color: C.muted, h: 1.7)),
      const SecTitle('متهم'),
      for (final s in cl.suspects)
        _Choice(
          title: '${s['name']}',
          sub: '${s['role']}',
          selected: _su == s['id'],
          onTap: () => setState(() => _su = '${s['id']}'),
        ),
      const SecTitle('انگیزه'),
      for (final m in cl.motives)
        _Choice(title: '${m['text']}', selected: _mo == m['id'], onTap: () => setState(() => _mo = '${m['id']}')),
      const SecTitle('مدارک کلیدی'),
      for (final e in cl.evidence)
        _EvCheck(
          title: '${e['title']}',
          type: '${e['type']}',
          shared: cl.sharedIds.contains(e['id']),
          selected: _ev.contains(e['id']),
          onTap: () => setState(() {
            final id = '${e['id']}';
            if (!_ev.add(id)) _ev.remove(id);
          }),
        ),
      const SecTitle('استدلال شما'),
      TextField(
        controller: _why,
        maxLines: 5,
        maxLength: 600,
        decoration: const InputDecoration(hintText: 'چرا این نتیجه را درست می‌دانید؟'),
      ),
      const SizedBox(height: 10),
      AppBtn('ثبت نظریه', icon: Icons.gavel, onTap: _submit),
    ]);
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.title, this.sub, required this.selected, required this.onTap});
  final String title;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Panel(
          accent: selected ? C.red : null,
          onTap: onTap,
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? C.red : Colors.transparent,
                border: Border.all(color: selected ? C.red : C.dim, width: 2),
                boxShadow: selected ? [BoxShadow(color: C.red.withAlpha(110), blurRadius: 10)] : null,
              ),
              child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            if (sub != null && title.isNotEmpty) ...[
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.panel2, C.bg2]),
                  border: Border.all(color: selected ? C.red : C.blue.withAlpha(110)),
                ),
                child: Text(title.substring(0, 1), style: ts(16, w: FontWeight.w900, color: selected ? C.red : C.blue)),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: ts(14, w: FontWeight.w700)),
                if (sub != null) Text(sub!, style: ts(11, color: C.muted)),
              ]),
            ),
          ]),
        ),
      );
}

class _EvCheck extends StatelessWidget {
  const _EvCheck({required this.title, required this.type, required this.shared, required this.selected, required this.onTap});
  final String title;
  final String type;
  final bool shared;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = type == 'photo' ? C.amber : (type == 'print' ? C.blue : (type == 'note' ? C.green : C.red));
    final icon = type == 'photo'
        ? Icons.photo_camera_outlined
        : (type == 'print' ? Icons.fingerprint : (type == 'note' ? Icons.sticky_note_2_outlined : Icons.description_outlined));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        accent: selected ? C.blue : null,
        onTap: onTap,
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: c.withAlpha(28),
              border: Border.all(color: c.withAlpha(120)),
            ),
            child: Icon(icon, color: c, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: ts(14, w: FontWeight.w600))),
          if (shared) const Padding(padding: EdgeInsets.only(left: 8), child: Tag('مشترک', color: C.green)),
          AnimatedScale(
            scale: selected ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.check_circle, color: C.blue, size: 22),
          ),
        ]),
      ),
    );
  }
}
