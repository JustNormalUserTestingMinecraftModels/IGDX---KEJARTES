# Building the APK

The APK is shared as a file (sideloaded), not through Google Play. Every
build goes through `tools/shrink_apk.ps1` after export: Godot stores the
textures uncompressed, and the script zips them, cutting the APK from about
387 MB to about 182 MB (measured on the 2026-09-30 debug build) with
byte-identical contents. Design and numbers:
`specs/2026-10-02-apk-size-design.md`.

## Two builds

| Build | "Export With Debug" | For | Debug overlay (5 taps / F1) |
|---|---|---|---|
| Debug | on | the team | on |
| Release | off | judges, players | off (`OS.is_debug_build()` is false) |

Both are signed with the same key, so either installs over the other and
the phone keeps its save. Never put a release build on Google Play signed
this way.

## One-time setup per PC

`export_presets.cfg` and `.godot/export_credentials.cfg` are not in git, so
each exporting PC sets these once in **Project > Export > Android**:

- **Architectures:** `arm64-v8a` only.
- **Keystore > Release:** the path in Editor Settings'
  `export/android/debug_keystore` (on the PC:
  `C:/Users/user/AppData/Roaming/Godot/keystores/debug.keystore`),
  **Release User** `androiddebugkey`, **Release Password** the value of
  `export/android/debug_keystore_pass`. Godot refuses a release export
  without these.
- Use the **Android** preset. The "Kejartes" preset overrides Min SDK
  without a Gradle build and refuses to export (CHANGELOG, 2026-10-01).

## Each build

1. Project > Export > Android > Export Project. Tick or untick
   "Export With Debug" per the table above.
2. Shrink it:

   ```bash
   powershell -ExecutionPolicy Bypass -File tools/shrink_apk.ps1 "C:/path/to/Kejartes.apk"
   ```

3. Share `Kejartes-small.apk`. The script prints `before -> after`; if it
   prints a red line instead, no `-small.apk` was written.

Measured: the 2026-09-30 debug APK (both ABIs) went from 387.3 MB to
182.4 MB.

## Phone check (first build, and after an engine upgrade)

On the debug build: open the Lobby, Skin Select, a batik minigame, and the
end-of-grade exam art (Debug > Scenes > Gladi Resik Akhir Kelas). Each
should load as fast as before. Then install the release build over it: it
installs without uninstalling, and five taps top-right open nothing.

If loads are visibly slower, the deflated textures are being seeked
backwards; deflate only the large `.ctex` (see the spec's open risk).
