import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/feedback.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../widgets/hud.dart';

/// Private notebook for one case. Notes stay on this phone only and are never
/// sent over the network.
Future<void> showNotesSheet(BuildContext context, String caseKey, String title) {
  Fx.select();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      side: BorderSide(color: C.line2),
    ),
    builder: (_) => _NotesSheet(caseKey: caseKey, title: title),
  );
}

class _NotesSheet extends StatefulWidget {
  const _NotesSheet({required this.caseKey, required this.title});
  final String caseKey;
  final String title;

  @override
  State<_NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends State<_NotesSheet> {
  late final TextEditingController _c;
  Timer? _debounce;
  bool _saved = true;

  static const _starters = [
    ('مشکوک:', Icons.report_gmailerrorred_outlined),
    ('ناهماهنگی:', Icons.compare_arrows),
    ('سؤال:', Icons.help_outline),
    ('مدرک:', Icons.folder_open),
    ('ساعت:', Icons.schedule),
  ];

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: Store.i.noteFor(widget.caseKey));
  }

  void _changed(String _) {
    setState(() => _saved = false);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _flush);
  }

  Future<void> _flush() async {
    await Store.i.setNote(widget.caseKey, _c.text);
    if (mounted) setState(() => _saved = true);
  }

  void _insert(String prefix) {
    Fx.select();
    final t = _c.text;
    final needNl = t.isNotEmpty && !t.endsWith('\n');
    final next = '$t${needNl ? '\n' : ''}$prefix ';
    _c.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length));
    _changed(next);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Queue the final write so nothing typed in the last 500 ms is lost.
    Store.i.setNote(widget.caseKey, _c.text);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: C.line2, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.edit_note, color: C.amber),
              const SizedBox(width: 8),
              Expanded(child: Text('دفترچه یادداشت · ${widget.title}', style: ts(15, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(_saved ? 'ذخیره شد' : 'در حال ذخیره…', style: ts(10, color: _saved ? C.green : C.amber)),
            ]),
            const SizedBox(height: 4),
            Text('فقط روی همین گوشی می‌ماند و برای کسی ارسال نمی‌شود.', style: ts(11, color: C.muted)),
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _starters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _insert(_starters[i].$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: C.panel2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: C.line2),
                    ),
                    child: Row(children: [
                      Icon(_starters[i].$2, size: 14, color: C.blue),
                      const SizedBox(width: 5),
                      Text(_starters[i].$1, style: ts(12, color: C.muted)),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _c,
              onChanged: _changed,
              minLines: 6,
              maxLines: 10,
              maxLength: 2000,
              style: ts(14, h: 1.8),
              decoration: InputDecoration(
                hintText: 'مثلاً: ساعت ۹ شب کسی در راهرو دیده شد؛ حرف‌های او با سند شماره ۲ نمی‌خواند…',
                counterText: '${fa(_c.text.length)} / ${fa(2000)}',
              ),
            ),
            const SizedBox(height: 4),
            const HudDivider('PRIVATE NOTES'),
          ]),
        ),
      ),
    );
  }
}
