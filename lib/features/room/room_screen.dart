import 'package:flutter/material.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../network/client.dart';
import '../../network/protocol.dart';
import '../../widgets/hud.dart';
import '../../widgets/ui.dart';
import 'briefing_view.dart';
import 'hypothesis_view.dart';
import 'investigation_view.dart';
import 'lobby_view.dart';
import 'result_view.dart';
import 'voting_view.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final cl = GameClient.i;
  bool _ended = false;
  Phase? _lastPhase;

  @override
  void initState() {
    super.initState();
    _lastPhase = cl.phase;
    cl.addListener(_on);
  }

  @override
  void dispose() {
    cl.removeListener(_on);
    super.dispose();
  }

  void _on() {
    if (!mounted) return;
    if (!_ended && (cl.closedReason != null || cl.lost)) {
      _ended = true;
      _end(cl.closedReason ?? 'اتصال با میزبان از دست رفت و بازگشت ممکن نشد.');
      return;
    }
    final e = cl.lastError;
    if (e != null) {
      cl.lastError = null;
      snack(context, e);
    }
    if (_lastPhase != cl.phase) {
      if (cl.phase != Phase.result) Fx.phase();
      _lastPhase = cl.phase;
    }
    setState(() {});
  }

  Future<void> _end(String reason) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (d) => AlertDialog(
        backgroundColor: C.panel,
        title: Text('پایان نشست', style: ts(17, w: FontWeight.w700)),
        content: Text(reason, style: ts(14, color: C.muted, h: 1.7)),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('بازگشت به منو'))],
      ),
    );
    await cl.leave();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _leave() async {
    final ok = await confirm(
      context,
      'خروج از اتاق',
      cl.isHost ? 'با خروج شما، اتاق برای همه بسته می‌شود.' : 'از این اتاق خارج می‌شوید.',
      yes: 'خروج',
    );
    if (!ok) return;
    await cl.leave();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Widget _view() {
    switch (cl.phase) {
      case Phase.lobby:
        return LobbyView(onLeave: _leave);
      case Phase.briefing:
        return const BriefingView();
      case Phase.investigation:
        return const InvestigationView();
      case Phase.hypothesis:
        return const HypothesisView();
      case Phase.voting:
        return const VotingView();
      case Phase.result:
        return const ResultView();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: Stage(
          back: false,
          child: Column(children: [
            if (cl.reconnecting)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: C.amber.withAlpha(40),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: C.amber)),
                  const SizedBox(width: 10),
                  Text('اتصال قطع شد. در حال تلاش مجدد…', style: ts(12, color: C.amber)),
                ]),
              ),
            PhaseBar(
              index: const [Phase.lobby, Phase.briefing, Phase.investigation, Phase.hypothesis, Phase.voting, Phase.result]
                  .indexOf(cl.phase),
              labels: const ['لابی', 'معرفی پرونده', 'تحقیقات', 'نظریه‌پردازی', 'رأی‌گیری', 'نتیجه'],
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(scale: Tween<double>(begin: 0.97, end: 1).animate(a), child: child),
                ),
                child: KeyedSubtree(key: ValueKey(cl.phase), child: _view()),
              ),
            ),
          ]),
        ),
      );
}
