@tool
extends Control

## @tool note: mirrors Scripts/MainMenu/main_menu.gd's established pattern
## (see that script's header for the full placeholder-instance
## explanation). The MCP test suite instantiates this scene from inside
## the editor process; without @tool the script becomes a placeholder
## and traversal-based checks on the root node break. The real work here
## -- reading GameState.next_scene and kicking off a threaded resource
## load -- is a runtime-only side effect that must never fire just
## because a human opened this scene in the editor, or because the test
## suite instantiated it to check for theme overrides/hardcoded colors.
## Both cases are covered by Engine.is_editor_hint().

@onready var _bar: ProgressBar = $LoadingBar
@onready var _label: Label = $LoadingLabel

var _target_path: String = ""


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_target_path = GameState.next_scene
	_label.text = "Memuat..."
	_bar.value = 0.0
	ResourceLoader.load_threaded_request(_target_path)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _target_path.is_empty():
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_target_path, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_bar.value = progress[0] * 100.0
		ResourceLoader.THREAD_LOAD_LOADED:
			_bar.value = 100.0
			var packed := ResourceLoader.load_threaded_get(_target_path)
			_target_path = ""
			get_tree().change_scene_to_packed(packed)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Loading: failed to load " + _target_path)
			_target_path = ""
			_label.text = "Gagal memuat"
