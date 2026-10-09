# Lomba Menari beat chart (dev-only)

The arrows in Lomba Menari land on the beat of its track, read from
`Resources/Minigames/Charts/SeniTari.tres` (a `DanceChart`). That chart is made
offline, never at play time. Spec: `docs/superpowers/specs/2026-10-09-seni-tari-beat-sync-design.md`, section 7.

1. **Detect.** On a machine with Python: `pip install librosa`, then
   `python tools/dance_chart/detect_beats.py Assets/Audio/BGM/minigame_senibudaya_menari.mp3`.
   It writes `tools/dance_chart/beats.json` (tempo, first-beat offset, beats),
   replacing the committed placeholder (the 100 bpm stand-in the game ships).
2. **Import.** Open `Scripts/Design/BuildDanceChart.gd` in the editor and
   File > Run (Ctrl+Shift+X). It writes `SeniTari.tres`, one arrow per beat,
   directions round-robin (left, top-left, top-right, right).
3. **Hand-tune.** Select `SeniTari.tres` in the FileSystem dock and edit
   `events` in the Inspector: thin the verse, thicken the chorus, set each
   arrow's `type` (0 left, 1 right, 2 top-left, 3 top-right). Keep `events`
   sorted by `beat`; `tests/test_lomba_menari_sync.gd` checks it.

Also set the track's import `bpm` and `bar_beats` (select the mp3, Import dock)
to the detected values, so Godot's own beat fields agree with the chart.

**Manual fallback** (no Python): set `bpm` and `first_beat_offset` by ear,
then author `events` directly. The game code is identical either way.

The chart assumes one constant tempo. If the track changes tempo, raise it with
the owner before charting (spec section 7, "Tempo-change caveat").
