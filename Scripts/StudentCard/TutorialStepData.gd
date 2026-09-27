class_name TutorialStepData
extends Resource

## Title displayed at the top of the tutorial popup for this step.
@export var title: String = ""

## Main body text explaining this tutorial step. Supports multi-line.
@export_multiline var text: String = ""

## Path(s) to the node(s) to spotlight-highlight (relative to scene root).
## Can be a single path or comma-separated paths (e.g. "Path1,Path2") to highlight multiple items under a single box.
## Leave empty for no spotlight highlight on this step.
@export var target_node_path: String = ""

## Optional custom prompt text displayed at bottom of panel (e.g. "Tekan tombol 'Senin' untuk lanjut!").
## If empty, auto-detects whether the step requires a specific button press or clicking anywhere.
@export var prompt_text: String = ""
