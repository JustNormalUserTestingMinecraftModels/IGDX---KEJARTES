# Known pre-existing errors/warnings (baseline, Task 0)

These were observed in the editor and game logs during Task 0 verification
(scene parsing checks and the Step 8 boot test), captured **after** the
`Scenes/Transition/transition.tscn` corruption fix was applied. They are
**not** caused by that fix and are **not this plan's responsibility to fix**
— recorded here so later tasks don't mistake them for regressions.

## Invalid ext_resource UIDs (warnings, not errors)

Godot logs a warning and falls back to the resource's text path whenever a
scene's `ext_resource` UID doesn't match the `.uid` sidecar file it should
reference. Observed for:

```
res://Scenes/StudentList/student_list.tscn:4 - ext_resource, invalid UID: uid://c7gmkcle3uv8o - using text path instead: res://Assets/Images/MuridPotrait/Murid1.jpg
res://Scenes/StudentList/student_list.tscn:6 - ext_resource, invalid UID: uid://bhanm4qbpra2a - using text path instead: res://Assets/Images/UI/paper.png
res://Scenes/StudentList/student_list.tscn:7 - ext_resource, invalid UID: uid://0c5vps0sx30f - using text path instead: res://Assets/Images/UI/stickynotes.png
res://Scenes/Loading/loading.tscn:4 - ext_resource, invalid UID: uid://cwmltvrg3rr1t - using text path instead: res://Assets/Images/UI/—Pngtree—book icon vector_4358423.png
```

Source: `logs_read(source="editor")` (all four appear on any scene load/scan
in this editor session), and the last one (`loading.tscn:4`) also surfaces
in `logs_read(source="game")` during the boot test, attributed to
`res://Scripts/Transition/transition.gd:14 @ change_scene` (i.e. it fires
when `transition.gd` loads `loading.tscn` while switching scenes) — this is
expected: the transition script's job is to load whatever scene it's given,
and the warning originates in `loading.tscn`'s own resource references, not
in the transition script.

Effect: Godot resolves the resource via its text path instead of the UID and
loads it successfully — no missing assets, no visual/functional breakage
observed. These are stale/broken UID references in the two `.tscn` files
themselves, unrelated to the `transition.tscn` corruption fixed in Task 0.

No other errors or warnings were observed in `logs_read(source="editor")` or
`logs_read(source="game")` while verifying `transition.tscn` (Step 3) or
during the full boot test through Splashscreen -> Loading -> MainMenu
(Step 8).
