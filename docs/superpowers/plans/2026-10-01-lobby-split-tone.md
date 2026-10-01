# Lobby split-tone — implementation plan

Spec: `docs/superpowers/specs/2026-10-01-lobby-split-tone-design.md`.
Worktree `.claude/worktrees/lobby-split-tone`, branch `feat/lobby-split-tone`.

Every text edit lands **before** a Godot editor opens this worktree, so the
hand edit of `Lobby.tscn` (task 3) cannot be overwritten by an editor's
in-memory copy (CLAUDE.md, Working efficiently 4).

1. **Shader.** `Scripts/Shaders/illustration_grade.gdshader`: add the
   `SPLIT-TONE` header paragraph, the four uniforms (`shadow_tone`,
   `highlight_tone`, `split_balance`, `split_strength`), `const SPLIT_WIDTH`,
   and the luma-preserving block after the tint line, gated on
   `split_strength > 0.0`.
2. **Materials.** New `illustration_grade_material_lobby.tres` (a copy of
   the plain material plus split-tone). Add the same split-tone values to
   `illustration_grade_cutout_lobby.tres` and `illustration_grade_face.tres`.
   Starting values: shadow 1.10 / 0.96 / 1.00, highlight 1.04 / 1.00 / 0.94,
   balance 0.5, strength 0.7.
3. **Lobby.tscn.** Add an ext_resource for the new backdrop material and for
   the face material. Point `BGLayer` at the new backdrop material. Add
   `material = ExtResource(face)` to all 24 `Hand_*` and 24 `Items_*`.
4. **Debug Look page.** `Scripts/Debug/DebugLookPanel.gd`: a "Split-Tone
   Lobby:" block (switch, strength, balance, three shadow channels, three
   highlight channels) over the three Lobby materials, plus a helper that
   writes one channel of a Color parameter.
5. **Tests.**
   - New `tests/test_lobby_split_tone.gd`.
   - `test_illustration_ao.gd`: move `BGLayer` out of BACKDROPS into a
     LOBBY_BACKDROP bucket, add a LOBBY_HANDS bucket (48), set the census
     to 90, and make the shared-grade parity list include the new material.
   - `test_look_layer.gd`: add the 48 plates and the new material to GRADED,
     the shared-material check, the saturation check and the ceilings.
6. **Docs.** Style guide "Illustration materials" paragraph; CHANGELOG
   entry once it has landed.
7. **Verify.** Seed the worktree's `.godot`, launch a second editor detached,
   run the targeted suites (`lobby_split_tone`, `illustration_ao`,
   `look_layer`, `lobby_look`, `script_documentation`, `clean_code`), then
   live-measure the Lobby: mean luma before and after (frozen tree), a hand
   against its face, and one minigame unchanged. Send full-size captures.
8. **Ship** with `ship-pr` once the owner has seen the screenshots.
