# Audio

- `SFX/` — short one-shot sounds
- `BGM/` — looping music

## Filling or swapping a slot

1. Drop your `.ogg` (preferred) or `.wav` into `SFX/` or `BGM/`.
2. In the Godot editor, expand the **AudioDirector** autoload
   (Project > Project Settings > Autoload, or just open
   `Scenes/Audio/audio_director.tscn`).
3. Drag your file onto the matching slot in the inspector.

No code changes required. Slots you leave empty simply play nothing.

| Slot | Fires when |
|---|---|
| `sfx_tap` | any button is pressed |
| `sfx_confirm` | a positive/accept action |
| `sfx_cancel` | back, close, decline |
| `sfx_success` | a target is met, a day goes well |
| `sfx_fail` | a target is missed |
| `sfx_coin` | money changes |
| `sfx_whoosh` | scene transitions |
| `sfx_pop` | a card or list item enters |
| `bgm_menu` | MainMenu, Settings |
| `bgm_lobby` | Lobby, StudentCard, StudentList, AturJadwal |
| `bgm_simulation` | SchoolDay |
| `bgm_result` | SemesterEnd |

## Current SFX source

The 8 `sfx_*` slots are filled with clips from Kenney's **UI Audio**
pack (CC0, kenney.nl/assets/ui-audio) — downloaded directly from
kenney.nl and mapped as a starting point, not a final mix:

| Slot | File | Kenney source |
|---|---|---|
| `sfx_tap` | `SFX/tap.ogg` | `click1.ogg` |
| `sfx_confirm` | `SFX/confirm.ogg` | `click2.ogg` |
| `sfx_cancel` | `SFX/cancel.ogg` | `click3.ogg` |
| `sfx_success` | `SFX/success.ogg` | `switch1.ogg` |
| `sfx_fail` | `SFX/fail.ogg` | `switch2.ogg` |
| `sfx_coin` | `SFX/coin.ogg` | `click4.ogg` |
| `sfx_whoosh` | `SFX/whoosh.ogg` | `rollover1.ogg` |
| `sfx_pop` | `SFX/pop.ogg` | `click5.ogg` |

The Kenney pack is generic UI clicks/switches — it has no dedicated
coin, whoosh, or success/fail stingers, so those four are
reasonable-but-approximate stand-ins. Swap any of them for a
purpose-made sound whenever one is available; see
`SFX/Kenney_License.txt` for the pack's CC0 license text (attribution
is appreciated but not required).

`bgm_*` slots are intentionally left empty — music is a bigger
creative choice than SFX and is left for a deliberate pass later.
