# Student chatter in the Lobby — design

**Date:** 2026-09-19 · **Branch:** `feat/student-chatter`

## What the player gets

In the Lobby, the seated students talk. Tap a student and they say a short
line in a chat bubble that pops out of *their* seat; leave the screen alone for
20–50 s and a random student pipes up on their own. What they say depends on
who they are — their personality (`Tekun`, `Aktif`, …), their quirk (`Kutu
Buku`, `Biang Onar`, …) and, when it is extreme, how they feel right now (tired,
sulky, happy). Only one student talks at a time, and tapping repeatedly never
stacks or restarts bubbles: the line already showing stays until it finishes.

## Reference: Pak Herman's bubble

`Scripts/Koperasi/ChatBubble.gd` is the model: a Control with `Body`
(PanelContainer, `ShopChatBubble`) › `Text`, plus a `Tail` TextureRect
(`chat_bubble_tail.svg`, a right triangle whose tip is its bottom-right
corner). It pops in with `TRANS_BACK` scale 0.2→1 + fade from a pivot at the
tail tip, lingers, then shrinks back toward the speaker. We copy that motion;
we do not reuse the class, because it is bound to Herman (his catalog, his
AnimationPlayer, sticky lines, per-event cooldowns) and its rest position is a
fixed literal, while ours moves between four seats and mirrors.

## Where it happens

Lobby only (`Scenes/Lobby/loby.tscn`). The diorama has four seats:

```
 ┌──────────── Classroom 1080×1920 ────────────┐
 │  Slot1 (back, left)     Slot2 (back, right)  │
 │  Slot3 (front, left)    Slot4 (front, right) │
 └──────────────────────────────────────────────┘
```

Left-column student (Slot1/Slot3):  tail flipped to the bubble's LEFT edge,
bubble grows to the right, toward the room's centre.

```
        ┌──────────────────────┐
        │ Pak, ini PR-nya...   │
        └┐─────────────────────┘
         \   ← tail tip on the student's ChatAnchor
       (face)
```

Right-column student (Slot2/Slot4): tail as authored (right edge), bubble
grows to the left. Rule: `flip = anchor_global.x < viewport_width / 2`.

## Logic

### Line selection — `StudentChatterCatalog`

- `PERSONALITY_LINES[personality]` — 8 lines each for `Aktif`, `Tekun`,
  `Kreatif`, `Santai`, `Seni Dalam Kesunyian`.
- `QUIRK_LINES[quirk]` — 8 lines each for `Kutu Buku`, `Penyendiri`,
  `Semangat Juang`, `Penasaran`, `Biang Onar`, `Pekerja Keras`.
- `STATE_LINES[state]` — 6 lines each for `LELAH`, `BETE`, `SENANG`.
- `GENERIC_LINES` — 6 lines, the fallback for a student whose personality and
  quirk are both unknown (debug rosters).
- `state_for(student)`: `LELAH` when energy ≤ 30, else `BETE` when mood ≤ 30,
  else `SENANG` when mood ≥ 75, else none. Energy wins because an exhausted
  student is the more urgent read for the teacher.
- A student's **trait pool** = personality lines + quirk lines (16 lines for
  every shipped student). Andi and Thea share `Kreatif`, so what makes each
  unique is the quirk half.
- Each line is drawn: if the student has a state, `STATE_CHANCE` = 0.4 of the
  time the line comes from that state's pool; otherwise from the trait pool.
- **Anti-repetition** (`StudentChatterPicker`, one instance per Lobby): a
  shuffle bag per (student name, pool). Every line in a pool is said once
  before any repeats, and a refilled bag never starts with the line that just
  ended the previous one. With 16 trait lines, a student repeats at most once
  every 16 lines.
- Every line ≤ 60 characters and must fit on three lines of the bubble's text
  at its font (a test measures this with the real font).
- Voice: students talking to their teacher, "Pak" / "Pak Guru", casual
  Indonesian school slang, no emoji.

### Showing a line — `StudentChatBubble`

States `IDLE → SHOWING → LINGERING → HIDING → IDLE`, as in Herman's bubble.

- `show_line(text, anchor_global, flip)`: sets text, flips (tail `flip_h`
  and mirrored x inside the bubble), sets `pivot_offset` to the tail tip,
  places the bubble so the tip lands on the anchor, clamps it inside the
  visible rect with `EDGE_MARGIN` (24 px), then tweens in: scale
  0.2→1, alpha 0→1, `FADE_IN_S` 0.32, `TRANS_BACK`/`EASE_OUT`.
- Lingers `LINGER_S` = 2.6 s, then tweens out: scale → 0.2, alpha → 0,
  `FADE_OUT_S` 0.28, `TRANS_CUBIC`/`EASE_IN`, shrinking into the tail tip —
  i.e. back into the student.
- `is_busy()` is true in every state except IDLE.
- `dismiss()` cuts straight to the hide tween (used when a popup opens).
- Emits `finished` on reaching IDLE.
- Clamping keeps the body on screen; when it clamps, the tail stays attached
  to the body, so its tip can sit a few px off the anchor. Accepted.

### Who talks and when — `LobbyChatter`

A plain `Node` in `loby.tscn`, handed the seats by `loby.gd`.

- **Seat** = `{student: Dictionary, hit: Control, anchor: Control}`; `hit`
  is the slot's visible face/portrait, `anchor` the slot's `ChatAnchor`.
- **Tap** (`_input`, InputEventScreenTouch / left mouse button, *pressed*):
  resets the idle timer; if the press is inside a seat's `hit` global rect,
  that seat asks to talk.
- **Spam guard**: a request is refused while the bubble `is_busy()`, and for
  `TAP_COOLDOWN_S` = 0.5 s after it goes idle. A refused tap changes nothing —
  the line on screen keeps its text and its remaining linger time.
- **Idle chatter**: a one-shot timer of `randf_range(IDLE_MIN_S, IDLE_MAX_S)`
  = 20–50 s, re-rolled every time it re-arms. It re-arms on every tap and
  whenever the bubble finishes. On timeout a random seated student talks,
  never the previous idle speaker when there is more than one seat.
- **Gate**: `loby.gd` hands in `can_speak: Callable`, false while the lobby
  tutorial is active, the daily-reward popup is open, or a skin picker is
  open. Blocked requests are dropped; a blocked idle timeout simply re-arms.
- Opening the skin picker calls `dismiss()`; its `closed` re-seats the
  students (`_setup_students` → `set_seats`).
- No students approved → no seats → no chatter.

## State

Read-only. Nothing is written anywhere and nothing is persisted.

| Read from `GameState.approved_students[i]` | Meaning |
|---|---|
| `name` | bag key, seat identity |
| `personality` (fallback: `persona` with `Persona ` stripped; `Pendiam` → `Seni Dalam Kesunyian`) | trait pool |
| `quirk` | trait pool |
| `kepribadian1` (**mood**, 0–100) | `BETE` / `SENANG` |
| `kepribadian2` (**energy**, 0–100) | `LELAH` |

`StudentData` is not involved — the Lobby only holds the dictionaries, and
`kepribadian1` is mood, `kepribadian2` energy (`StudentData.mood` /
`StudentData.energy` on the other side of the bridge).

## Kelas 7/8/9

No difference. Lines, timings and triggers are the same in every grade.

## Files

| File | Change |
|---|---|
| `Scripts/Lobby/StudentChatterCatalog.gd` | new — line pools, `state_for`, `personality_of` |
| `Scripts/Lobby/StudentChatterPicker.gd` | new — shuffle bags, anti-repeat |
| `Scripts/Lobby/StudentChatBubble.gd` + `Scenes/Lobby/StudentChatBubble.tscn` | new — the bubble |
| `Scripts/Lobby/LobbyChatter.gd` | new — taps, spam guard, idle timer, gate |
| `Scenes/Lobby/loby.tscn` | `ChatAnchor` in each portrait slot; `ChatBubble` instance as Classroom's last child; `Chatter` node |
| `Scripts/Lobby/loby.gd` | hand seats + gate to `Chatter`; dismiss on skin picker |
| `Scripts/Design/ThemeFactory.gd` + rebake | `StudentChatBubble` (PanelContainer) and `StudentChatText` (Label, bold body face, `font_title`, `text_primary`) — body face, not on `DISPLAY_ROSTER` |
| `tests/test_student_chatter.gd` | new suite |
| `docs/superpowers/CHANGELOG.md` | entry |

The bubble is a PackedScene instanced in the `.tscn` (no runtime visual
construction); every script gets a `##` header and `##` on every `@export`.

## Testing

- Catalog: every personality and quirk has ≥ 8 lines, states ≥ 6; every line
  ≤ 60 chars, non-empty, no emoji; every line fits in 3 lines of the bubble's
  text width at the baked `StudentChatText` font.
- `state_for` thresholds, including energy beating mood.
- Picker: a full pool cycles with no repeats; the bag boundary never repeats.
- Bubble: flip rule, tail mirrored, tip lands on the anchor, clamping.
- Chatter: spam guard (busy → refused, text unchanged), cooldown, idle range
  20–50, gate blocks, idle speaker differs from the previous one.
- Scene scans: four `ChatAnchor`s, one bubble instance, `Chatter` wired.

## Not doing

- Chatter anywhere but the Lobby.
- Several students talking at once or replying to each other.
- Grade-specific or week-specific lines.
- A talk animation on the face rigs, and a speech SFX.
- Generalising Herman's `ChatBubble` into a shared base class.
