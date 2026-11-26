# CASE 007 (پرونده ۰۰۷)

Offline local-network multiplayer detective game for 2 to 6 players. Flutter, Android first.

## Build

```
flutter create --org com.realspy --project-name case007 --platforms=android .
rm -f test/widget_test.dart
dart run tool/patch_android.dart
flutter pub get
dart run flutter_launcher_icons
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

Output: `build/app/outputs/flutter-apk/`. Without a release keystore the build is signed with the debug key and installs normally. For store-grade signing create `android/key.properties` and a keystore yourself and wire them in `android/app/build.gradle`; never commit them.

## Fonts and sounds

Vazirmatn v33 (SIL OFL 1.1, weights 400 to 900) is bundled in `assets/fonts/` and set in `lib/core/theme.dart`. Nine short interface sounds from Kenney's Interface Sounds pack (CC0) are in `assets/sounds/` and played by `lib/core/sfx.dart` (click, tab, message, share, lab, alert, phase, win, lose). Both licenses are in `assets/licenses/` and listed under About > Licenses. There are no timers anywhere in the game by design.

## Playing

1. Host: Create room (1 to 6 players), then share the code or QR. The host phone can run a hotspot, or all phones join one Wi-Fi.
2. Players: Join room and type only the 6-letter code. The host is found automatically (UDP broadcast, with an HTTP subnet probe as fallback). No IP is ever typed. QR scanning also works.
3. Host taps the detective bot for a brand new case (unlimited procedural cases from 15 scenarios: murder, theft, espionage; easy, standard, hard; the bot validates each case and rebuilds it if a check fails), picks type and difficulty by hand, or chooses one of the 5 hand-written cases. Everyone taps ready, host starts.
4. Investigate: share evidence, interrogate suspects and witnesses (they lie, slip, break or ask for a lawyer), take fingerprint samples, send prints to the team lab (limited requests), chat.
5. Submit hypotheses, vote, see the verdict.

## Rules of the game

- One shot. The team verdict (most votes) either names the real culprit (case solved) or it does not (case lost). A finished case is closed forever on that phone; there is no replay and no retry.
- No coins, XP or unlocks. Every case is open from the start. Rank is cosmetic and follows solved cases; eight cosmetic badges (first solve, win streak, and so on) show progress on the profile.
- Each player keeps a private notebook per case (pencil button on the investigation screen). It is stored on that phone only and never sent over the network.
- Haptic feedback and an optional click sound can be switched in Settings. An in-app guide (menu, or Settings) explains phases, tabs and detective tips.
- Interrogation is run by an offline rule-based engine on the host: each person has a voice, nerves, pride, a hidden secret or guilt, and a memory of what they already said. Honest people also look nervous sometimes, so tells are not proof.

## Online play

The game also works over the internet through a small relay (`relay/`, a free Cloudflare Worker). Deploy it as described in `relay/README.md`, set its address in `lib/core/relay_config.dart` (or per phone in Settings > Online server). The host turns on "Online room" when creating a room; players pick "Online" on the join screen and type only the code. The relay copies signed frames and never reads them. Local play is unchanged.

Support button opens Telegram chat with @MaTeoHastam. Creator: ReaLsPY.
