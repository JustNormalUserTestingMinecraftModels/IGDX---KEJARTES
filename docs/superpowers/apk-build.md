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

The script signs with **this PC's** Godot debug keystore. Builds from the
same PC, debug or release, install over each other and the phone keeps its
save. A build from **another PC** carries a different key: Android refuses
to install it over yours, and uninstalling first wipes the save. To share
one signature across PCs, copy one `debug.keystore` to the other PC and
point its `export/android/debug_keystore` (and the preset's Release
keystore) at it; the password and user stay `debug_keystore_pass` /
`debug_keystore_user`. Never put a build signed this way on Google Play.

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

## Web build (itch.io)

itch.io allows 200 MB per file, and the raw `index.pck` is ~586 MB, so the
export is gzipped in place after Godot writes it: itch.io sends gzip content
under the file's own name with `content-encoding: gzip`, and the browser
unpacks it before Godot reads it. `tools/shrink_web.ps1` does this and proves
each file unpacks to a byte-identical original. Design:
`specs/2026-10-02-web-build-design.md`.

**One-time setup per PC** (`export_presets.cfg` is not in git): Project >
Export > Add > **Web**, then:

- **Variant > Thread Support:** off. **Extensions Support:** off.
- **Vram Texture Compression:** **For Desktop** on **and For Mobile** on.
  Without For Mobile, phone browsers get no usable textures.
- Export as **release** (Export With Debug off): no debug overlay for players.
- The web build runs on the Compatibility (WebGL 2) renderer on its own;
  Android keeps the Mobile renderer.

**Each build:**

1. Export the Web preset into a folder that holds `index.html`, outside the
   project (the PC's build used `Downloads/KejarTes-web/release`). Headless:
   `Godot_console.exe --headless --path <project> --export-release "Web" <folder>/index.html`.
2. Shrink it:

   ```bash
   powershell -ExecutionPolicy Bypass -File tools/shrink_web.ps1 "C:/path/to/folder"
   ```

   It refuses a folder it already processed, restores the originals if any
   check fails, and writes `<folder>-itch.zip` with `index.html` at the root.
3. On itch.io: New project > Kind of project **HTML** > upload the zip >
   tick "This file will be played in the browser". Set the viewport to
   1080 x 1920 (portrait) and leave SharedArrayBuffer off (the build is
   single-threaded).

**Measured 2026-10-02:** `index.pck` 585.6 MB to 172.8 MB, `index.wasm`
37.7 MB to 9.4 MB, the upload zip 181.8 MB. The `.pck` is within 27 MB of
itch.io's limit: anything that adds more than that (more art, a second phone
texture format) needs the zip checked again; the script fails loudly if a
file goes over.

**Checked:** served the gzipped files with `content-encoding: gzip` (a
throwaway local server, not committed) and played in a desktop browser: the
game boots to the title, and the Lobby, Settings and a minigame (Main Bola)
render. **Not checked:** SchoolDay, EndCutscene and the other screens, any
side-by-side with the Mobile renderer, audio, and **phone browsers**.

**Phone-browser test (decides whether phones stay supported):** Godot's web
runtime loads the whole raw `.pck` (~586 MB) into the browser's memory. Open
the itch.io draft page on a phone. If the tab crashes or reloads, export again
with **For Mobile off** (about 330 MB raw, ~115 MB gzipped) and send phone
players the APK.
