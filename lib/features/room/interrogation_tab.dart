import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/util.dart';
import '../../game/voice.dart';
import '../../network/client.dart';
import '../../widgets/effects.dart';
import '../../widgets/hud.dart';
import '../../widgets/ui.dart';

class InterrogationTab extends StatefulWidget {
  const InterrogationTab({super.key});

  @override
  State<InterrogationTab> createState() => _InterrogationTabState();
}

class _InterrogationTabState extends State<InterrogationTab> {
  final cl = GameClient.i;
  final _rnd = Random();
  final _scroll = ScrollController();
  String? _sid;
  String _tone = 'neutral';

  static const _stageNames = ['آرام', 'معذب', 'مضطرب', 'در آستانه فروپاشی'];
  static const _stageColors = [C.green, C.amber, C.red, C.red];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<J> get _people => [...cl.suspects, ...cl.witnesses];

  bool _isWitness(String id) => cl.witnesses.any((w) => w['id'] == id);

  String _line(String topic, {String x = ''}) {
    final byTone = askLines[topic];
    final list = byTone?[_tone] ?? byTone?['neutral'] ?? const ['...'];
    return list[_rnd.nextInt(list.length)].replaceAll('{x}', x);
  }

  void _ask(String topic, {String arg = '', String extra = ''}) {
    final sid = _sid;
    if (sid == null || cl.waiting.contains(sid)) return;
    final x = arg.isEmpty ? '' : cl.suspectName(arg);
    cl.ask(sid, topic, _tone, arg, '${_line(topic, x: x)}$extra');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _pickOther() async {
    final me = _sid;
    final list = cl.suspects.where((s) => s['id'] != me).toList();
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: C.bg2,
      builder: (sheet) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
          const SecTitle('دربارهٔ چه کسی بپرسید؟'),
          for (final s in list)
            ListTile(
              title: Text('${s['name']}', style: ts(14, w: FontWeight.w700)),
              subtitle: Text('${s['role']}', style: ts(11, color: C.muted)),
              onTap: () => Navigator.pop(sheet, '${s['id']}'),
            ),
        ]),
      ),
    );
    if (pick != null) _ask('others', arg: pick);
  }

  Future<void> _pickEvidence() async {
    final list = cl.evidence;
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: C.bg2,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
          const SecTitle('کدام مدرک را نشان می‌دهید؟'),
          if (list.isEmpty) Text('مدرکی در اختیار ندارید.', style: ts(13, color: C.muted)),
          for (final e in list)
            ListTile(
              leading: Icon(e['type'] == 'photo'
                  ? Icons.photo_camera_outlined
                  : (e['type'] == 'print' ? Icons.fingerprint : Icons.description_outlined), color: C.blue),
              title: Text('${e['title']}', style: ts(14, w: FontWeight.w700)),
              onTap: () => Navigator.pop(sheet, '${e['id']}'),
            ),
        ]),
      ),
    );
    if (pick == null) return;
    final ev = cl.evById(pick);
    _ask('evidence', arg: pick, extra: ' «${ev?['title'] ?? ''}»');
  }

  Widget _flag(String f) {
    final hard = cl.caseDiff == 'hard';
    switch (f) {
      case 'drift':
        return hard ? const SizedBox.shrink() : const Tag('تناقض با اظهار قبلی', color: C.amber, icon: Icons.compare_arrows);
      case 'secret':
        return const Tag('رازی فاش شد', color: C.blue, icon: Icons.key);
      case 'break':
        return const Tag('اعتراف جزئی', color: C.red, icon: Icons.warning_amber);
      case 'confess':
        return const Tag('اعتراف', color: C.red, icon: Icons.gavel);
      case 'lawyer':
        return const Tag('درخواست وکیل', color: C.red, icon: Icons.balance);
      case 'sample':
        return const Tag('نمونه گرفته شد', color: C.green, icon: Icons.fingerprint);
      case 'refuse':
        return const Tag('امتناع', color: C.amber, icon: Icons.block);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = _people;
    if (people.isEmpty) return const SizedBox.shrink();
    _sid ??= '${people.first['id']}';
    final p = people.firstWhere((x) => x['id'] == _sid, orElse: () => people.first);
    final sid = '${p['id']}';
    final witness = _isWitness(sid);
    final log = cl.interro[sid] ?? [];
    final waiting = cl.waiting.contains(sid);
    var stage = 0;
    var lawyered = false;
    for (final m in log) {
      if (m['who'] == 'sus') {
        stage = (m['stage'] as num?)?.toInt() ?? stage;
        if (m['lawyer'] == true) lawyered = true;
      }
    }
    final sampled = cl.samples.contains(sid);
    return Column(children: [
      SizedBox(
        height: 52,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), children: [
          for (final x in people)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                avatar: _isWitness('${x['id']}') ? const Icon(Icons.visibility_outlined, size: 16) : null,
                label: Text('${x['name']}'),
                selected: sid == x['id'],
                onSelected: (_) => setState(() {
                  _sid = '${x['id']}';
                  cl.freshAnswer = null;
                }),
                selectedColor: C.red.withAlpha(50),
                backgroundColor: C.panel2,
                side: BorderSide(color: sid == x['id'] ? C.red : C.line2),
              ),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Panel(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p['name']} · ${p['role']}', style: ts(14, w: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${p['bio']}', style: ts(12, color: C.muted, h: 1.7)),
            const SizedBox(height: 8),
            if (!witness && cl.caseDiff != 'hard' && log.isNotEmpty) ...[
              EcgMonitor(stage: stage.clamp(0, 3)),
              const SizedBox(height: 8),
            ],
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (witness) const Tag('شاهد', color: C.blue, icon: Icons.visibility_outlined),
              if (!witness && cl.caseDiff != 'hard' && log.isNotEmpty)
                Tag(_stageNames[stage.clamp(0, 3)], color: _stageColors[stage.clamp(0, 3)], icon: Icons.monitor_heart_outlined),
              if (lawyered) const Tag('وکیل خواسته', color: C.red, icon: Icons.balance),
              if (!witness && (cl.labLeft > 0 || sampled))
                sampled
                    ? const Tag('نمونه اثر انگشت دارد', color: C.green, icon: Icons.fingerprint)
                    : InkWell(
                        onTap: waiting ? null : () => cl.takeSample(sid),
                        child: const Tag('گرفتن اثر انگشت', color: C.amber, icon: Icons.fingerprint),
                      ),
            ]),
          ]),
        ),
      ),
      Expanded(
        child: log.isEmpty
            ? Center(child: Text('بازجویی را آغاز کنید. لحن و موضوع را با دقت انتخاب کنید.', style: ts(13, color: C.muted)))
            : ListView(controller: _scroll, padding: const EdgeInsets.all(16), children: [
                for (var i = 0; i < log.length; i++) _bubble(log[i], p, i == log.length - 1 && cl.freshAnswer == sid),
                if (waiting)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [const TypingDots(), const SizedBox(width: 8), Text('در حال پاسخ‌دادن…', style: ts(12, color: C.dim))]),
                  ),
              ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'neutral', label: Text('عادی')),
            ButtonSegment(value: 'empathy', label: Text('همدلی')),
            ButtonSegment(value: 'pressure', label: Text('فشار')),
            ButtonSegment(value: 'accuse', label: Text('اتهام')),
          ],
          selected: {_tone},
          onSelectionChanged: (v) => setState(() => _tone = v.first),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          if (!witness) _topic('کجا بودی؟', Icons.place_outlined, waiting || lawyered, () => _ask('alibi')),
          if (!witness) _topic('رابطه با قربانی', Icons.people_outline, waiting || lawyered, () => _ask('rel')),
          if (!witness) _topic('پول و فشار', Icons.payments_outlined, waiting || lawyered, () => _ask('money')),
          _topic('چه دیدی؟', Icons.visibility_outlined, waiting || lawyered, () => _ask('saw')),
          _topic('درباره دیگران', Icons.groups_outlined, waiting || lawyered, _pickOther),
          if (!witness) _topic('نشان‌دادن مدرک', Icons.folder_open, waiting || lawyered, _pickEvidence),
        ]),
      ),
    ]);
  }

  Widget _topic(String label, IconData icon, bool off, VoidCallback f) => ActionChip(
        avatar: Icon(icon, size: 16, color: off ? C.dim : C.blue),
        label: Text(label, style: ts(12, color: off ? C.dim : C.text)),
        backgroundColor: C.panel2,
        side: BorderSide(color: off ? C.line : C.line2),
        onPressed: off ? null : f,
      );

  Widget _bubble(J m, J person, bool typeIt) {
    final me = m['who'] == 'me';
    final st = ts(13, h: 1.7);
    final obs = ((m['obs'] as List?) ?? const []).map((e) => '$e').toList();
    final flag = '${m['flag'] ?? ''}';
    return Align(
      alignment: me ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: GestureDetector(
        onLongPress: me
            ? null
            : () {
                cl.sendChat('📝 اظهارات ${person['name']}: «${m['text']}»');
                snack(context, 'اظهارات در گفتگوی تیم ثبت شد.');
              },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: bubbleDeco(me),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            typeIt && !me ? TypewriterText('${m['text']}', style: st) : Text('${m['text']}', style: st),
            if (!me && obs.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final o in obs) Text('ملاحظه: $o', style: ts(11, color: C.amber, h: 1.6)),
            ],
            if (!me && flag.isNotEmpty && flag != 'dup') ...[
              const SizedBox(height: 6),
              _flag(flag),
            ],
          ]),
        ),
      ),
    );
  }
}
