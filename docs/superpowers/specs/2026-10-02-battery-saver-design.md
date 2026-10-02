# Battery saver and a 60 fps cap

Date: 2026-10-02. Status: approved design, not yet built.

## Problem

A phone gets warm playing a debug build. Nothing caps the frame rate
(`project.godot` has no `application/run/max_fps`, no script sets
`Engine.max_fps`), so a 90 or 120 Hz phone renders up to 120 frames a second
even on still menus. MSAA 2D and bloom already have a switch: Settings'
**Grafis HD** (`GameSettings.hd_graphics_enabled`, 2026-09-30).

## Design

1. **Default cap of 60 fps.** `project.godot`: `application/run/max_fps=60`.
   Nothing in the game needs more.
2. **"Hemat Baterai" switch** in Settings' display card, beside Grafis HD.
   - `GameSettings.battery_saver_enabled: bool = false`, saved in
     `settings.cfg` with the other switches; setter emits
     `battery_saver_changed(enabled)`.
   - On: `Engine.max_fps = 30`. Off: back to the project's 60
     (`ProjectSettings.get_setting("application/run/max_fps")`). Applied at
     load and on every flip, by GameSettings itself (it is the autoload that
     owns the value; no other node needs to listen).
   - The fps numbers live in named consts in `GameSettings.gd`
     (`BATTERY_SAVER_FPS := 30`).
   - Row: a `SettingRow` instance (`BatterySaverRow`) in `Settings.tscn`,
     built in the editor, label "Hemat Baterai", subtitle "Batasi ke 30 FPS
     agar HP tidak cepat panas".
   - A toggle in the debug overlay's Look panel (`DebugLookPanel.gd`),
     like `hd_graphics_enabled`.
3. **Grafis HD unchanged.** The two switches are independent.

## Tests

- `test_project_hygiene` (or `test_settings`): `application/run/max_fps`
  is 60.
- `test_settings`: the row exists and is wired; GameSettings saves and
  loads `battery_saver_enabled`; flipping it sets `Engine.max_fps` to 30 and
  back to 60 (restore the original value after).
- The Settings screen still fits 1080x1920 without scrolling (existing fit
  test covers the display card).
- Full-size screenshot of Settings with the new row, sent to the user.
- Phone: play a debug build with Hemat Baterai on; it should stay cooler.

## Out of scope

Automatic thermal or battery-based quality, `low_processor_mode` (the
game animates constantly), changing Grafis HD's default.
