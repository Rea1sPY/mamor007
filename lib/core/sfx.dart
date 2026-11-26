import 'package:audioplayers/audioplayers.dart';

import 'store.dart';

enum Cue { click, tab, message, share, lab, alert, phase, win, lose }

/// Short interface sounds (Kenney, CC0). One low-latency player per cue so
/// quick repeats never cut each other off and no audio focus is taken from
/// the music the user may already be playing.
class Sfx {
  Sfx._();

  static final Map<Cue, AudioPlayer> _players = {};
  static final Map<Cue, DateTime> _last = {};

  static const _minGap = Duration(milliseconds: 60);

  static Future<void> play(Cue cue) async {
    try {
      if (!Store.i.sound) return;
      final now = DateTime.now();
      final prev = _last[cue];
      if (prev != null && now.difference(prev) < _minGap) return;
      _last[cue] = now;
      var p = _players[cue];
      if (p == null) {
        p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        _players[cue] = p;
      }
      await p.stop();
      await p.play(AssetSource('sounds/${cue.name}.ogg'), volume: 0.7);
    } catch (_) {
      // Sound is decoration. Never let it break the game.
    }
  }
}
