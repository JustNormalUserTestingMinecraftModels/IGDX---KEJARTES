# APK size: 387 MB down to the 100–200 MB range

Date: 2026-10-02. Status: approved design, not yet built.

## Goal

The sideloaded APK (shared as a file: Drive, itch.io, IGDX judges) lands
between 100 and 200 MB, with **no change to what the player sees or hears,
and no loss of runtime performance**: same pixels, same GPU memory, same audio.

Out of scope: Google Play / `.aab`, lossy image re-encodes, audio re-encodes,
source-art resizes, a custom engine build.

## Where the 387 MB went

Measured from `Downloads/KejarTes-apk/KejarTes-2026-09-30-debug.apk`
(`unzip -lv`, stored sizes):

| Part | In APK | Cause |
|---|---|---|
| 132 VRAM-compressed `.ctex` (ASTC 4x4) | 246.6 MB | Godot's Android exporter stores every `.ctex` uncompressed (its no-compress extension list). ASTC of mostly transparent art deflates ~6x: the 15 largest went 56.7 → 9.1 MB. |
| 328 lossless `.ctex` | 16.8 MB | Already packed. |
| `libgodot_android.so`, two ABIs | 53.6 MB | That build carried `armeabi-v7a` (28.5) and `arm64-v8a` (25.1), debug template. |
| BGM / ambience (`mp3str`, `oggvorbisstr`, `sample`) | 60.6 MB | 256–320 kbps MP3. Left alone (see "Rejected"). |
| Fonts, scripts, scenes, other | ~9 MB | |

## Design

### 1. `tools/shrink_apk.ps1` + `tools/ShrinkApk.java`

Run after every Godot export:

```
Godot export ─► X.apk ─► shrink_apk.ps1 X.apk ─► X-small.apk
                          1. repack: deflate every *.ctex, copy the rest
                          2. zipalign -P 16 -f 4
                          3. apksigner sign (Godot's debug keystore)
                          4. verify, report sizes
```

- **Repack** is a single-file Java program run with `java ShrinkApk.java`
  (JDK 11+ runs a source file directly). Java because the JDK is already a
  hard requirement for Android export on any machine that builds the APK, and
  `java.util.zip` writes STORED and DEFLATED entries exactly as asked; .NET
  Framework's `ZipArchive` (PowerShell 5.1) cannot be trusted to write a true
  STORED entry, and `resources.arsc` must stay STORED.
  - Entries ending in `.ctex`: written DEFLATED, best compression.
  - Every other entry: written with its **original** method (STORED stays
    STORED, so `resources.arsc` and any uncompressed `.so` keep their
    requirements).
  - The old signature files (`META-INF/*.SF`, `*.RSA`, `*.EC`, `*.DSA`,
    `MANIFEST.MF`) are dropped; step 3 re-signs.
- **zipalign** `-P 16` page-aligns native libraries for 16 KB-page devices,
  `4` aligns the rest. Must run before signing (v2/v3 signatures cover the
  final bytes).
- **apksigner** signs with the keystore at the editor setting
  `export/android/debug_keystore` (alias `androiddebugkey`, password from
  `export/android/debug_keystore_pass`), read from
  `%APPDATA%\Godot\editor_settings-4.6.tres`. Same key as every build so far,
  so a new APK installs over an old one and the phone keeps its save.
- **Tools are found, not hard-coded:** `zipalign` / `apksigner` from the
  highest `build-tools` under `export/android/android_sdk_path`; `java` from
  `export/android/java_sdk_path`. Each can be overridden by a parameter.
  A missing tool stops the script with a message naming the setting.

**Self-checks before reporting success** (any failure deletes the output and
exits non-zero; the input APK is never written):

1. Same entry set as the input, minus the dropped signature files.
2. Every kept entry has the same CRC-32 and uncompressed size as in the input:
   the content is byte-identical, only its packing changed.
3. Every `.ctex` is DEFLATED; every non-`.ctex` kept its original method.
4. `zipalign -c -P 16 4` and `apksigner verify` pass.

Then it prints `before → after` in MB.

Output: `<input name>-small.apk` beside the input.

### 2. Two builds, both through the script

| Build | Export | Who | Debug overlay |
|---|---|---|---|
| Debug | "Export With Debug" on | the team | on |
| Release | "Export With Debug" off | judges, players | off (`DebugManager.gd:144`, `DapatkanUang.gd:50` check `OS.is_debug_build()`) |

`export_presets.cfg` is gitignored, so preset settings are per machine and
documented rather than committed:

- `architectures/arm64-v8a=true`, every other ABI false (already so on the PC).
- `keystore/release` = the debug keystore path, `keystore/release_user` =
  `androiddebugkey`, `keystore/release_password` = its password. Godot
  refuses a release export without these; reusing the debug key keeps one
  signature across both builds (sideload only; never for Play).

### 3. Docs

- `docs/superpowers/apk-build.md`: preset settings above, then the two
  export-and-shrink recipes, and the phone check below.
- `docs/superpowers/DEBT.md`: drop "No export preset exists on the dev PC" and
  "The download size was not measured" (texture-memory section, and "ETC2 is
  on but nothing is built for Android yet"); record the measured sizes.
- `docs/superpowers/CHANGELOG.md`: entry on landing.
- `CLAUDE.md`: one line pointing at `apk-build.md`, inside the budget.

## Expected size

Images ~45 MB + engine (arm64, release) ~20–25 MB + audio ~60 MB + other
~8 MB ≈ **135 MB**. The debug build runs a few MB larger. The real number is
measured on the first run and written into `apk-build.md`.

## Performance

- Same GPU memory: the textures are byte-identical ASTC, decoded the same way.
- Load cost: each zipped `.ctex` is inflated on read instead of read straight
  from the APK; inflating the largest (6.6 MB) takes milliseconds, on screens
  already behind the `Transition` wipe.
- Release template and arm64-only: equal or faster.

**The one open risk:** Godot reads APK assets through Android's
`AAssetManager`, which handles deflated assets, but a backward seek in a
deflated asset re-inflates from the start. If a texture load turns out to
seek backwards, loads slow down. The phone pass below is where this shows;
if it does, deflate only `.ctex` above a size threshold (the big art) rather
than all of them, and re-measure.

## Verification

- The script's self-checks (above) on every run.
- One phone pass on the first debug build: Lobby, Skin Select, a batik
  minigame, the end-of-grade exam art via Debug → Gladi Resik Akhir Kelas.
  Each should load as before. Then the release build: installs over the
  debug one, and the 5-tap overlay does not open.
- No GDScript changes, so the editor suite is unaffected.

## Rejected

- **Lossy/WebP images** (the usual Godot size tip): ~4x the GPU memory of
  ASTC, undoing the 2026-09-30 texture-memory pass.
- **Basis Universal:** re-encodes all 132 images (the student art already
  showed block artifacts once) and adds transcoding to each first load.
- **Gradle build template:** heavier, slower exports, and its asset
  compression for `.ctex` is unverified.
- **Audio re-encode:** generation loss on lossy sources and not needed to hit
  the range. Revisit with an A/B listening test if a smaller build is ever
  needed.
- **Removing the duplicate MP3** (`introcutscene.mp3` = `schoolsimulation.mp3`):
  deliberate placeholder per `Assets/Audio/README.md`, awaiting its own track.
