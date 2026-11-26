import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sfx.dart';
import 'store.dart';

/// Haptic and sound feedback. Everything here respects the two switches in
/// Settings and never throws (a missing vibrator or audio device is not an error).
class Fx {
  Fx._();

  static void _haptic(Future<void> Function() f) {
    try {
      if (Store.i.haptics) f();
    } catch (_) {}
  }

  /// Any button press.
  static void tap() {
    _haptic(HapticFeedback.selectionClick);
    Sfx.play(Cue.click);
  }

  /// Choosing an option (haptic only).
  static void select() => _haptic(HapticFeedback.selectionClick);

  /// Switching tabs.
  static void tab() {
    _haptic(HapticFeedback.selectionClick);
    Sfx.play(Cue.tab);
  }

  /// The room moved to the next phase.
  static void phase() {
    _haptic(HapticFeedback.lightImpact);
    Sfx.play(Cue.phase);
  }

  /// A teammate wrote in the chat.
  static void message() {
    _haptic(HapticFeedback.selectionClick);
    Sfx.play(Cue.message);
  }

  /// Evidence was shared with the team.
  static void share() {
    _haptic(HapticFeedback.lightImpact);
    Sfx.play(Cue.share);
  }

  /// A lab result arrived.
  static void lab() {
    _haptic(HapticFeedback.mediumImpact);
    Sfx.play(Cue.lab);
  }

  /// Case solved.
  static void success() {
    _haptic(HapticFeedback.mediumImpact);
    Sfx.play(Cue.win);
  }

  /// Case lost.
  static void fail() {
    _haptic(HapticFeedback.heavyImpact);
    Sfx.play(Cue.lose);
  }

  /// Something needs attention (a suspect asks for a lawyer).
  static void alert() {
    _haptic(HapticFeedback.vibrate);
    Sfx.play(Cue.alert);
  }
}

/// Runs [action] once, right after the first frame of [child].
class FxOnMount extends StatefulWidget {
  const FxOnMount({super.key, required this.action, required this.child});
  final VoidCallback action;
  final Widget child;

  @override
  State<FxOnMount> createState() => _FxOnMountState();
}

class _FxOnMountState extends State<FxOnMount> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.action();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
