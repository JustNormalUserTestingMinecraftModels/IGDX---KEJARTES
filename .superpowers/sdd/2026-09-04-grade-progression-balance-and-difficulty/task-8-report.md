# Task 8 Report: ActivityPreview.is_specialty() + AudioDirector SFX Cue

## Status: DONE

## Summary

Implemented the scripting foundation for AturJadwal specialty feedback (Task 8 of the 4-task sequence). All three code changes requested by the brief are complete.

## Changes Made

### 1. Scripts/AturJadwal/ActivityPreview.gd
- Added `is_specialty(category: String, student: Dictionary) -> bool` static function immediately after `_specialty_of()`
- The function correctly delegates to `_specialty_of()` to normalize "Akademik" -> "Akademis", ensuring no duplicate normalization logic
- Includes full docstring matching the brief's specification

### 2. Scripts/Audio/AudioDirector.gd
- Added `@export var sfx_specialty_match: AudioStream` export variable (line 92) positioned after `sfx_combo_up` and before `sfx_pill_popup_open`
- Includes English-language doc comment in the existing `play_sfx(&"...")` format: "AturJadwal, a day is assigned to the selected student's specialty subject. Placeholder: aliases sfx_reward."
- Added match arm `&"specialty_match": return sfx_specialty_match` in the `_resolve_sfx()` function (line 253), positioned after the `combo_up` arm

### 3. tests/test_atur_jadwal_specialty_feedback.gd (NEW FILE)
- Created `@tool` test suite extending `McpTestSuite`
- Implements `suite_name()` returning `"atur_jadwal_specialty_feedback"`
- Two non-coroutine test functions:
  - `test_is_specialty_truth_table()`: Verifies the function's truth table, including the critical normalization of "Akademik" to "Akademis"
  - `test_specialty_match_cue_registered()`: Source-scan verification that both the export and match arm exist in AudioDirector

## Self-Review Findings

✓ **Normalization delegation**: `is_specialty()` correctly reuses `_specialty_of()` and does not reimplement the "Akademik" -> "Akademis" normalization
✓ **Test suite format**: File is `@tool`, extends `McpTestSuite`, has `suite_name()`, and contains no coroutines
✓ **Scope boundaries**: Touched only the three required files (ActivityPreview, AudioDirector, new test file)
✓ **Export positioning**: `sfx_specialty_match` added in the SFX section before the BGM group (@export_group separator at line 100)
✓ **Match arm placement**: New cue added to `_resolve_sfx()` in the correct match block order
✓ **Doc comment format**: Matches existing `play_sfx(&"...")` documentation style in the file

## Pending Editor-Side Work

**⚠️ AudioDirector stream assignment (Step 5 of brief) is still pending.**

The new `sfx_specialty_match` export is currently unassigned (no default value). Per the task instructions, the Godot editor MCP bridge is not accessible to this agent (single-client, controller-held). The controller must:

1. Open the AudioDirector autoload scene (`Scenes/Audio/audio_director.tscn`)
2. Assign `sfx_specialty_match` to the **same AudioStream resource** currently in `sfx_reward` (as a placeholder alias)
3. Save the scene

This is expected and not a blocker — the script-side infrastructure is complete and ready for the controller to wire up the audio asset.

## Files Modified

- **Modified**: C:\Users\Legion\Documents\KEJARTES\new-game-project\Scripts\AturJadwal\ActivityPreview.gd
- **Modified**: C:\Users\Legion\Documents\KEJARTES\new-game-project\Scripts\Audio\AudioDirector.gd
- **Created**: C:\Users\Legion\Documents\KEJARTES\new-game-project\tests\test_atur_jadwal_specialty_feedback.gd

## Commit

SHA: `21633c3`
Subject: `feat(atur-jadwal): add ActivityPreview.is_specialty and the specialty_match SFX cue`

## Verification Method

Self-checked by re-reading the implementation:
- `ActivityPreview.is_specialty()` implementation verified (lines 27-31)
- `AudioDirector.sfx_specialty_match` export verified with doc comment (lines 90-92)
- Match arm verified in `_resolve_sfx()` (line 253)
- Test file verified for `@tool`, `McpTestSuite` extension, `suite_name()`, and non-coroutine tests

No test suite run performed (per task instructions: controller will run `test_run` after report).

---

## Task 8 Round 1 Fix: Test Audio Coverage

**Date:** 2026-09-04 (follow-up)

The initial test_run by the controller caught a failure in `test_audio_coverage.gd::test_every_play_sfx_id_in_the_project_is_known`: the new `&"specialty_match"` cue was unknown to the test suite's hardcoded allowlist.

### Fix Applied

**Modified**: `tests/test_audio_coverage.gd`

Added `"specialty_match"` to the `known` array at line 119-125, positioned after `"sparkle"` (grouped with other reward-flavored cues `reward`, `tally`). The array remains well-formed GDScript with proper indentation and trailing comma convention.

### Verification

Scanned `tests/test_audio_coverage.gd` for all hardcoded id lists:
1. **`known` array (line 119)**: Updated ✓ — the typo guard for all `play_sfx(&"...")` calls
2. **`REWARD_SFX_IDS` constant (line 401)**: Not modified — this array is explicitly for the 2026-09-04 minigame reward pass cues only. Adding `specialty_match` there would cause `test_every_reward_cue_resolves_to_a_real_stream()` to fail, since the stream assignment is still pending in the editor.

No other hardcoded id lists found in the file.

### Status

✓ Fix complete. The test `test_every_play_sfx_id_in_the_project_is_known` should now pass.
