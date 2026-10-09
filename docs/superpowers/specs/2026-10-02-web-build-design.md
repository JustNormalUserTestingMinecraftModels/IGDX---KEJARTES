# Web (HTML) build for itch.io

Date: 2026-10-02. Status: approved design, not yet built.

## Goal

A web build of KejarTes that uploads to itch.io and runs in desktop **and**
phone browsers, with the same art and audio as the APK.

## Constraints (itch.io HTML5 docs, read 2026-10-02)

- At most 500 MB extracted in total, **200 MB per file**, 1,000 files.
- itch.io serves `.pck`, `.wasm`, `.js` and `.html` gzipped, and a file whose
  *content* is already gzip is sent with `content-encoding: gzip` under its
  own name. The browser decompresses it before Godot reads it.

## Measured sizes (2026-10-02, from `.godot/imported`, scaled to the 132 VRAM images)

| Build carries | Raw `.pck` | Gzipped `.pck` |
|---|---|---|
| Desktop textures only | ~330 MB | ~115 MB |
| Desktop + mobile (ETC2) | ~580 MB | ~140 MB |

Raw is over the 200 MB per-file limit; gzipped is under it. So the `.pck`
must be uploaded gzipped.

## Design

1. **Web export preset** (per PC; `export_presets.cfg` is gitignored, so it
   is documented, not committed): threads off
   (`variant/thread_support=false`), `vram_texture_compression/for_desktop`
   and `for_mobile` on, exported as release (no debug overlay). The web
   build runs on the Compatibility (WebGL 2) renderer; `project.godot`'s
   `rendering_method="mobile"` stays for Android.
2. **`tools/shrink_web.ps1 <export folder>`**: gzips `*.pck`, `*.wasm` and
   `*.js` in place under their own names; verifies each decompresses to a
   byte-identical original (SHA-256) and that every file is ≤ 200 MB; writes
   `<folder>-itch.zip` with `index.html` at the root; prints before/after
   sizes. On any failure, the originals are restored and no zip is left.
   Running it twice is refused (a gzipped file is detected by its magic bytes).
3. **Compatibility-renderer check:** run the game locally with
   `--rendering-method gl_compatibility`, screenshot Lobby, Settings, a
   minigame, SchoolDay and EndCutscene at full size, compare with the Mobile
   renderer, and list differences. Fixing them is a follow-up.
4. **Local serve test:** a throwaway server (not committed) sends the gzipped
   files with `content-encoding: gzip`, like itch.io; the game must boot to
   the main menu in the in-app browser.
5. **Docs:** a Web section in `docs/superpowers/apk-build.md` (preset, commands,
   itch.io upload, phone-browser test), a changelog entry, and the CLAUDE.md
   build line widened to name both scripts, kept within the 23,000-char budget.

## Risk

Godot's web runtime loads the whole raw `.pck` (~580 MB) into the browser's
memory. Desktop browsers cope; phone browsers may crash or reload the tab.
The user tests a draft itch.io page on a phone. If it fails, the fallback is
a desktop-only build (`for_mobile` off, ~330 MB raw) and phone players use
the APK.

## Out of scope

Fixing Compatibility-renderer differences, the oversized-art pass
(cancelled 2026-10-02), PWA/offline support, threads.
