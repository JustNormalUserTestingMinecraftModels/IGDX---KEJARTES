# App icon

The game's launcher icon (Thea), from the owner's 1024x1024 `Icon.png`
(2026-10-01). Drop-replaceable at the same paths and sizes.

| File | Size | Used by |
|---|---|---|
| `app_icon.png` | 432x432 | `project.godot` `application/config/icon` (window icon, and the APK's fallback) and the Android preset's `launcher_icons/main_192x192` (Godot scales it down) |
| `app_icon_foreground.png` | 432x432 | `launcher_icons/adaptive_foreground_432x432` |
| `app_icon_background.png` | 432x432 | `launcher_icons/adaptive_background_432x432`: plain cream, the art's own `#F9EDE4` |
| `app_icon_monochrome.png` | 432x432 | `launcher_icons/adaptive_monochrome_432x432`: white ink (hair, outlines, eye) on transparent, which Android 13+ tints when the phone's "Themed icons" is on. Left empty, the export template's Godot robot shows there |

**Adaptive icons (Android 8+) show only the middle 288x288** of each 432
layer (72 of 108 dp), then mask it to the launcher's shape, often a circle.
So the foreground fits the whole drawing into that middle square on a
transparent canvas; a full-bleed foreground shows only hair.

**`export_presets.cfg` is gitignored** (it holds the keystore settings), so
each machine that exports must set the four `launcher_icons/*` slots itself:
Project > Export > Android > Launcher Icons. Left empty, Godot falls back to
`app_icon.png` for the main and foreground layers, and the foreground is then
cropped to the hair.

Android caches launcher icons: uninstall the old APK before installing a new
one to see a change.

432x432 stays under `tests/test_texture_memory.gd`'s 500,000-pixel budget, so
the lossless import is allowed.
