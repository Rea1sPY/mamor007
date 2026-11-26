# Case format

Add `assets/cases/case_XXX.json` and its id to `CaseLoader` in `lib/game/case_model.dart`.

Fields: id, title, category (theft, murder, espionage), difficulty (easy, standard, hard), minPlayers, maxPlayers, brief, roles[{name, desc}], suspects[{id, name, role, bio, responses{pressure, empathy, accuse}}], motives[{id, text}], evidence[{id, type: document|note|photo, title, content, public, scene, caption}], solution{culprit, motive, keyEvidence[], explanation}.

Public evidence goes to everyone; the rest is dealt round-robin so each piece has exactly one holder. Photos use `scene`: corridor, tower, desk, or room.

## Generated cases and simulation data

Generated cases (`gen_<seed>`) are built by `lib/game/generator.dart`. They add `witnesses`, evidence of type `print` (`print: {p: loop|whorl|arch, s: seed, q: clear|partial|smudged}`) and a hidden `sim` block: `actors` (voice, nerve, pride, guilt, alibi claim/drift/truth, secret, relation/money/saw lines, what each says about others, per-evidence reactions, confession lines), `fingers` (per person), `prints` (evidence id to owner) and `lab` (team request budget). The host never sends `sim` to clients. Hand-written cases may omit `sim.actors`; the engine then derives behaviour from `responses`. Add `sim.fingers` and `sim.prints` to enable the lab.

Hand-written cases shipped: case_001 (murder, standard), case_002 (espionage, hard), case_003 (theft, easy), case_004 (theft, standard), case_005 (murder, hard). Every one has fingerprint evidence and a `sim` block with `fingers`, `prints` and `lab`.
