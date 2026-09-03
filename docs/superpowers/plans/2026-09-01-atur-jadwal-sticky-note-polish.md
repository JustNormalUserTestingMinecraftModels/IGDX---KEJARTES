# AturJadwal Sticky-Note Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the five day sticky notes on `atur_jadwal.tscn` read as lively hand-pinned paper — each scheduled note shows the pembelajaran name, a one-word flavour label, a category icon peeking from behind, a soft drop shadow, and a squash-pop when assigned; national-holiday days get a distinct locked-gold treatment.

**Architecture:** The five `BGHari` day buttons stop being bare `TextureButton`+`Label` pairs hand-edited five times in the scene. They become five instances of a new `Scenes/AturJadwal/DayStickyNote.tscn` template backed by one documented `@tool` script (`DayStickyNote.gd`). The template owns the shadow sprite (a shared `soft_shadow.gdshader`), the peeking back-icon, the three stacked labels, and a small lock glyph. `atur_jadwal.gd` drops its per-button label/tint code and calls three template methods instead: `show_empty()`, `show_scheduled(category)`, `show_holiday(title)`. No ThemeFactory variation is added, so **no theme rebake / editor restart is required**.

**Tech Stack:** Godot 4.6 (`mobile` renderer), GDScript, `@tool` scripts, `McpTestSuite` tests run via the Godot AI MCP `test_run`, `EditorScript` for one-time PNG generation (no Python/ImageMagick/Inkscape is installed on this machine).

**Spec:** This document — see **§ Design** below. There is no separate spec file; the design was settled in a brainstorming pass on 2026-09-01 (7 clarifying answers, recorded in § Design).

## Global Constraints

- Godot **4.6**, portrait 1080×1920, `mobile` renderer.
- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation. Only accepted exception: layout-only constant overrides (`separation`, `margin_*`). This plan adds **no** new variation — it reuses `H2Label`, `CaptionLabel`, `MicroLabel`.
- **No visual is built at runtime.** Static chrome is a node in the `.tscn`; repeated units are a `PackedScene` template; responsive geometry is a `@tool` script driven by documented `@export` knobs. The template script must not call `SomeControl.new()` — `tests/test_viewport_editability.gd` is a one-way ratchet and `atur_jadwal.gd`'s frozen count (17) must not rise.
- Every script needs a `##` file header and a `##` line on every `@export` (`tests/test_script_documentation.gd` enforces this).
- Test suites must be `@tool`, must not be coroutines (the runner does `suite.call(name)` without awaiting), and `@tool` scripts the runner instantiates live must gate real `_ready()` side effects behind `if Engine.is_editor_hint(): return` while leaving pure signal wiring ungated.
- **Never hand-edit `atur_jadwal.tscn` / `DayStickyNote.tscn` while the editor is attached.** Go through the editor MCP: `scene_open` → `node_create` / `node_set_property` / `node_manage` (or `batch_execute` with `create_node` / `set_property` / `move_node` / `delete_node`) → `scene_save`. `anchors_preset` is inert (set the four anchors); numbers must be unquoted; `node_create` appends last so z-order needs `move_node`; a node's type can only change by delete-and-recreate.
- **Rescan after editing a `.gd`, before running tests:** `filesystem_manage(op="scan")`, or `test_run` serves a stale script.
- Game-facing identifiers and UI text are **Indonesian**; engine/systems code is English.
- Commits: Conventional Commits with a scope, e.g. `feat(atur-jadwal): ...`. End commit messages with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.

---

## § Design

### Current behaviour (what exists today)

`Scenes/AturJadwal/atur_jadwal.tscn` → node `BGHari` (a `TextureRect`, whiteboard.png) has five child `TextureButton`s named `Senin`, `Selasa`, `Rabu`, `Kamis`, `Jumat`, each using `res://Assets/Images/UI/stickynotes.png` (`ignore_texture_size = true`), each with a single child `Label` (`H2Label` variation, `modulate = black`) reading `"SENIN"` etc.

`Scripts/AturJadwal/atur_jadwal.gd::_update_day_button_colors()` (around line 480) is the only code that restyles them:

- **Holiday day** (week in `HOLIDAYS`, day matches): `btn.self_modulate = tokens.state_danger` (red), label `"SENIN\n(LIBUR)"`.
- **Scheduled day**: `btn.self_modulate = tokens.category_color(category)`, label `"SENIN"`.
- **Empty day**: `btn.self_modulate = tokens.surface_sunken` (grey), label `"SENIN"`.

`_check_and_lock_holidays()` independently writes `GameState.day_schedules[student_id][day_name] = {category:"Istirahat", …}` for every student on a holiday, so a holiday day is *also* a scheduled day; the holiday branch is checked first and wins.

Other code that touches the day nodes and must keep working unchanged:

- `_start_day_button_sway()` — sets `btn.pivot_offset = btn.size/2` and loops a small `rotation` tween (idle sway). Operates on the node as a `Control`.
- `_animate_day_button_press(btn)` — `pivot_offset`, `scale` tween, then `tween.tween_callback(_show_penjadwalan_popup)`.
- `_connect_day_button(btn, day)` — `btn.pressed.connect(_on_day_pressed.bind(day))`.
- `_get_day_button(day_name)` — returns `senin_btn` … per a `match`.
- Tutorial: `_show_step()` / `_highlight_multiple()` do `get_node_or_null("BGHari/Senin")`, check `is Control`, read `.size`, `.visible`, `.get_global_transform()`. `_get_button_display_name()` iterates a node's children looking for a `Label`, else returns `node.name`.

### Brainstorming decisions (2026-09-01)

1. **Note text** = day name + subject display name + a one-word flavour label (three stacked lines).
2. **Flavour words** (decorative, Indonesian): `Akademis → "Fokus"`, `SeniBudaya → "Berkarya"`, `Olahraga → "Semangat"`, `Wirausaha → "Cuan"`, `Istirahat → "Santai"`.
3. **Subject display names** reuse the UI wording already used by `ActivityRow` instances / asserted by `tests/test_atur_jadwal.gd::test_display_names_are_indonesian_and_decoupled_from_category_keys`: `Akademis → "Akademik"`, `SeniBudaya → "Seni Budaya"`, `Olahraga → "Atletik"`, `Wirausaha → "Wirausaha"`, `Istirahat → "Libur"`.
4. **Back icon** peeks out of the note's **top-right corner** (roughly a third of it past the paper edge), drawn *behind* the paper.
5. **Icon art**: Akademis / SeniBudaya / Olahraga reuse the existing `res://Assets/Images/StudentCard/stat_akademis.png` / `stat_senibudaya.png` / `stat_olahraga.png`. Wirausaha, Istirahat, and the national-holiday flag have **no art** — generate flat geometric **placeholder** transparent PNGs (256×256) for the visual team to override in place later.
6. **Drop shadow** = a soft offset shadow *behind the paper*, following the paper's shape: a second `stickynotes.png` sprite, tinted translucent black, offset down-right, blurred by a shared `soft_shadow.gdshader`.
7. **National-holiday note** = **gold** paper (`category_color("Libur")` = `cat_libur`), `SubjectLabel` shows the real holiday title (e.g. `"Kemerdekaan RI"`), `FlavorLabel` = `"Libur Nasional"`, a small 🔒 lock glyph shown, and a flag/calendar placeholder back-icon. It must read as fixed and non-negotiable — visually distinct from a player-chosen purple `Istirahat` note.
8. **Juice** = keep the existing idle sway; add a squash-pop on the note **plus** the back-icon fading/sliding into view **only when a day newly becomes scheduled or its category changes** (not on every `_update_student_display()` repaint).
9. **Structure** = one reusable `DayStickyNote.tscn` template + `@tool` script; five instances in `atur_jadwal.tscn`.

### Template node tree — `Scenes/AturJadwal/DayStickyNote.tscn`

```
DayStickyNote            Control        root; script DayStickyNote.gd; custom_minimum_size = (271, 267)
├─ Shadow               TextureRect    stickynotes.png; ShaderMaterial(soft_shadow.gdshader);
│                                      self_modulate = Color(0,0,0,0.33); offset +(14,18) vs Paper;
│                                      scaled 1.03; mouse_filter = 2 (ignore); expand_mode = 1
├─ BackIcon             TextureRect    peeks past top-right; offset roughly left=150 top=-70,
│                                      size 175×175; expand_mode = 1, stretch_mode = 5 (keep-aspect-centered);
│                                      mouse_filter = 2; starts hidden
└─ Paper                TextureButton  stickynotes.png; ignore_texture_size = true; stretch_mode = 0;
   │                                   anchored to fill the root; self_modulate tinted per state;
   │                                   set_meta(Juice.NO_AUTO_JUICE, true) in _ready
   ├─ DayLabel          Label          H2Label; modulate = black; text "SENIN"; top of the paper
   ├─ SubjectLabel      Label          CaptionLabel; modulate = black; middle line; starts ""
   ├─ FlavorLabel       Label          MicroLabel; modulate = black; bottom line; starts ""
   └─ Lock              Label          MicroLabel; text "🔒"; top-left of the paper; starts hidden
```

- z-order (child index): `Shadow` (0) < `BackIcon` (1) < `Paper` (2). `node_create` appends last, so after creating all three, `move_node` `Shadow` to index 0 and `BackIcon` to index 1.
- Label placement is layout-only offsets; do **not** add `theme_override_font_size` — the three variations already differ in size (`H2Label` > `CaptionLabel` (22) > `MicroLabel` (18)).
- The root carries `custom_minimum_size = (271, 267)` so `tests/test_atur_jadwal.gd::test_interactive_controls_meet_the_minimum_touch_target` (needs ≥ `touch_target_min` = 96) keeps passing even before `atur_jadwal.tscn` sets the instance offsets.
- `category_icons` (Dictionary) and `holiday_icon` (Texture2D) `@export`s are set **once on the `DayStickyNote.tscn` root**, so the five instances inherit them and there is only one copy to maintain.

### `DayStickyNote.gd` public interface

```gdscript
@tool
class_name DayStickyNote
extends Control

signal pressed   # re-emitted from the inner Paper TextureButton

const DISPLAY_NAMES := {
    "Akademis": "Akademik", "SeniBudaya": "Seni Budaya", "Olahraga": "Atletik",
    "Wirausaha": "Wirausaha", "Istirahat": "Libur",
}
const FLAVOR_WORDS := {
    "Akademis": "Fokus", "SeniBudaya": "Berkarya", "Olahraga": "Semangat",
    "Wirausaha": "Cuan", "Istirahat": "Santai",
}

@export var category_icons: Dictionary = {}   # category key -> Texture2D, set on the .tscn root
@export var holiday_icon: Texture2D           # flag/calendar placeholder, set on the .tscn root

func set_day_name(day_name: String) -> void         # sets DayLabel to day_name.to_upper()
func show_empty() -> void                            # grey paper, day line only, hide subject/flavor/icon/lock
func show_scheduled(category: String) -> void        # tint = category_color(category); fill subject + flavour;
                                                     #   BackIcon = category_icons[category], shown;
                                                     #   pop + icon-reveal iff state/category changed
func show_holiday(title: String) -> void            # gold tint = category_color("Libur"); SubjectLabel = title;
                                                     #   FlavorLabel = "Libur Nasional"; Lock shown;
                                                     #   BackIcon = holiday_icon, shown; pop iff newly holiday
func play_assign_pop() -> void                       # squash/scale tween on self + BackIcon fade/slide-in;
                                                     #   returns immediately if Engine.is_editor_hint()
```

Internal state: `var _state := ""` (`"empty"` / `"scheduled"` / `"holiday"`) and `var _category := ""`. `show_scheduled` / `show_holiday` call `play_assign_pop()` only when `_state` or `_category` actually changed, then update them. `_ready()` connects `Paper.pressed` → `pressed.emit` (ungated pure wiring), sets `pivot_offset = size/2`, sets `Paper`'s `NO_AUTO_JUICE` meta, and gates any tween/audio behind `Engine.is_editor_hint()`. All colours come from `DesignTokens.load_default()` — **no `Color(` literal** in this script.

### `atur_jadwal.gd` changes (Task 5)

`_update_day_button_colors()` inner body per day becomes:

```gdscript
var note := btn as DayStickyNote
if note == null:
    continue
note.set_day_name(day_name)
if week_holidays.has(day_name):
    note.show_holiday(week_holidays[day_name]["title"])
elif schedules.has(day_name):
    note.show_scheduled(schedules[day_name]["category"])
else:
    note.show_empty()
```

Delete the `var label = btn.get_child(0) as Label` line and every `label.text = …`. Everything else in the file is untouched — `senin_btn` … `jumat_btn` `@onready`s still resolve (`$BGHari/Senin` etc.), `.pressed` still exists (the template re-emits it), and `_start_day_button_sway` / `_animate_day_button_press` still operate on the `Control` root.

### Files

- **Create** `Scripts/Design/GenerateStickyNoteIcons.gd` — `@tool extends EditorScript`; draws three 256×256 transparent PNGs and `save_png`s them to `Assets/Images/AturJadwal/`.
- **Create** `Assets/Images/AturJadwal/icon_wirausaha_placeholder.png` (+ `.import`) — coin glyph.
- **Create** `Assets/Images/AturJadwal/icon_istirahat_placeholder.png` (+ `.import`) — crescent glyph.
- **Create** `Assets/Images/AturJadwal/icon_libur_nasional_placeholder.png` (+ `.import`) — flag glyph.
- **Create** `Scripts/Shaders/soft_shadow.gdshader` — `canvas_item` 9-tap gaussian blur, alpha-preserving.
- **Create** `Scripts/AturJadwal/DayStickyNote.gd` — the template script.
- **Create** `Scenes/AturJadwal/DayStickyNote.tscn` — the template scene.
- **Create** `tests/test_sticky_note_assets.gd` — the three PNGs load as 256×256 `Texture2D`; the shader file exists and declares `shader_type canvas_item` + a `blur` uniform.
- **Create** `tests/test_day_sticky_note.gd` — template structure, script docs, dict coverage, method behaviour, `pressed` re-emit.
- **Modify** `Scenes/AturJadwal/atur_jadwal.tscn` — replace the five `BGHari` children with `DayStickyNote` instances (via editor MCP).
- **Modify** `Scripts/AturJadwal/atur_jadwal.gd:480-516` — rewire `_update_day_button_colors()` to the template API.
- **Modify** `tests/test_atur_jadwal.gd` — retarget two tests (`test_day_buttons_are_tinted_via_category_color`, `test_the_whiteboard_and_sticky_notes_are_unchanged`) to the new structure.
- **Modify** `docs/superpowers/specs/2026-09-01-atur-jadwal-mockup.md` — append a short STATUS note recording the sticky-note polish.

---

## Task 1: Placeholder icon generator + three PNG assets

**Files:**
- Create: `Scripts/Design/GenerateStickyNoteIcons.gd`
- Create (generated): `Assets/Images/AturJadwal/icon_wirausaha_placeholder.png`, `icon_istirahat_placeholder.png`, `icon_libur_nasional_placeholder.png` (+ their `.import` siblings)
- Test: `tests/test_sticky_note_assets.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: three texture paths, referenced by name in Task 3's `DayStickyNote.tscn` root `category_icons` / `holiday_icon`:
  - `res://Assets/Images/AturJadwal/icon_wirausaha_placeholder.png`
  - `res://Assets/Images/AturJadwal/icon_istirahat_placeholder.png`
  - `res://Assets/Images/AturJadwal/icon_libur_nasional_placeholder.png`

- [ ] **Step 1: Write the failing test**

Create `tests/test_sticky_note_assets.gd`:

```gdscript
@tool
extends McpTestSuite

## The three placeholder icons the DayStickyNote template needs but that have
## no real art yet (Wirausaha / Istirahat / national holiday). Generated by
## Scripts/Design/GenerateStickyNoteIcons.gd (an EditorScript, File > Run).
## This suite is a plain asset-existence scan -- it instantiates nothing.

func suite_name() -> String:
    return "sticky_note_assets"

const _ICONS := [
    "res://Assets/Images/AturJadwal/icon_wirausaha_placeholder.png",
    "res://Assets/Images/AturJadwal/icon_istirahat_placeholder.png",
    "res://Assets/Images/AturJadwal/icon_libur_nasional_placeholder.png",
]

func test_placeholder_icons_exist_and_are_256_square() -> void:
    for path in _ICONS:
        assert_true(ResourceLoader.exists(path), "missing generated icon: " + path)
        var tex := load(path) as Texture2D
        assert_true(tex != null, path + " did not load as a Texture2D")
        if tex != null:
            assert_eq(tex.get_width(), 256, path + " must be 256 px wide")
            assert_eq(tex.get_height(), 256, path + " must be 256 px tall")

func test_generator_script_exists_and_is_documented() -> void:
    var p := "res://Scripts/Design/GenerateStickyNoteIcons.gd"
    assert_true(ResourceLoader.exists(p), "generator script is missing")
    var src := FileAccess.get_file_as_string(p)
    assert_true(src.begins_with("@tool"), "generator must be @tool")
    assert_true(src.contains("extends EditorScript"), "generator must extend EditorScript")
    assert_true(src.contains("## "), "generator needs a ## doc header")
```

- [ ] **Step 2: Run it to confirm it fails**

Run via MCP: `test_run` filtered to `sticky_note_assets`.
Expected: FAIL — script and icons do not exist yet.

- [ ] **Step 3: Write the generator EditorScript**

Create `Scripts/Design/GenerateStickyNoteIcons.gd`:

```gdscript
@tool
extends EditorScript

## One-time generator for the three DayStickyNote placeholder icons that have
## no real art yet: a coin (Wirausaha), a crescent (Istirahat) and a flag
## (national holiday). Run it from the editor via File > Run (Ctrl+Shift+X).
## The visual team overrides these PNGs in place later -- keep the file names.
##
## No Python / ImageMagick / Inkscape is installed on this machine, so the
## glyphs are drawn straight into an Image with flat geometry. They are
## deliberately crude: they exist so layout and wiring have something to
## show, not as finished art.

const SIZE := 256
const OUT_DIR := "res://Assets/Images/AturJadwal/"

func _run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
    _save(_draw_coin(),   OUT_DIR + "icon_wirausaha_placeholder.png")
    _save(_draw_crescent(), OUT_DIR + "icon_istirahat_placeholder.png")
    _save(_draw_flag(),   OUT_DIR + "icon_libur_nasional_placeholder.png")
    var fs := EditorInterface.get_resource_filesystem()
    if fs:
        fs.scan()
    print("[GenerateStickyNoteIcons] wrote 3 placeholders to ", OUT_DIR)

func _blank() -> Image:
    return Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)

func _save(img: Image, path: String) -> void:
    var err := img.save_png(ProjectSettings.globalize_path(path))
    assert(err == OK)

# --- glyph helpers -------------------------------------------------------

func _fill_disc(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
    var r2 := r * r
    for y in range(SIZE):
        for x in range(SIZE):
            var dx := x - cx
            var dy := y - cy
            if dx * dx + dy * dy <= r2:
                img.set_pixel(x, y, col)

func _fill_rect(img: Image, x0: int, y0: int, w: int, h: int, col: Color) -> void:
    for y in range(max(0, y0), min(SIZE, y0 + h)):
        for x in range(max(0, x0), min(SIZE, x0 + w)):
            img.set_pixel(x, y, col)

func _draw_coin() -> Image:
    var img := _blank()
    var teal := Color("00a389")          # matches DesignTokens.cat_wirausaha
    _fill_disc(img, 128, 128, 96, teal)
    _fill_disc(img, 128, 128, 70, teal.darkened(0.18))
    _fill_disc(img, 128, 128, 62, teal)
    return img

func _draw_crescent() -> Image:
    var img := _blank()
    var violet := Color("6b4fe0")        # matches DesignTokens.cat_istirahat
    _fill_disc(img, 128, 128, 92, violet)
    _fill_disc(img, 168, 108, 82, Color(0, 0, 0, 0))   # bite out -> crescent
    return img

func _draw_flag() -> Image:
    var img := _blank()
    var gold := Color("ffc93c")          # matches DesignTokens.cat_libur
    var pole := gold.darkened(0.35)
    _fill_rect(img, 60, 36, 12, 184, pole)              # pole
    _fill_rect(img, 72, 44, 120, 78, gold)              # banner
    return img
```

- [ ] **Step 4: Run the generator in the attached editor**

In the Godot editor, open `Scripts/Design/GenerateStickyNoteIcons.gd` and run it with **File > Run** (Ctrl+Shift+X). Confirm the console prints `[GenerateStickyNoteIcons] wrote 3 placeholders`. Then `filesystem_manage(op="scan")` so the `.import` files are generated.

- [ ] **Step 5: Run the test to confirm it passes**

Run: `test_run` filtered to `sticky_note_assets`.
Expected: PASS (both tests).

- [ ] **Step 6: Commit**

```bash
git add Scripts/Design/GenerateStickyNoteIcons.gd tests/test_sticky_note_assets.gd "Assets/Images/AturJadwal/"
git commit -m "feat(atur-jadwal): generate placeholder icons for the sticky-note categories

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 2: `soft_shadow.gdshader`

**Files:**
- Create: `Scripts/Shaders/soft_shadow.gdshader`
- Test: add one test to `tests/test_sticky_note_assets.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `res://Scripts/Shaders/soft_shadow.gdshader`, applied as a `ShaderMaterial` on `DayStickyNote.tscn`'s `Shadow` node (Task 3). Uniform: `blur` (float, texels, default `2.5`).

- [ ] **Step 1: Add the failing test**

Append to `tests/test_sticky_note_assets.gd`:

```gdscript
func test_soft_shadow_shader_exists() -> void:
    var p := "res://Scripts/Shaders/soft_shadow.gdshader"
    assert_true(ResourceLoader.exists(p), "soft_shadow.gdshader is missing")
    var src := FileAccess.get_file_as_string(p)
    assert_true(src.contains("shader_type canvas_item"), "must be a canvas_item shader")
    assert_true(src.contains("uniform float blur"), "must expose a `blur` uniform")
    var sh := load(p) as Shader
    assert_true(sh != null, "did not load as a Shader resource")
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `test_run` filtered to `sticky_note_assets`.
Expected: FAIL on `test_soft_shadow_shader_exists`.

- [ ] **Step 3: Write the shader**

Create `Scripts/Shaders/soft_shadow.gdshader`:

```glsl
// Soft drop-shadow for a sprite: a small separable-ish gaussian applied in a
// single pass (9 offset taps) that blurs only the alpha silhouette, so the
// node's own `self_modulate` (a translucent black) stays flat while the edge
// goes soft. Used by DayStickyNote.tscn's Shadow node behind each sticky
// note. `blur` is in source texels; keep it small (2-4) -- this is chrome,
// not a bloom pass.
shader_type canvas_item;

uniform float blur : hint_range(0.0, 8.0) = 2.5;

void fragment() {
    vec2 px = TEXTURE_PIXEL_SIZE * blur;
    float a = 0.0;
    a += texture(TEXTURE, UV + vec2(-px.x, -px.y)).a * 0.0625;
    a += texture(TEXTURE, UV + vec2( 0.0,  -px.y)).a * 0.125;
    a += texture(TEXTURE, UV + vec2( px.x, -px.y)).a * 0.0625;
    a += texture(TEXTURE, UV + vec2(-px.x,  0.0 )).a * 0.125;
    a += texture(TEXTURE, UV                     ).a * 0.25;
    a += texture(TEXTURE, UV + vec2( px.x,  0.0 )).a * 0.125;
    a += texture(TEXTURE, UV + vec2(-px.x,  px.y)).a * 0.0625;
    a += texture(TEXTURE, UV + vec2( 0.0,   px.y)).a * 0.125;
    a += texture(TEXTURE, UV + vec2( px.x,  px.y)).a * 0.0625;
    COLOR = vec4(COLOR.rgb, COLOR.a * a);
}
```

- [ ] **Step 4: Rescan and run the test**

`filesystem_manage(op="scan")`, then `test_run` filtered to `sticky_note_assets`.
Expected: PASS (all three tests in the suite).

- [ ] **Step 5: Commit**

```bash
git add Scripts/Shaders/soft_shadow.gdshader tests/test_sticky_note_assets.gd
git commit -m "feat(atur-jadwal): add a reusable soft drop-shadow shader

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: `DayStickyNote` template (script + scene)

**Files:**
- Create: `Scripts/AturJadwal/DayStickyNote.gd`
- Create: `Scenes/AturJadwal/DayStickyNote.tscn`
- Test: `tests/test_day_sticky_note.gd`

**Interfaces:**
- Consumes: the three placeholder icons (Task 1), `soft_shadow.gdshader` (Task 2), `res://Assets/Images/UI/stickynotes.png`, `res://Assets/Images/StudentCard/stat_akademis.png` / `stat_senibudaya.png` / `stat_olahraga.png`, `DesignTokens` (`category_color`, `surface_sunken`), `Juice.NO_AUTO_JUICE`.
- Produces: `class_name DayStickyNote extends Control` with `signal pressed`, `const DISPLAY_NAMES`, `const FLAVOR_WORDS`, `@export var category_icons: Dictionary`, `@export var holiday_icon: Texture2D`, and methods `set_day_name(day_name: String) -> void`, `show_empty() -> void`, `show_scheduled(category: String) -> void`, `show_holiday(title: String) -> void`, `play_assign_pop() -> void`. Consumed by Task 4 (scene instances) and Task 5 (`atur_jadwal.gd`).

- [ ] **Step 1: Write the failing test**

Create `tests/test_day_sticky_note.gd`:

```gdscript
@tool
extends McpTestSuite

## The DayStickyNote template: one reusable sticky note for the AturJadwal
## day row. Five instances live under atur_jadwal.tscn's BGHari. This suite
## instantiates the template directly and drives its three state methods.
##
## Must be @tool; no coroutine tests (the runner does not await).

func suite_name() -> String:
    return "day_sticky_note"

const _SCENE := "res://Scenes/AturJadwal/DayStickyNote.tscn"
const _SCRIPT := "res://Scripts/AturJadwal/DayStickyNote.gd"

var _note: DayStickyNote

func setup() -> void:
    _note = (load(_SCENE) as PackedScene).instantiate()
    Engine.get_main_loop().root.add_child(_note)
    track(_note)

# ---- structure --------------------------------------------------------

func test_scene_tree_shape() -> void:
    assert_true(_note is DayStickyNote, "root must be a DayStickyNote")
    for p in ["Shadow", "BackIcon", "Paper", "Paper/DayLabel",
              "Paper/SubjectLabel", "Paper/FlavorLabel", "Paper/Lock"]:
        assert_true(_note.get_node_or_null(p) != null, "missing node: " + p)
    assert_true(_note.get_node("Paper") is TextureButton, "Paper must be a TextureButton")
    var shadow := _note.get_node("Shadow") as TextureRect
    assert_true(shadow.material is ShaderMaterial, "Shadow needs the soft_shadow ShaderMaterial")

func test_z_order_puts_paper_in_front() -> void:
    assert_true(_note.get_node("Shadow").get_index() < _note.get_node("BackIcon").get_index(),
        "Shadow must be behind BackIcon")
    assert_true(_note.get_node("BackIcon").get_index() < _note.get_node("Paper").get_index(),
        "BackIcon must be behind Paper")

func test_no_theme_overrides() -> void:
    var offenders: Array[String] = []
    _collect_overrides(_note, offenders)
    assert_eq(offenders.size(), 0, "theme_override_* on: " + ", ".join(offenders))

func _collect_overrides(n: Node, out: Array) -> void:
    for pr in n.get_property_list():
        var nm: String = pr.get("name", "")
        if nm.begins_with("theme_override_") and not (
                nm.begins_with("theme_override_constants/")):
            if n.get(nm) != null:
                out.append("%s.%s" % [n.name, nm])
    for c in n.get_children():
        _collect_overrides(c, out)

func test_script_has_no_color_literals() -> void:
    var src := FileAccess.get_file_as_string(_SCRIPT)
    var re := RegEx.create_from_string("Color\\s*\\(")
    assert_eq(re.search_all(src).size(), 0, "read colours from DesignTokens, not Color()")

func test_script_is_documented() -> void:
    var src := FileAccess.get_file_as_string(_SCRIPT)
    assert_true(src.begins_with("@tool"), "must be @tool")
    assert_true(src.contains("class_name DayStickyNote"), "needs class_name")
    for line in src.split("\n"):
        if line.strip_edges().begins_with("@export"):
            pass  # documentation adjacency is enforced by test_script_documentation.gd
    assert_true(src.contains("## "), "needs a ## header")

# ---- dictionaries match ActivityRow's wording ------------------------

func test_display_names_cover_all_five_categories() -> void:
    var expected := {
        "Akademis": "Akademik", "SeniBudaya": "Seni Budaya", "Olahraga": "Atletik",
        "Wirausaha": "Wirausaha", "Istirahat": "Libur",
    }
    assert_eq(DayStickyNote.DISPLAY_NAMES, expected, "DISPLAY_NAMES drifted from the ActivityRow wording")

func test_flavor_words_cover_all_five_categories() -> void:
    for c in ["Akademis", "SeniBudaya", "Olahraga", "Wirausaha", "Istirahat"]:
        assert_true(DayStickyNote.FLAVOR_WORDS.has(c), "no flavour word for " + c)
        assert_true(String(DayStickyNote.FLAVOR_WORDS[c]).length() > 0, c + " flavour word is empty")

func test_icon_exports_are_populated_from_the_tscn_root() -> void:
    for c in ["Akademis", "SeniBudaya", "Olahraga", "Wirausaha", "Istirahat"]:
        assert_true(_note.category_icons.has(c), "category_icons missing " + c)
        assert_true(_note.category_icons[c] is Texture2D, c + " icon is not a Texture2D")
    assert_true(_note.holiday_icon is Texture2D, "holiday_icon not set on the template root")

# ---- behaviour ------------------------------------------------------

func test_show_scheduled_fills_text_icon_and_tint() -> void:
    _note.set_day_name("Senin")
    _note.show_scheduled("Olahraga")
    assert_eq((_note.get_node("Paper/DayLabel") as Label).text, "SENIN")
    assert_eq((_note.get_node("Paper/SubjectLabel") as Label).text, "Atletik")
    assert_eq((_note.get_node("Paper/FlavorLabel") as Label).text, "Semangat")
    assert_true((_note.get_node("Paper/SubjectLabel") as Label).visible)
    assert_true((_note.get_node("BackIcon") as TextureRect).visible)
    assert_true((_note.get_node("BackIcon") as TextureRect).texture != null)
    assert_false((_note.get_node("Paper/Lock") as Label).visible, "no lock on a normal scheduled day")
    var tint := (_note.get_node("Paper") as TextureButton).self_modulate
    assert_true(tint.is_equal_approx(DesignTokens.load_default().category_color("Olahraga")),
        "paper tint must be the Olahraga category colour")

func test_show_empty_hides_the_extras() -> void:
    _note.show_scheduled("Akademis")
    _note.show_empty()
    assert_false((_note.get_node("Paper/SubjectLabel") as Label).visible)
    assert_false((_note.get_node("Paper/FlavorLabel") as Label).visible)
    assert_false((_note.get_node("BackIcon") as TextureRect).visible)
    assert_false((_note.get_node("Paper/Lock") as Label).visible)
    var tint := (_note.get_node("Paper") as TextureButton).self_modulate
    assert_true(tint.is_equal_approx(DesignTokens.load_default().surface_sunken))

func test_show_holiday_is_gold_locked_and_titled() -> void:
    _note.set_day_name("Rabu")
    _note.show_holiday("Kemerdekaan RI")
    assert_eq((_note.get_node("Paper/DayLabel") as Label).text, "RABU")
    assert_eq((_note.get_node("Paper/SubjectLabel") as Label).text, "Kemerdekaan RI")
    assert_eq((_note.get_node("Paper/FlavorLabel") as Label).text, "Libur Nasional")
    assert_true((_note.get_node("Paper/Lock") as Label).visible, "holiday note must show the lock")
    assert_true((_note.get_node("BackIcon") as TextureRect).visible)
    var tint := (_note.get_node("Paper") as TextureButton).self_modulate
    assert_true(tint.is_equal_approx(DesignTokens.load_default().category_color("Libur")),
        "holiday paper must be the Libur/gold colour")

func test_pressed_is_re_emitted_from_the_inner_button() -> void:
    var got := [false]
    _note.pressed.connect(func(): got[0] = true)
    (_note.get_node("Paper") as BaseButton).pressed.emit()
    assert_true(got[0], "DayStickyNote must re-emit the inner Paper button's `pressed`")

func test_touch_target_is_big_enough() -> void:
    var tokens := DesignTokens.load_default()
    var s := _note.get_combined_minimum_size()
    assert_true(minf(s.x, s.y) >= float(tokens.touch_target_min),
        "template min size %dx%d is below the %d px touch target" % [int(s.x), int(s.y), tokens.touch_target_min])
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `test_run` filtered to `day_sticky_note`.
Expected: FAIL — neither the script nor the scene exists.

- [ ] **Step 3: Write `DayStickyNote.gd`**

Create `Scripts/AturJadwal/DayStickyNote.gd`:

```gdscript
@tool
class_name DayStickyNote
extends Control

## One sticky note in AturJadwal's day row. Five instances sit under
## atur_jadwal.tscn's BGHari (named Senin..Jumat); atur_jadwal.gd drives each
## one every time the selected student or their schedule changes, calling
## exactly one of show_empty() / show_scheduled() / show_holiday().
##
## The note is three stacked lines on a tinted paper (day / pembelajaran name
## / one-word flavour), a category icon peeking from behind the top-right
## corner, and a soft drop shadow. A national-holiday day is locked gold with
## a padlock glyph. When a day newly becomes scheduled -- or its category
## changes -- the note plays a squash-pop and the icon slides into view.
##
## All colour comes from DesignTokens; there is no Color() literal here and
## no theme_override_*. This is a @tool script so the note previews in the
## editor, so every real side effect (tweens, audio) is gated behind
## Engine.is_editor_hint(); the pressed re-emit is pure wiring and stays
## ungated so tests can exercise it.

## Emitted when the inner Paper button is pressed. atur_jadwal.gd connects
## this exactly where it used to connect the old TextureButton's `pressed`.
signal pressed

## Code category -> the Indonesian word the player reads. Kept identical to
## the ActivityRow instances in atur_jadwal.tscn (asserted by both suites).
const DISPLAY_NAMES := {
	"Akademis": "Akademik",
	"SeniBudaya": "Seni Budaya",
	"Olahraga": "Atletik",
	"Wirausaha": "Wirausaha",
	"Istirahat": "Libur",
}

## Code category -> a decorative one-word mood label on the note's third line.
const FLAVOR_WORDS := {
	"Akademis": "Fokus",
	"SeniBudaya": "Berkarya",
	"Olahraga": "Semangat",
	"Wirausaha": "Cuan",
	"Istirahat": "Santai",
}

const _HOLIDAY_FLAVOR := "Libur Nasional"

## Category key -> the icon that peeks from behind the note. Set once on the
## DayStickyNote.tscn root so all five instances share one copy. Akademis /
## SeniBudaya / Olahraga use the real stat_*.png; Wirausaha / Istirahat use
## generated placeholders for the visual team to override in place.
@export var category_icons: Dictionary = {}

## The peeking icon for a national-holiday note (a flag/calendar placeholder).
@export var holiday_icon: Texture2D

@onready var _paper: TextureButton = $Paper
@onready var _day_label: Label = $Paper/DayLabel
@onready var _subject_label: Label = $Paper/SubjectLabel
@onready var _flavor_label: Label = $Paper/FlavorLabel
@onready var _lock: Label = $Paper/Lock
@onready var _back_icon: TextureRect = $BackIcon

var _tokens: DesignTokens
var _state := ""       # "" | "empty" | "scheduled" | "holiday"
var _category := ""


func _ready() -> void:
	_tokens = DesignTokens.load_default()
	pivot_offset = size / 2.0
	if _paper:
		_paper.set_meta(Juice.NO_AUTO_JUICE, true)
		if not _paper.pressed.is_connected(_on_paper_pressed):
			_paper.pressed.connect(_on_paper_pressed)
	# Default look until atur_jadwal.gd calls a state method.
	if _state == "":
		show_empty()


func _on_paper_pressed() -> void:
	pressed.emit()


func set_day_name(day_name: String) -> void:
	if _day_label:
		_day_label.text = day_name.to_upper()


func show_empty() -> void:
	_apply(_get_tokens().surface_sunken, false, false)
	_state = "empty"
	_category = ""


func show_scheduled(category: String) -> void:
	var changed := _state != "scheduled" or _category != category
	_subject_label.text = DISPLAY_NAMES.get(category, category)
	_flavor_label.text = FLAVOR_WORDS.get(category, "")
	_back_icon.texture = _get_icon(category)
	_apply(_get_tokens().category_color(category), true, false)
	_state = "scheduled"
	_category = category
	if changed:
		play_assign_pop()


func show_holiday(title: String) -> void:
	var changed := _state != "holiday"
	_subject_label.text = title
	_flavor_label.text = _HOLIDAY_FLAVOR
	_back_icon.texture = holiday_icon
	_apply(_get_tokens().category_color("Libur"), true, true)
	_state = "holiday"
	_category = ""
	if changed:
		play_assign_pop()


## Sets the paper tint and the visibility of the subject line, flavour line,
## back icon and lock glyph in one place.
func _apply(tint: Color, show_extras: bool, show_lock: bool) -> void:
	if _paper:
		_paper.self_modulate = tint
	if _subject_label:
		_subject_label.visible = show_extras
	if _flavor_label:
		_flavor_label.visible = show_extras
	if _back_icon:
		_back_icon.visible = show_extras
	if _lock:
		_lock.visible = show_lock


func _get_tokens() -> DesignTokens:
	if _tokens == null:
		_tokens = DesignTokens.load_default()
	return _tokens


func _get_icon(category: String) -> Texture2D:
	return category_icons.get(category, null)


## Squash-pop the whole note and float the back icon in. No-op in the editor.
func play_assign_pop() -> void:
	if Engine.is_editor_hint():
		return
	if not is_inside_tree():
		return
	pivot_offset = size / 2.0
	var t := _get_tokens()
	var pop := create_tween()
	pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(self, "scale", Vector2(1.12, 0.86), t.dur_fast * 0.6)
	pop.tween_property(self, "scale", Vector2(0.94, 1.06), t.dur_fast * 0.7)
	pop.tween_property(self, "scale", Vector2.ONE, t.dur_fast)
	if _back_icon:
		var rest := _back_icon.position
		_back_icon.position = rest + Vector2(10, -12)
		_back_icon.modulate.a = 0.0
		var reveal := create_tween().set_parallel(true)
		reveal.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reveal.tween_property(_back_icon, "position", rest, t.dur_normal)
		reveal.tween_property(_back_icon, "modulate:a", 1.0, t.dur_normal)
```

- [ ] **Step 4: Build `DayStickyNote.tscn` via the editor MCP**

`filesystem_manage(op="scan")` first so the script's `class_name` registers. Then, through the editor (never hand-write the `.tscn`):

1. `scene_manage` / `scene_open` — create a new scene, root node type `Control` named `DayStickyNote`, attach `res://Scripts/AturJadwal/DayStickyNote.gd`.
2. Root props: `custom_minimum_size = Vector2(271, 267)`, `mouse_filter = 1` (pass). Set `category_icons` to:
   - `"Akademis"` → `res://Assets/Images/StudentCard/stat_akademis.png`
   - `"SeniBudaya"` → `res://Assets/Images/StudentCard/stat_senibudaya.png`
   - `"Olahraga"` → `res://Assets/Images/StudentCard/stat_olahraga.png`
   - `"Wirausaha"` → `res://Assets/Images/AturJadwal/icon_wirausaha_placeholder.png`
   - `"Istirahat"` → `res://Assets/Images/AturJadwal/icon_istirahat_placeholder.png`
   Set `holiday_icon` → `res://Assets/Images/AturJadwal/icon_libur_nasional_placeholder.png`.
   (Dictionary values must be `Texture2D` resources — load each via the inspector / `set_property` with a resource ref, not a string.)
3. Child `Shadow` (`TextureRect`): `texture = res://Assets/Images/UI/stickynotes.png`, `expand_mode = 1`, `mouse_filter = 2`, anchors full-rect, `offset_left = 14`, `offset_top = 18`, `offset_right = 14`, `offset_bottom = 18`, `scale = Vector2(1.03, 1.03)`, `self_modulate = Color(0, 0, 0, 0.33)`. Create a new `ShaderMaterial` with `shader = res://Scripts/Shaders/soft_shadow.gdshader`, leave `blur` at its default. (`Color(0,0,0,0.33)` here is a scene value, not a script literal — allowed; the no-`Color()` rule is about the `.gd`.)
4. Child `BackIcon` (`TextureRect`): `expand_mode = 1`, `stretch_mode = 5`, `mouse_filter = 2`, `offset_left = 150`, `offset_top = -70`, `offset_right = 325`, `offset_bottom = 105` (≈175×175, top-right peek), `visible = false`.
5. Child `Paper` (`TextureButton`): `texture_normal = res://Assets/Images/UI/stickynotes.png`, `ignore_texture_size = true`, `stretch_mode = 0`, anchors full-rect (all four = 0/0/1/1), offsets 0.
6. Under `Paper`:
   - `DayLabel` (`Label`): `theme_type_variation = &"H2Label"`, `modulate = Color(0,0,0,1)`, `text = "SENIN"`, offsets ≈ `left 40, top 24, right 240, bottom 92`.
   - `SubjectLabel` (`Label`): `theme_type_variation = &"CaptionLabel"`, `modulate = Color(0,0,0,1)`, `text = ""`, `visible = false`, offsets ≈ `left 40, top 104, right 260, bottom 150`, `autowrap_mode = 2`.
   - `FlavorLabel` (`Label`): `theme_type_variation = &"MicroLabel"`, `modulate = Color(0,0,0,1)`, `text = ""`, `visible = false`, offsets ≈ `left 40, top 156, right 260, bottom 196`.
   - `Lock` (`Label`): `theme_type_variation = &"MicroLabel"`, `text = "🔒"`, `visible = false`, offsets ≈ `left 20, top 16, right 60, bottom 56`.
7. `move_node` so child order under the root is `Shadow` (0), `BackIcon` (1), `Paper` (2).
8. `scene_save` to `res://Scenes/AturJadwal/DayStickyNote.tscn`. Then `filesystem_manage(op="scan")`.

- [ ] **Step 5: Run the test to confirm it passes**

Run: `test_run` filtered to `day_sticky_note`.
Expected: PASS (all tests). If `test_touch_target_is_big_enough` fails, the root `custom_minimum_size` did not save — re-set it and re-save. If `test_icon_exports_are_populated_from_the_tscn_root` fails, the dictionary values were saved as strings, not `Texture2D` — re-assign them as resource references.

- [ ] **Step 6: Run the full suite for regressions**

Run: `test_run` (all suites). Expected: all green — `viewport_editability` unchanged (`DayStickyNote.gd` calls no `*.new()`), `script_documentation` covers the new script.

- [ ] **Step 7: Commit**

```bash
git add Scripts/AturJadwal/DayStickyNote.gd Scenes/AturJadwal/DayStickyNote.tscn tests/test_day_sticky_note.gd
git commit -m "feat(atur-jadwal): add the DayStickyNote template (paper, peeking icon, shadow, pop)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 4: Swap the five `BGHari` buttons for `DayStickyNote` instances

**Files:**
- Modify: `Scenes/AturJadwal/atur_jadwal.tscn` (via editor MCP)
- Modify: `tests/test_atur_jadwal.gd`

**Interfaces:**
- Consumes: `DayStickyNote.tscn` (Task 3).
- Produces: `atur_jadwal.tscn`'s `BGHari` now has five `DayStickyNote` instances named `Senin` / `Selasa` / `Rabu` / `Kamis` / `Jumat`, each keeping the exact screen offsets below. Consumed by Task 5.

Current per-instance offsets to preserve (from `atur_jadwal.tscn`, all under `BGHari`, `layout_mode = 0`):

| Node | offset_left | offset_top | offset_right | offset_bottom |
|---|---|---|---|---|
| Senin | 71.0 | 998.0 | 342.41193 | 1265.0 |
| Selasa | 415.0 | 1112.0 | 686.4119 | 1379.0 |
| Rabu | 744.0 | 998.0 | 1015.41187 | 1265.0 |
| Kamis | 227.0 | 1381.0 | 498.41193 | 1648.0 |
| Jumat | 574.0 | 1386.0 | 845.41187 | 1653.0 |

- [ ] **Step 1: Update the two structural tests first (they will fail until Step 2)**

In `tests/test_atur_jadwal.gd`:

Replace `test_day_buttons_are_tinted_via_category_color` with:

```gdscript
## The day-note tint now lives in the DayStickyNote template, not this
## screen's script. The screen just calls show_empty/show_scheduled/
## show_holiday; the template maps category -> DesignTokens.category_color().
func test_day_notes_are_daystickynote_instances_tinted_via_category_color() -> void:
    for day in ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]:
        var note := _screen.get_node_or_null("BGHari/" + day)
        assert_true(note is DayStickyNote, day + " must be a DayStickyNote instance")
    var tmpl := FileAccess.get_file_as_string("res://Scripts/AturJadwal/DayStickyNote.gd")
    assert_true(tmpl.contains("category_color"),
        "the template must tint via DesignTokens.category_color()")
```

Replace `test_the_whiteboard_and_sticky_notes_are_unchanged` with:

```gdscript
## The whiteboard art itself is still out of scope for the restyle and must
## survive untouched. The five sticky notes were polished on 2026-09-01
## (docs/superpowers/plans/2026-09-01-atur-jadwal-sticky-note-polish.md):
## each is now a DayStickyNote whose Paper still draws stickynotes.png.
func test_the_whiteboard_is_unchanged_and_notes_are_stickynotes() -> void:
    var board := _screen.get_node_or_null("BGHari") as TextureRect
    assert_true(board != null, "BGHari is gone")
    assert_eq(board.texture.resource_path, "res://Assets/Images/UI/whiteboard.png",
        "the whiteboard texture changed")
    for day in ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]:
        var note := _screen.get_node_or_null("BGHari/%s" % day) as DayStickyNote
        assert_true(note != null, "sticky note %s is gone or was reparented" % day)
        var paper := note.get_node_or_null("Paper") as TextureButton
        assert_true(paper != null and paper.texture_normal != null
            and paper.texture_normal.resource_path == "res://Assets/Images/UI/stickynotes.png",
            "%s Paper must still draw stickynotes.png" % day)
```

Leave `test_interactive_controls_meet_the_minimum_touch_target`, `test_scene_instantiates`, `test_top_band_matches_the_mockup`, and the z-order assertions as-is — they only require `BGHari/<day>` to exist and be a `Control`, which a `DayStickyNote` is.

- [ ] **Step 2: Replace the nodes via the editor MCP**

1. `scene_open` `res://Scenes/AturJadwal/atur_jadwal.tscn`.
2. For each of `Senin`, `Selasa`, `Rabu`, `Kamis`, `Jumat`: `delete_node` `BGHari/<day>` (removes the old `TextureButton` and its `Label` child).
3. For each day: instance `res://Scenes/AturJadwal/DayStickyNote.tscn` as a child of `BGHari`, name it `<day>`, set `layout_mode = 0` and the four offsets from the table above. (Use `batch_execute` per day where possible.)
4. Confirm child order under `BGHari` is Senin, Selasa, Rabu, Kamis, Jumat (order is cosmetic here, but keep it stable).
5. `scene_save`. Then `filesystem_manage(op="scan")`.

- [ ] **Step 3: Run the atur_jadwal suite**

Run: `test_run` filtered to `atur_jadwal`. Open `Scenes/MainMenu/main_menu.tscn` if a `scene_warning` says a suite needs the main scene open, then re-run.
Expected: PASS — including the two rewritten tests and `test_interactive_controls_meet_the_minimum_touch_target` (instances carry ~271×267 rects).

- [ ] **Step 4: Run the full suite**

Run: `test_run` (all). Expected: all green. `test_project_hygiene` needs every `ext_resource` UID in `atur_jadwal.tscn` to resolve — the new `DayStickyNote.tscn` / icon / shader imports must have been scanned (Step 2.5).

- [ ] **Step 5: Commit**

```bash
git add Scenes/AturJadwal/atur_jadwal.tscn tests/test_atur_jadwal.gd
git commit -m "feat(atur-jadwal): replace the five day buttons with DayStickyNote instances

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 5: Rewire `atur_jadwal.gd` to the template API

**Files:**
- Modify: `Scripts/AturJadwal/atur_jadwal.gd` — `_update_day_button_colors()` (around lines 480–516)

**Interfaces:**
- Consumes: `DayStickyNote` (`set_day_name`, `show_empty`, `show_scheduled`, `show_holiday`).
- Produces: nothing new — the `GameState.day_schedules` contract is untouched.

- [ ] **Step 1: Add a failing behavioural test**

Append to `tests/test_atur_jadwal.gd`:

```gdscript
## _update_day_button_colors() must route each day to the DayStickyNote
## template, never poke a child Label directly (the old bare-button code did
## `btn.get_child(0) as Label`).
func test_update_day_colors_uses_the_template_api() -> void:
    var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
    assert_false(src.contains("get_child(0) as Label"),
        "the old per-button Label poke must be gone")
    assert_true(src.contains("show_scheduled("), "must call DayStickyNote.show_scheduled()")
    assert_true(src.contains("show_holiday("), "must call DayStickyNote.show_holiday()")
    assert_true(src.contains("show_empty("), "must call DayStickyNote.show_empty()")
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `test_run` filtered to `atur_jadwal`.
Expected: FAIL on `test_update_day_colors_uses_the_template_api`.

- [ ] **Step 3: Rewrite `_update_day_button_colors()`**

Replace the body of the `for day_name in day_buttons.keys():` loop (currently the `var label = btn.get_child(0) as Label` block through the `else:` branch) with:

```gdscript
	for day_name in day_buttons.keys():
		var btn = day_buttons[day_name]
		var note := btn as DayStickyNote
		if note == null:
			continue

		note.set_day_name(day_name)

		if week_holidays.has(day_name):
			note.show_holiday(week_holidays[day_name].get("title", "Libur Nasional"))
		elif schedules.has(day_name):
			note.show_scheduled(schedules[day_name]["category"])
		else:
			note.show_empty()
```

Leave the function's header comment, the `tokens` / `default_color` locals it no longer needs can be removed, and the `week` / `week_holidays` lookups above the loop stay. Do not touch `_start_day_button_sway()`, `_animate_day_button_press()`, `_connect_day_button()`, `_get_day_button()`, or any tutorial code — they all still operate on the `Control` root and the re-emitted `pressed` signal.

- [ ] **Step 4: Rescan and run the atur_jadwal suite**

`filesystem_manage(op="scan")`, then `test_run` filtered to `atur_jadwal`.
Expected: PASS — the new test plus every existing one. `test_no_hardcoded_colors_remain_in_the_script` still passes (no `Color(` added). `test_day_notes_are_daystickynote_instances_tinted_via_category_color` still passes.

- [ ] **Step 5: Run the full suite**

Run: `test_run` (all). Expected: all green, `viewport_editability` still reports `atur_jadwal.gd` at 17 (nothing added, and the removed code held no `*.new()`).

- [ ] **Step 6: Visual check in the running editor**

Use the debug overlay: **⚡ Seed Playtest State**, then teleport to **AturJadwal**. Because the seed does not fill `day_schedules`:

1. Screenshot the fresh screen — five grey notes, day names only, soft shadow visible, gentle sway.
2. Tap a day → pick **Atletik** in the Penjadwalan popup. Screenshot: that note is now green, reads `KAMIS` / `Atletik` / `Semangat`, the olahraga icon peeks from the top-right, and it played a squash-pop.
3. Tap the same day → pick **Libur**. Screenshot: purple note, `Libur` / `Santai`, istirahat placeholder icon.
4. Open the debug overlay's week editor, set the week to **3**, re-enter AturJadwal. Screenshot the **Rabu** note: gold paper, `RABU` / `Kemerdekaan RI` / `Libur Nasional`, padlock glyph, flag placeholder icon — and it is not tappable to reschedule (the holiday warning still fires).

Note in the commit message anything that needed hand-nudging (label offsets, icon peek amount).

- [ ] **Step 7: Commit**

```bash
git add Scripts/AturJadwal/atur_jadwal.gd tests/test_atur_jadwal.gd
git commit -m "feat(atur-jadwal): drive the day notes through the DayStickyNote template

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 6: Documentation

**Files:**
- Modify: `docs/superpowers/specs/2026-09-01-atur-jadwal-mockup.md`

**Interfaces:** none.

- [ ] **Step 1: Append a STATUS note to the AturJadwal mockup spec**

Add, near that file's existing STATUS block:

```markdown
### 2026-09-01 — Sticky-note polish

The five day sticky notes were reworked into a reusable
`Scenes/AturJadwal/DayStickyNote.tscn` template (`DayStickyNote.gd`).
Plan: `docs/superpowers/plans/2026-09-01-atur-jadwal-sticky-note-polish.md`.

- Each scheduled note now shows three lines — day / pembelajaran name
  (`Akademik` / `Seni Budaya` / `Atletik` / `Wirausaha` / `Libur`) / a
  one-word flavour label (`Fokus` / `Berkarya` / `Semangat` / `Cuan` /
  `Santai`) — plus a category icon peeking from the top-right corner and a
  soft drop shadow (`Scripts/Shaders/soft_shadow.gdshader`).
- Assigning a day plays a squash-pop with the icon sliding in; the idle
  sway is unchanged.
- National-holiday days (e.g. Week 3 Rabu) render locked gold with the real
  holiday title, a `Libur Nasional` flavour line, and a padlock glyph.
- **Deferred art:** `icon_wirausaha_placeholder.png`,
  `icon_istirahat_placeholder.png` and `icon_libur_nasional_placeholder.png`
  in `Assets/Images/AturJadwal/` are flat geometric placeholders emitted by
  `Scripts/Design/GenerateStickyNoteIcons.gd` (File > Run). The visual team
  overrides them in place — keep the file names. The three skill categories
  already use the real `stat_*.png`.
- No ThemeFactory variation was added, so no theme rebake was needed.
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/specs/2026-09-01-atur-jadwal-mockup.md
git commit -m "docs(atur-jadwal): record the sticky-note polish in the mockup spec

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage** (§ Design decisions → task):

1. Three-line note text → Task 3 (`show_scheduled` sets `DayLabel` / `SubjectLabel` / `FlavorLabel`), asserted in `test_day_sticky_note.gd`.
2. Flavour words → `FLAVOR_WORDS` const in Task 3, coverage asserted.
3. Subject display names → `DISPLAY_NAMES` const in Task 3, asserted equal to the ActivityRow wording.
4. Icon peeks top-right → Task 3 scene step 4 (`BackIcon` offsets), z-order asserted behind `Paper`.
5. Placeholder icon art for Wirausaha / Istirahat / holiday → Task 1 generator + PNGs; skill categories reuse `stat_*.png` (Task 3 step 4.2).
6. Soft offset shadow following the paper shape → Task 2 shader + Task 3 `Shadow` node.
7. Locked-gold national-holiday note with title, `Libur Nasional`, padlock, flag icon → Task 3 `show_holiday()`, asserted; wired in Task 5 (`week_holidays[day_name]["title"]`).
8. Pop only on newly-scheduled / category-changed → Task 3 `_state` / `_category` guard + `play_assign_pop()`; idle sway left untouched in Task 5.
9. One reusable template + five instances → Task 3 (template) + Task 4 (instances).
- Holiday schedule still locked to Istirahat by `_check_and_lock_holidays()` → untouched; Task 5 keeps the holiday branch first.
- Tutorial node lookups (`BGHari/Senin`, "BGHari") → still `Control`s; Task 5 explicitly leaves tutorial code alone; `test_atur_jadwal.gd` structural tests keep `BGHari/<day>` existence checks.
- Ratchet (`test_viewport_editability`) → `DayStickyNote.gd` uses no `*.new()`; `atur_jadwal.gd` count unchanged. Verified in Task 3 step 6 and Task 5 step 5.
- `test_script_documentation` → both new scripts carry a `##` header and a `##` line per `@export` (Task 1, Task 3).

**Placeholder scan:** no "TBD"/"handle edge cases"/"similar to Task N" — every code step carries full source. Label/icon offsets are given as concrete numbers marked "≈" where the executor should eyeball-tune in Task 5 step 6.

**Type consistency:** `show_empty()` / `show_scheduled(category)` / `show_holiday(title)` / `set_day_name(day_name)` / `play_assign_pop()` / `pressed` used identically in Tasks 3, 4, 5, and both test files. `category_icons` / `holiday_icon` export names match between script, scene wiring, and `test_day_sticky_note.gd`. Icon paths identical in Task 1's Produces, Task 3 step 4.2, and `test_sticky_note_assets.gd`. Shader uniform `blur` matches between Task 2's shader and its test.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-09-01-atur-jadwal-sticky-note-polish.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Note: subagents cannot drive the Godot editor (the MCP bridge is single-client), so for the editor-bound steps (Task 1 step 4, Task 3 step 4, Task 4 step 2, and every `test_run`) the subagent writes the code/instructions and I run the editor.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints for review.

**Which approach?**
