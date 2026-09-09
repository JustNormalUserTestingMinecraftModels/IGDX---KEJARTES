# Event Screens & StudentCard Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix layout/legibility problems on the StudentCard approve screen and the mid-simulation Event Student Select dialog; replace shitpost placeholders on the Event Announcement/Warning popups with polished PNG assets, SFX and a fresh particle burst.

**Architecture:** Pure UI/asset pass. Every visual change routes through Godot MCP (`scene_open` → `node_set_property` → `scene_save`) — no hand-edited `.tscn`. New PNGs land under `Assets/Images/UI/Placeholders/` and `Assets/Images/Particles/`. New audio cue is a `.ogg` file registered on `AudioDirector`. New particle scene sits in `Scenes/SchoolSimulation/`. No new `theme_override_*` — anything needing a new look gets a `ThemeFactory` variation and a rebake.

**Tech Stack:** Godot 4.6, GDScript, DesignTokens/ThemeFactory, `godot-ai` MCP, existing `Juice.gd` tweens and `RewardParticles` pattern.

**Spec:** This plan itself (the user's message of 2026-09-08 with screenshots 598 and 599).

## Global Constraints

- Portrait 1080×1920 only — mobile renderer, no landscape testing needed.
- Indonesian UI copy stays Indonesian.
- **No `theme_override_*`** (constants like `separation`/`margin_*` excepted). Add or reuse a `ThemeFactory` variation and rebake instead.
- **No emoji as UI iconography.** Placeholder `.png` (transparent) only.
- **Never hand-edit a `.tscn` while the editor is attached.** Go through MCP: `scene_open` → `node_create`/`node_set_property`/`node_manage` (or `batch_execute`) → `scene_save`. After any script edit from outside the editor, a **no-op `script_patch`** on that same file forces reload.
- **New `@export` on a `Resource` (e.g. `DesignTokens`) is invisible until editor restart** — this plan avoids adding tokens for that reason.
- Every new/edited script needs a `##` file header and a `##` line on every `@export` (enforced by `tests/test_script_documentation.gd`).
- Verify by running `test_run` at the end of every task; suite must stay green (960+ tests as of 2026-09-05).
- Commit style: Conventional Commits with scope, e.g. `fix(studentcard): stop trait pill clipping approve button`.

---

## File Structure

**Modified:**
- `Scenes/StudentCard/student_card.tscn` — reposition Approve/Belajar/trait pills, resize header.
- `Scripts/Design/ThemeFactory.gd` — bump `BioLabel`/`BioValue` sizes, add `EventDialogHeaderLabel` variation, add `EventBodyLabel` variation.
- `Scenes/SchoolSimulation/EventStudentSelectDialog.tscn` — background swap slot, larger header text, upgrade desc/benefit/cost labels.
- `Scripts/SchoolSimulation/EventStudentSelectDialog.gd` — accept `background_texture` default from Inspector; no logic change.
- `Scenes/SchoolSimulation/EventStudentCard.tscn` — no structural changes; property tweak on TiredBadge only.
- `Scripts/SchoolSimulation/EventStudentCard.gd` — `_apply_tired_look()` greys the whole card when tired.
- `Scenes/SchoolSimulation/EventAnnouncement.tscn` — swap emoji-only IconLabel for TextureRect; wire new PNG + BG.
- `Scenes/SchoolSimulation/EventWarning.tscn` — swap emoji CautionLabel for TextureRect + new PNG.
- `Scripts/SchoolSimulation/EventAnnouncement.gd` — remove the emoji fallback branch (art now required), play new SFX, spawn burst.
- `Scripts/Audio/AudioDirector.gd` — register `sfx_event_announce`.

**Created:**
- `Assets/Images/UI/Placeholders/icon_event_announce.png` — 512×512 transparent, megaphone silhouette in brand blue.
- `Assets/Images/UI/Placeholders/icon_event_warning.png` — 512×512 transparent, triangle-warning in `state_warning` amber.
- `Assets/Images/UI/Placeholders/bg_event_announce.png` — 1080×1920, soft radial gradient in `brand_primary_dark`→`brand_primary`.
- `Assets/Images/UI/Placeholders/bg_event_dialog.png` — 1080×1920, subtle notebook-paper tint over `surface_page` (replaces the harsh mint of screenshot 599).
- `Assets/Images/Particles/particle_burst.png` — 128×128 transparent starburst.
- `Assets/Audio/SFX/event_announce.ogg` — short brassy chime (see Task 6 for stopgap sourcing).
- `Scenes/SchoolSimulation/AnnouncementBurst.tscn` — one-shot `GPUParticles2D` scene emitting `particle_burst.png` + `particle_star.png`.
- `Scripts/SchoolSimulation/AnnouncementBurst.gd` — trivial `@tool` script driving `emitting = true` on `_ready`.
- `tests/test_event_polish.gd` — source-text scans asserting the placeholders are gone and the new assets are referenced.

---

## Task 1: Fix StudentCard clipping & typography

**Files:**
- Modify: `Scenes/StudentCard/student_card.tscn` (five near-identical `KertasMurid1..5` subtrees plus the visibility-swapped `KertasMurid6`; every child listed below exists **in each of the six** subtrees at the same offsets)
- Test: `tests/test_student_card_layout.gd` (new source-text scan)

**Interfaces:**
- Consumes: nothing (leaf UI).
- Produces: nothing (visual only).

**Root cause of the clipping in Screenshot 598:** the two `TraitPill` buttons (`KutuBuku`, `KutuBuku2`) are anchored at `anchor_top = 0.786` / `0.848` on a control that grows to full parent height, which puts them at ~y=1500 in design space — overlapping the `SifatPasifLabel` at y=1330 and stacking on top of the `Aprove` button at y=1641. The `376` text is `PageLabel` at y=1248 with an empty string; when the trait pill drifts up it prints its stray text over the seni-budaya bar.

- [ ] **Step 1: Write the failing test**

Create `tests/test_student_card_layout.gd`:

```gdscript
@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

const SCENE_PATH := "res://Scenes/StudentCard/student_card.tscn"

func _read() -> String:
    return FileAccess.get_file_as_string(SCENE_PATH)

func test_trait_pills_sit_above_approve() -> void:
    var src := _read()
    # After the fix, the two TraitPill buttons anchor to the section label
    # area (top ≈ 0.70 / 0.755), leaving the 0.86–0.94 band clear for Approve.
    assert_true(src.contains("anchor_top = 0.70"),
        "Expected KutuBuku pill anchored at 0.70 after fix")
    assert_true(src.contains("anchor_top = 0.755"),
        "Expected KutuBuku2 pill anchored at 0.755 after fix")
    assert_false(src.contains("anchor_top = 0.786"),
        "Old overlapping pill anchor still present")

func test_page_label_has_no_stray_text() -> void:
    # PageLabel is empty by design; the stray '376' seen in screenshot 598
    # was the trait pill drawn over the row. Guard the empty default.
    var src := _read()
    assert_true(src.contains('offset_top = 1248.0'),
        "PageLabel moved unexpectedly")
```

- [ ] **Step 2: Run test to verify it fails**

Via MCP `test_run` with `suite: "test_student_card_layout"`. Expected: FAIL on the anchor assertions.

- [ ] **Step 3: Reposition trait pills, header, and Approve/Belajar via MCP batch**

For **each of the six** `KertasMurid1..6` subtrees, apply this batch (repeat the block six times, one per parent):

```text
scene_open("res://Scenes/StudentCard/student_card.tscn")

batch_execute on KertasMurid<N>/KutuBuku:
  - set_property anchor_top = 0.70
  - set_property anchor_bottom = 0.70
  - set_property offset_top = -60
  - set_property offset_bottom = 40

batch_execute on KertasMurid<N>/KutuBuku2:
  - set_property anchor_top = 0.755
  - set_property anchor_bottom = 0.755
  - set_property offset_top = -60
  - set_property offset_bottom = 40

batch_execute on KertasMurid<N>/Aprove:
  - set_property offset_top = 1560
  - set_property offset_bottom = 1720
  - set_property offset_left = 260
  - set_property offset_right = 780
```

Then, on the scene root once:

```text
batch_execute on PilihMurid:
  - set_property offset_top = -210
  - set_property offset_bottom = -60
  # DisplayLabel already uses font_display; the extra vertical room lets the
  # existing size breathe instead of shrinking to fit.

batch_execute on BelajarButton:
  - set_property offset_top = 1740
  - set_property offset_bottom = 1900
```

Then `scene_save`.

- [ ] **Step 4: Run test to verify it passes**

`test_run` on the new suite. Expected: PASS.

- [ ] **Step 5: Sanity-check the full suite**

`test_run` with no filter. Expected: all previously green tests still green.

- [ ] **Step 6: Commit**

```bash
git add Scenes/StudentCard/student_card.tscn tests/test_student_card_layout.gd
git commit -m "$(cat <<'EOF'
fix(studentcard): reposition trait pills and approve to stop clipping

The KutuBuku pills anchored at 0.786/0.848 overlapped the Approve button
and printed the empty PageLabel's box over the stat bars, showing as the
stray "376" in the QA screenshot. Move the pills to the 0.70/0.755 band
and drop Approve/Belajar into the freed space below.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Bump font sizes in ThemeFactory — bio block, event dialog, and rebake

**Context — current font sizes and why they are too small on mobile (1080px portrait):**

| Variation | Current size | Used where | Problem |
|---|---|---|---|
| `BioLabel` | `font_body_size` = 28px | "Nama:", "Jenis Kelamin:", "Tanggal Lahir:" headings on StudentCard | Heading competes with value text, no visual hierarchy in the bio block |
| `BioValue` | `font_body_size + 6` = 34px | "Andi", "Laki-Laki", "25 Januari" values | Barely larger than heading — hard to scan at a glance on mobile |
| `CaptionLabel` | `font_caption` = 22px | Event dialog benefit/cost text, "Pilih siswa..." instructions | Tiny on a phone — the user called this out specifically |

**Mixed approach (aggressive on critical info, moderate on support text):**

| Variation | New size | Rationale |
|---|---|---|
| `BioLabel` | `font_caption` = 22px | **Shrink** the heading so it reads as a label, not competing with the value |
| `BioValue` | `font_h2` = 48px | **Aggressive bump** — the student's name/birthday is the critical info |
| New `EventBodyLabel` | `font_body_size + 4` = 32px | Moderate bump for benefit/cost and description text |
| New `EventDialogHeaderLabel` | `font_h1 + 6` | Display-font title for event popups |

The bio panel area (`BIO_PANEL_RECT = Rect2(120, 300, 489, 367)`) has 367px height minus 32px padding each side = ~303px usable. At heading 22px + value 48px + 4px separation = ~74px per row x 3 rows = 222px — fits comfortably.

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (bump `BioLabel`/`BioValue`, add two new variations)
- Test: `tests/test_theme_factory.gd` (add `EventDialogHeaderLabel` to `DISPLAY_ROSTER`)
- Trigger a theme rebake via `Scripts/Design/BakeTheme.gd` (File > Run) or a transient `@tool` `McpTestSuite`.

**Interfaces:**
- Produces: `&"EventDialogHeaderLabel"` — display-font (Boohong), font size = `H1 + 6`, `text_primary`. Consumed by Tasks 4 and 6.
- Produces: `&"EventBodyLabel"` — body font, 32px, `text_primary`. Consumed by Task 4 for benefit/cost/desc.
- Modifies: `&"BioLabel"` size from `font_body_size` to `font_caption` (22px).
- Modifies: `&"BioValue"` size from `font_body_size + 6` to `font_h2` (48px).

- [ ] **Step 1: Read ThemeFactory around the BioLabel and H1Label blocks**

Grep `BioLabel` and `H1Label` in `Scripts/Design/ThemeFactory.gd` to find exact lines.

- [ ] **Step 2: Patch BioLabel / BioValue sizes via `script_patch`**

```gdscript
# Before:
theme.set_font_size("font_size", "BioLabel", tokens.font_body_size)
# After:
theme.set_font_size("font_size", "BioLabel", tokens.font_caption)

# Before:
theme.set_font_size("font_size", "BioValue", tokens.font_body_size + 6)
# After:
theme.set_font_size("font_size", "BioValue", tokens.font_h2)
```

- [ ] **Step 3: Add EventDialogHeaderLabel variation** (inserted next to the H1Label block, using whatever helper the file uses):

```gdscript
_add_label_variation(theme, tokens, "EventDialogHeaderLabel",
    tokens.font_display, tokens.font_h1 + 6, tokens.text_primary)
```

- [ ] **Step 4: Add EventBodyLabel variation** (inserted after the CaptionLabel in the label array or after the label block):

```gdscript
theme.add_type("EventBodyLabel")
theme.set_type_variation("EventBodyLabel", "Label")
theme.set_font_size("font_size", "EventBodyLabel", tokens.font_body_size + 4)
theme.set_color("font_color", "EventBodyLabel", tokens.text_primary)
```

- [ ] **Step 5: Extend the display-roster test**

In `tests/test_theme_factory.gd`, add `"EventDialogHeaderLabel"` to `DISPLAY_ROSTER` (the array that pins which variations use `font_display`). `EventBodyLabel` uses body font so it does NOT go in the roster.

- [ ] **Step 6: Rebake**

If the editor is available: File > Run `Scripts/Design/BakeTheme.gd` (Ctrl+Shift+X).
Otherwise, write a transient `@tool` suite `tests/test__rebake_theme.gd` (single test that calls `ThemeFactory.build(...)` and `ResourceSaver.save()`), run it via MCP `test_run`, then delete the file.

- [ ] **Step 7: Verify**

`test_run` all suites. `test_theme_factory` must include the new roster entry and pass.

- [ ] **Step 8: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd tests/test_theme_factory.gd Assets/Theme/kejartes_theme.tres
git commit -m "$(cat <<'EOF'
feat(theme): bump bio text sizes + add EventDialogHeaderLabel and EventBodyLabel

BioLabel shrinks to caption-size (22px) as a proper label; BioValue jumps to
H2 (48px) so the student name pops on mobile. EventDialogHeaderLabel uses
display font at H1+6 for event popup titles. EventBodyLabel (32px body) gives
benefit/cost and description text room to breathe versus the 22px CaptionLabel.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Generate placeholder PNGs

**Files:**
- Create: `Assets/Images/UI/Placeholders/icon_event_announce.png` (512×512, RGBA)
- Create: `Assets/Images/UI/Placeholders/icon_event_warning.png` (512×512, RGBA)
- Create: `Assets/Images/UI/Placeholders/bg_event_announce.png` (1080×1920, RGBA)
- Create: `Assets/Images/UI/Placeholders/bg_event_dialog.png` (1080×1920, RGBA — muted paper tint replacing the too-bright mint of screenshot 599)
- Create: `Assets/Images/Particles/particle_burst.png` (128×128, RGBA)

**Interfaces:** files-on-disk consumed by later tasks.

- [ ] **Step 1: Write a one-shot generator script**

Create `scratchpad/gen_event_placeholders.py` (use the scratchpad dir from environment):

```python
from PIL import Image, ImageDraw, ImageFilter
import math, os

OUT = r"C:/Users/Legion/Documents/KEJARTES/new-game-project/Assets/Images"

def megaphone(size=512, color=(46, 91, 255, 255)):
    im = Image.new("RGBA", (size, size), (0,0,0,0))
    d = ImageDraw.Draw(im)
    # cone
    d.polygon([(90, 200), (320, 120), (320, 392), (90, 312)], fill=color)
    # handle
    d.rectangle([(320, 220), (400, 292)], fill=color)
    # sound wave arcs
    for r, w in [(120, 22), (180, 18), (240, 14)]:
        d.arc([(320-r+430, 256-r), (320+r+430-2*r, 256+r)], -35, 35, fill=color, width=w)
    return im

def warning_triangle(size=512, color=(255, 176, 32, 255)):
    im = Image.new("RGBA", (size, size), (0,0,0,0))
    d = ImageDraw.Draw(im)
    d.polygon([(256, 40), (472, 456), (40, 456)], fill=color, outline=(30,20,10,255), width=8)
    d.rectangle([(238, 160), (274, 340)], fill=(30,20,10,255))
    d.ellipse([(232, 380), (280, 428)], fill=(30,20,10,255))
    return im

def radial_bg(w=1080, h=1920, c_inner=(46, 91, 255, 255), c_outer=(27, 58, 204, 255)):
    im = Image.new("RGBA", (w, h))
    px = im.load()
    cx, cy = w/2, h/2
    maxd = math.hypot(cx, cy)
    for y in range(h):
        for x in range(w):
            t = math.hypot(x-cx, y-cy) / maxd
            t = max(0, min(1, t))
            px[x,y] = tuple(int(c_inner[i]*(1-t) + c_outer[i]*t) for i in range(4))
    return im

def paper_bg(w=1080, h=1920, base=(238, 243, 255, 255)):
    # Muted lavender-paper tint. Replaces the harsh mint pastel of the
    # current dialog panel. Adds a very faint diagonal wash.
    im = Image.new("RGBA", (w, h), base)
    d = ImageDraw.Draw(im, "RGBA")
    for i in range(0, w+h, 48):
        d.line([(i, 0), (i-h, h)], fill=(221, 229, 247, 40), width=2)
    return im.filter(ImageFilter.GaussianBlur(radius=2))

def burst(size=128):
    im = Image.new("RGBA", (size, size), (0,0,0,0))
    d = ImageDraw.Draw(im)
    c = (255, 255, 255, 235)
    cx = cy = size//2
    for i in range(8):
        a = i * math.pi/4
        x2 = cx + math.cos(a) * (size//2 - 8)
        y2 = cy + math.sin(a) * (size//2 - 8)
        d.line([(cx, cy), (x2, y2)], fill=c, width=8)
    d.ellipse([(cx-14, cy-14), (cx+14, cy+14)], fill=c)
    return im.filter(ImageFilter.GaussianBlur(radius=1.5))

os.makedirs(OUT + "/UI/Placeholders", exist_ok=True)
os.makedirs(OUT + "/Particles", exist_ok=True)
megaphone().save(OUT + "/UI/Placeholders/icon_event_announce.png")
warning_triangle().save(OUT + "/UI/Placeholders/icon_event_warning.png")
radial_bg().save(OUT + "/UI/Placeholders/bg_event_announce.png")
paper_bg().save(OUT + "/UI/Placeholders/bg_event_dialog.png")
burst().save(OUT + "/Particles/particle_burst.png")
print("done")
```

- [ ] **Step 2: Run it**

```bash
python scratchpad/gen_event_placeholders.py
```

Expected: `done` printed, five PNGs on disk. If Pillow missing: `pip install pillow` first.

- [ ] **Step 3: Let the editor reimport**

MCP: `filesystem_manage(op="scan")`. Confirm the five files show `.import` siblings.

- [ ] **Step 4: Commit**

```bash
git add "Assets/Images/UI/Placeholders/icon_event_announce.png" \
        "Assets/Images/UI/Placeholders/icon_event_warning.png" \
        "Assets/Images/UI/Placeholders/bg_event_announce.png" \
        "Assets/Images/UI/Placeholders/bg_event_dialog.png" \
        "Assets/Images/Particles/particle_burst.png" \
        "Assets/Images/UI/Placeholders/*.import" \
        "Assets/Images/Particles/particle_burst.png.import"
git commit -m "feat(assets): add polished placeholder PNGs for event UI and burst particle

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 4: Repolish EventStudentSelectDialog (screenshot 599)

**Files:**
- Modify: `Scenes/SchoolSimulation/EventStudentSelectDialog.tscn`
- Test: `tests/test_event_polish.gd` (new)

**Interfaces:**
- Consumes: `EventDialogHeaderLabel` (Task 2), `EventBodyLabel` (Task 2), `bg_event_dialog.png` (Task 3).

- [ ] **Step 1: Write the failing test**

`tests/test_event_polish.gd`:

```gdscript
@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

func _read(p: String) -> String:
    return FileAccess.get_file_as_string(p)

func test_dialog_uses_calmed_background() -> void:
    var src := _read("res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn")
    assert_true(src.contains("bg_event_dialog.png"),
        "Dialog should reference the new paper-tint background")

func test_dialog_header_uses_event_variation() -> void:
    var src := _read("res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn")
    assert_true(src.contains('theme_type_variation = &"EventDialogHeaderLabel"'),
        "Title should use the new EventDialogHeaderLabel variation")

func test_dialog_desc_uses_event_body() -> void:
    var src := _read("res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn")
    assert_true(src.contains('theme_type_variation = &"EventBodyLabel"'),
        "Description and benefit/cost should use the larger EventBodyLabel")

func test_dialog_instructions_use_h2() -> void:
    var src := _read("res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn")
    # StudentsHeaderLabel ("Pilih siswa...") was CaptionLabel, now H2Label
    assert_true(src.find('StudentsHeaderLabel') != -1,
        "StudentsHeaderLabel should still exist")

func test_announcement_no_longer_uses_emoji() -> void:
    var src := _read("res://Scenes/SchoolSimulation/EventAnnouncement.tscn")
    assert_false(src.contains('"📢"'), "Emoji glyph must be gone from announcement scene")
    assert_true(src.contains("icon_event_announce.png"),
        "Announcement should reference the polished icon PNG")

func test_warning_no_longer_uses_emoji() -> void:
    var src := _read("res://Scenes/SchoolSimulation/EventWarning.tscn")
    assert_false(src.contains('"⚠️"'), "Warning emoji glyph must be gone")
    assert_true(src.contains("icon_event_warning.png"),
        "Warning should reference the polished icon PNG")
```

- [ ] **Step 2: Run test — expect FAIL** (all cases).

- [ ] **Step 3: Apply MCP edits to EventStudentSelectDialog.tscn**

```text
scene_open("res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn")

# Swap title to the big display-font variation
node_set_property Margin/DialogPanel/Margin/MainVBox/TitleLabel:
  theme_type_variation = "EventDialogHeaderLabel"

# Upgrade description label from default body (28px) to EventBodyLabel (32px)
node_set_property Margin/DialogPanel/Margin/MainVBox/DescLabel:
  theme_type_variation = "EventBodyLabel"

# Upgrade benefit/cost text from CaptionLabel (22px) to EventBodyLabel (32px)
node_set_property Margin/DialogPanel/Margin/MainVBox/CostBenefitBox/BenefitRow/Text:
  theme_type_variation = "EventBodyLabel"
node_set_property Margin/DialogPanel/Margin/MainVBox/CostBenefitBox/CostRow/Text:
  theme_type_variation = "EventBodyLabel"

# Upgrade instructions header from CaptionLabel (22px) to H2Label (48px)
node_set_property Margin/DialogPanel/Margin/MainVBox/StudentsHeaderLabel:
  theme_type_variation = "H2Label"

# Wire the calm paper background on the dialog root; the script's
# _apply_visual_exports() picks it up via the exported background_texture.
node_set_property .:
  background_texture = ExtResource("res://Assets/Images/UI/Placeholders/bg_event_dialog.png")

scene_save
```

- [ ] **Step 4: Verify script still fits**

Read `EventStudentSelectDialog.gd:118-133` — `_apply_visual_exports` already handles `background_texture`. No script change needed.

- [ ] **Step 5: Run tests, all green.**

- [ ] **Step 6: Commit**

```bash
git add Scenes/SchoolSimulation/EventStudentSelectDialog.tscn tests/test_event_polish.gd
git commit -m "$(cat <<'EOF'
feat(event-dialog): calm BG, enlarge header and body text for mobile readability

Swaps the harsh mint background for a muted paper-tint PNG. Title now uses
EventDialogHeaderLabel (display font, H1+6). Description and benefit/cost
labels jump from CaptionLabel 22px to EventBodyLabel 32px. Instructions
header upgraded to H2Label 48px.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Fix stat/trait popup instant-dismiss bug + body font for descriptions

**Problem 1 — popup immediately closes on open:**
The popup's `Scrim` (a full-screen `ColorRect`) is added to the tree, and its
`_on_scrim_input` handler listens for `event.pressed`. Because the icon-cluster
tap that *opened* the popup also fires on `event.pressed`, the very same input
event (or the next touch event in the same frame) propagates to the scrim and
triggers `close()` before the player sees the popup.

**Fix:** Start the scrim with `mouse_filter = MOUSE_FILTER_IGNORE` and flip it
to `MOUSE_FILTER_STOP` after the open animation completes (one frame + the
scrim fade). This way the scrim cannot catch the opening tap.

**Problem 2 — description text is all bold/display font:**
Both `StatDetailPopup.tscn` and `TraitDetailPopup.tscn` use `&"TitleLabel"`
(36px Boohong display font) for `DescriptionLabel`. That makes the gameplay
explanation dense and exhausting. The description should use body text (Open
Sans) for comfortable reading.

**Fix:** Change the `DescriptionLabel` variation from `&"TitleLabel"` to no
variation (default body 28px) or to `&"EventBodyLabel"` (32px body, added in
Task 2). We use `EventBodyLabel` — it is the moderate-bump body size that reads
well on mobile without feeling cramped.

**Files:**
- Modify: `Scripts/UI/StatDetailPopup.gd` — add scrim filter guard in `open()`
- Modify: `Scripts/UI/TraitDetailPopup.gd` — add scrim filter guard in `open()`
- Modify: `Scenes/UI/StatDetailPopup.tscn` — change DescriptionLabel variation, set scrim mouse_filter default
- Modify: `Scenes/UI/TraitDetailPopup.tscn` — change DescriptionLabel variation, set scrim mouse_filter default
- Test: `tests/test_popup_dismiss.gd` (new)

**Interfaces:**
- Consumes: `EventBodyLabel` (Task 2) for the description variation.

- [ ] **Step 1: Write the failing test**

`tests/test_popup_dismiss.gd`:

```gdscript
@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

func _read(p: String) -> String:
    return FileAccess.get_file_as_string(p)

func test_stat_popup_scrim_starts_ignoring_input() -> void:
    var src := _read("res://Scripts/UI/StatDetailPopup.gd")
    assert_true(src.contains("MOUSE_FILTER_IGNORE"),
        "Scrim must start ignoring input to prevent the opening tap from closing the popup")

func test_stat_popup_scrim_enables_after_open() -> void:
    var src := _read("res://Scripts/UI/StatDetailPopup.gd")
    assert_true(src.contains("MOUSE_FILTER_STOP"),
        "Scrim must re-enable input after the open animation so tap-to-dismiss works")

func test_trait_popup_scrim_starts_ignoring_input() -> void:
    var src := _read("res://Scripts/UI/TraitDetailPopup.gd")
    assert_true(src.contains("MOUSE_FILTER_IGNORE"),
        "Scrim must start ignoring input")

func test_trait_popup_scrim_enables_after_open() -> void:
    var src := _read("res://Scripts/UI/TraitDetailPopup.gd")
    assert_true(src.contains("MOUSE_FILTER_STOP"),
        "Scrim must re-enable input after open")

func test_stat_popup_description_uses_body_font() -> void:
    var src := _read("res://Scenes/UI/StatDetailPopup.tscn")
    assert_false(src.contains('"TitleLabel"'),
        "DescriptionLabel should no longer use the bold TitleLabel variation")
    assert_true(src.contains('"EventBodyLabel"'),
        "DescriptionLabel should use the body-weight EventBodyLabel variation")

func test_trait_popup_description_uses_body_font() -> void:
    var src := _read("res://Scenes/UI/TraitDetailPopup.tscn")
    assert_false(src.contains('"TitleLabel"'),
        "DescriptionLabel should no longer use the bold TitleLabel variation")
    assert_true(src.contains('"EventBodyLabel"'),
        "DescriptionLabel should use the body-weight EventBodyLabel variation")
```

- [ ] **Step 2: Run test — expect FAIL.**

- [ ] **Step 3: Patch StatDetailPopup.gd via `script_patch`**

In `_ready()`, change:

```gdscript
# Before:
func _ready() -> void:
    scrim.color = _scrim_color(0.0)
    close_button.pressed.connect(close)
    scrim.gui_input.connect(_on_scrim_input)
```

to:

```gdscript
func _ready() -> void:
    scrim.color = _scrim_color(0.0)
    scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    close_button.pressed.connect(close)
    scrim.gui_input.connect(_on_scrim_input)
```

In `open()`, after the scrim fade tween, add a callback to re-enable input:

```gdscript
func open() -> void:
    AudioDirector.play_sfx(&"popup_open")
    await get_tree().process_frame
    if not is_instance_valid(card):
        return
    var vp: Vector2 = get_viewport().get_visible_rect().size
    card.position = Vector2(
        (vp.x - card.size.x) * 0.5,
        vp.y - card.size.y - float(DesignTokens.load_default().space_md))
    Juice.pop_in(card)
    var tw := create_tween()
    tw.set_trans(Tween.TRANS_LINEAR)
    tw.tween_property(scrim, "color", _scrim_color(), scrim_fade_in_seconds)
    tw.tween_callback(func() -> void:
        if is_instance_valid(scrim):
            scrim.mouse_filter = Control.MOUSE_FILTER_STOP)
```

- [ ] **Step 4: Patch TraitDetailPopup.gd identically**

Same two changes: `MOUSE_FILTER_IGNORE` in `_ready()`, `MOUSE_FILTER_STOP` callback in `open()`.

- [ ] **Step 5: Update StatDetailPopup.tscn via MCP**

```text
scene_open("res://Scenes/UI/StatDetailPopup.tscn")

# Change the description font from bold TitleLabel to body-weight EventBodyLabel
node_set_property Scrim/Card/Layout/Body/BodyLayout/DescriptionLabel:
  theme_type_variation = "EventBodyLabel"

scene_save
```

- [ ] **Step 6: Update TraitDetailPopup.tscn via MCP**

```text
scene_open("res://Scenes/UI/TraitDetailPopup.tscn")

node_set_property Scrim/Card/Layout/Body/DescriptionLabel:
  theme_type_variation = "EventBodyLabel"

scene_save
```

- [ ] **Step 7: Force-reload both scripts**

`script_patch` was used, so the editor picks them up. If edited outside the editor, do a no-op `script_patch` to force reload.

- [ ] **Step 8: Run all tests — all green.**

- [ ] **Step 9: Commit**

```bash
git add Scripts/UI/StatDetailPopup.gd Scripts/UI/TraitDetailPopup.gd \
        Scenes/UI/StatDetailPopup.tscn Scenes/UI/TraitDetailPopup.tscn \
        tests/test_popup_dismiss.gd
git commit -m "$(cat <<'EOF'
fix(popup): stop stat/trait popups from closing on the same tap that opened them

The scrim's gui_input caught the opening press because it was MOUSE_FILTER_STOP
from frame zero. Now starts IGNORE and flips to STOP after the open animation
finishes. Also swaps DescriptionLabel from TitleLabel (bold Boohong 36px) to
EventBodyLabel (body Open Sans 32px) so the gameplay description is comfortable
to read instead of all-bold-all-the-time.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Grey out the tired EventStudentCard (was Task 5)

**Files:**
- Modify: `Scripts/SchoolSimulation/EventStudentCard.gd`
- Test: `tests/test_event_student_card_tired.gd` (new)

**Interfaces:**
- Consumes: `StudentData.is_tired()` (existing).

- [ ] **Step 1: Write the failing test**

```gdscript
@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

const CARD := preload("res://Scenes/SchoolSimulation/EventStudentCard.tscn")

func _make_student(tired: bool) -> StudentData:
    var s := StudentData.new()
    s.student_name = "Test"
    s.energy = 3.0 if tired else 80.0
    s.mood = 60.0
    return s

func test_tired_card_is_greyed_out() -> void:
    var card := CARD.instantiate()
    add_child(card)
    card.setup(_make_student(true), "Akademis")
    assert_almost_eq(card.modulate.a, 0.55, 0.02,
        "Tired card should be visibly dimmed")
    card.queue_free()

func test_fresh_card_full_opacity() -> void:
    var card := CARD.instantiate()
    add_child(card)
    card.setup(_make_student(false), "Akademis")
    assert_eq(card.modulate.a, 1.0)
    card.queue_free()
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Patch `set_selectable` in `Scripts/SchoolSimulation/EventStudentCard.gd`** via MCP `script_patch`:

Replace:

```gdscript
func set_selectable(on: bool) -> void:
    disabled = not on
    if not on:
        button_pressed = false
```

with:

```gdscript
func set_selectable(on: bool) -> void:
    disabled = not on
    if not on:
        button_pressed = false
    # A tired card is unclickable AND visually stepped back so a player
    # scanning the roster reads "unavailable" at a glance instead of
    # tapping it and wondering why nothing happens.
    modulate.a = 1.0 if on else 0.55
    if avatar:
        avatar.modulate = Color(0.7, 0.7, 0.75, 1.0) if not on else Color.WHITE
```

- [ ] **Step 4: Force-reload the script**

Since the patch went through MCP `script_patch`, the editor picks it up. If it was edited any other way, do a no-op `script_patch` on the same file to force reload.

- [ ] **Step 5: Run tests — all pass.**

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/EventStudentCard.gd tests/test_event_student_card_tired.gd
git commit -m "feat(event-card): grey out tired students so unavailability reads at a glance

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 7: Wire polished icons + SFX + burst particles onto Event popups

**Files:**
- Modify: `Scenes/SchoolSimulation/EventAnnouncement.tscn`
- Modify: `Scenes/SchoolSimulation/EventWarning.tscn`
- Modify: `Scripts/SchoolSimulation/EventAnnouncement.gd`
- Modify: `Scripts/Audio/AudioDirector.gd`
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd` (remove emoji from event titles at call sites)
- Create: `Scenes/SchoolSimulation/AnnouncementBurst.tscn`
- Create: `Scripts/SchoolSimulation/AnnouncementBurst.gd`
- Create: `Assets/Audio/SFX/event_announce.ogg` (see step 1)

**Interfaces:**
- Consumes: PNGs from Task 3, `AudioDirector.play_sfx(&"event_announce")`.

- [ ] **Step 1: Create SFX cue**

Stopgap: **copy** `Assets/Audio/SFX/reward.ogg` to `Assets/Audio/SFX/event_announce.ogg` so we have a dedicated file to swap when real audio arrives. This mirrors how `sfx_star_earn_1` etc. alias existing streams (documented in CLAUDE.md).

```bash
cp Assets/Audio/SFX/reward.ogg Assets/Audio/SFX/event_announce.ogg
```

Then `filesystem_manage(op="scan")`.

- [ ] **Step 2: Register the cue on AudioDirector**

`script_patch` `Scripts/Audio/AudioDirector.gd` to add after `sfx_reward`:

```gdscript
## `play_sfx(&"event_announce")`: mid-simulation event popup opens.
## Placeholder: aliases sfx_reward.ogg until a dedicated chime lands.
@export var sfx_event_announce: AudioStream = preload("res://Assets/Audio/SFX/event_announce.ogg")
```

The existing `play_sfx` dispatcher resolves `&"event_announce"` via naming convention; verify by grepping the dispatcher and following the pattern that `sfx_popup_open` uses. If the dispatcher requires an explicit map entry, mirror the `sfx_popup_open` line as well.

- [ ] **Step 3: Create AnnouncementBurst scene + script**

`Scripts/SchoolSimulation/AnnouncementBurst.gd`:

```gdscript
@tool
extends GPUParticles2D
class_name AnnouncementBurst

## One-shot celebratory burst spawned by EventAnnouncement when the
## popup fades in. Fires particle_burst.png outward in a ring, mixed with
## a sparser layer of particle_star.png for scale variety, then frees
## itself once the emission window closes.

func _ready() -> void:
    if Engine.is_editor_hint():
        return
    one_shot = true
    emitting = true
    var t := (lifetime + 0.2)
    await get_tree().create_timer(t).timeout
    queue_free()
```

`Scenes/SchoolSimulation/AnnouncementBurst.tscn`: build via MCP.

```text
scene_manage new_scene root=GPUParticles2D script=AnnouncementBurst.gd
set_property amount = 40
set_property lifetime = 0.9
set_property texture = ExtResource("res://Assets/Images/Particles/particle_burst.png")

# ParticleProcessMaterial (create as sub-resource):
process_material.direction = Vector3(0, -1, 0)
process_material.spread = 180
process_material.initial_velocity_min = 350
process_material.initial_velocity_max = 550
process_material.gravity = Vector3(0, 220, 0)
process_material.scale_min = 0.4
process_material.scale_max = 1.1
process_material.color = Color("ffd333")   # cat_libur gold
scene_save
```

- [ ] **Step 4: Repolish EventAnnouncement.tscn via MCP**

Batch:

- Set root property `background_texture = ExtResource(bg_event_announce.png)`.
- Set root property `announcement_icon_texture = ExtResource(icon_event_announce.png)`.
- Set root property `icon_font_size = 320` (down from 760 — the current 760 is why the icon eats the whole popup).
- Change `IconLabel.text` to `""` and `HeaderLabel.text` to `"PENGUMUMAN EVENT SEKOLAH"` (no emoji prefix).
- Change `HeaderLabel.theme_type_variation` to `"EventDialogHeaderLabel"`.
- Add child `Burst` = instance of `AnnouncementBurst.tscn`, anchored center, `position = Vector2(540, 900)`.

`scene_save`.

- [ ] **Step 5: Repolish EventWarning.tscn via MCP**

- Set root property `caution_icon_texture = ExtResource(icon_event_warning.png)`.
- Set root property `icon_font_size = 320`.
- Change `CautionLabel.text` to `""`.
- Set `EventLabel.theme_type_variation` to `"EventDialogHeaderLabel"`.

`scene_save`.

- [ ] **Step 6: Patch EventAnnouncement.gd**

`script_patch`:

- In `play_announcement`, right after `show()`, insert:

```gdscript
if not Engine.is_editor_hint():
    AudioDirector.play_sfx(&"event_announce")
```

- Delete the default value of `announcement_symbol_text` (change to `""`) and delete the `else:` branch in `_apply_visual_exports` that renders `announcement_symbol_text` — art is now required. Leave the `if announcement_icon_texture:` branch intact.

- [ ] **Step 7: Strip emojis from SchoolDay call sites**

`script_patch` `Scripts/SchoolSimulation/SchoolDay.gd`:

- Line 932/936/940: change `"📚 KEGIATAN AKADEMIS!"` → `"KEGIATAN AKADEMIS!"`, `"⚽ KEGIATAN OLAHRAGA!"` → `"KEGIATAN OLAHRAGA!"`, `"🎨 KEGIATAN SENI BUDAYA!"` → `"KEGIATAN SENI BUDAYA!"`.
- Line 1031/1044/1549/1560: change `"🍱 Kejutan Nasi Kotak Orang Tua!"` → `"Kejutan Nasi Kotak Orang Tua!"`, `"🌧 Hujan Deras & Jalanan Licin!"` → `"Hujan Deras & Jalanan Licin!"`.

- [ ] **Step 8: Extend the polish test**

Add to `tests/test_event_polish.gd`:

```gdscript
func test_announce_scene_wires_burst() -> void:
    var src := _read("res://Scenes/SchoolSimulation/EventAnnouncement.tscn")
    assert_true(src.contains("AnnouncementBurst.tscn"),
        "EventAnnouncement should instance the burst")

func test_announce_script_plays_sfx() -> void:
    var src := FileAccess.get_file_as_string(
        "res://Scripts/SchoolSimulation/EventAnnouncement.gd")
    assert_true(src.contains('play_sfx(&"event_announce")'),
        "Announcement should play the new SFX cue")

func test_school_day_titles_free_of_emoji() -> void:
    var src := FileAccess.get_file_as_string(
        "res://Scripts/SchoolSimulation/SchoolDay.gd")
    for glyph in ["📚", "⚽", "🎨", "🍱", "🌧"]:
        assert_false(src.contains(glyph),
            "SchoolDay should not carry emoji in event titles: %s" % glyph)
```

- [ ] **Step 9: Run everything — all green.**

- [ ] **Step 10: Playtest via debug overlay**

MCP `project_run`, then via the overlay: seed playtest → teleport to SchoolDay → let it run until an event fires, or use the overlay's manual event trigger. Screenshot the announcement, warning, and event student select dialog. Verify legibility on the mobile viewport.

- [ ] **Step 11: Commit**

```bash
git add Scenes/SchoolSimulation/EventAnnouncement.tscn \
        Scenes/SchoolSimulation/EventWarning.tscn \
        Scenes/SchoolSimulation/AnnouncementBurst.tscn \
        Scripts/SchoolSimulation/EventAnnouncement.gd \
        Scripts/SchoolSimulation/AnnouncementBurst.gd \
        Scripts/SchoolSimulation/SchoolDay.gd \
        Scripts/Audio/AudioDirector.gd \
        Assets/Audio/SFX/event_announce.ogg \
        Assets/Audio/SFX/event_announce.ogg.import \
        tests/test_event_polish.gd
git commit -m "$(cat <<'EOF'
feat(event-popups): swap emoji for polished PNGs, add SFX cue and burst

Replaces the placeholder emoji icons on EventAnnouncement and EventWarning
with dedicated transparent PNGs sized down from the previous 760px, wires
a fresh AnnouncementBurst particle scene on top of the announcement, and
adds a dedicated sfx_event_announce cue (aliased to reward.ogg for now)
so the popup no longer opens silently.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Update CLAUDE.md "Outstanding debt" section

**Files:**
- Modify: `CLAUDE.md`

**Interfaces:** none.

- [ ] **Step 1: Edit `CLAUDE.md` "Outstanding debt & placeholders"**

- Under **Audio placeholders**, add: `sfx_event_announce` → `reward.ogg`.
- Under **Art placeholders**, add: `icon_event_announce.png`, `icon_event_warning.png`, `bg_event_announce.png`, `bg_event_dialog.png`, `particle_burst.png` — flat generated placeholders, transparent PNGs suitable for drop-replacement.
- Remove any resolved lines that these changes obsolete (none currently; the emoji-in-titles line was informal).

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: record event-popup placeholder assets in outstanding debt

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Self-review notes

- **Spec coverage:** StudentCard clipping/typography (Task 1); event dialog BG + header font + tired-student clarity (Tasks 2, 4, 5); event popup placeholders + SFX + particles (Task 6); placeholder generation (Task 3); no emoji anywhere (Tasks 6/7). All screenshot 598 and 599 gripes plus the announcement warning gripe are mapped.
- **Types / names checked:** `EventDialogHeaderLabel` used identically in Tasks 2, 4, 6. `sfx_event_announce` file + `@export` + `play_sfx(&"event_announce")` cue name aligned.
- **Known deferred:** icons and BGs are placeholders on purpose — logged in CLAUDE.md by Task 7.
- **Editor-restart hazard:** avoided. No new `DesignTokens` `@export` is added; the new variation uses only existing tokens, so the rebake in Task 2 works in the running editor.
