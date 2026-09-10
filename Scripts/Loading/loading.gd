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
##
## Flow: CutScene wipes here with the real target in GameState.next_scene
## (see cut_scene.gd). This screen threads that target in behind the
## progress bar, then hands back to Transition to wipe on to it -- so the
## whole hop, entry and exit, carries the shared cover. The exit waits on
## _incoming_wipe_done: a target that is already cached finishes loading
## in under a frame, and calling Transition.change_scene() while its entry
## wipe is still retracting would hit Transition's _busy guard and be
## silently dropped, stranding the player here.

@onready var _bar: ProgressBar = $LoadingBar
@onready var _label: Label = $LoadingLabel

var _target_path: String = ""
var _incoming_wipe_done: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_target_path = GameState.next_scene
	_label.text = "Memuat..."
	_bar.value = 0.0
	# Transition instantiates this scene mid-change_scene_to_file(), so
	# _ready runs before it emits scene_changed for the entry wipe -- the
	# connection is always in place before that signal fires.
	Transition.scene_changed.connect(_on_incoming_wipe_done)
	ResourceLoader.load_threaded_request(_target_path)


## The entry wipe has fully retracted and Transition is idle again, so the
## exit wipe is now safe to start. See the header note above.
func _on_incoming_wipe_done(_path: String) -> void:
	_incoming_wipe_done = true
	Transition.scene_changed.disconnect(_on_incoming_wipe_done)


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
			if not _incoming_wipe_done:
				return
			# Consume the threaded load so it does not linger as pending;
			# the PackedScene stays in ResourceLoader's cache, so the
			# change_scene_to_file() inside Transition.change_scene() picks
			# it up without a second disk read.
			ResourceLoader.load_threaded_get(_target_path)
			var dest := _target_path
			_target_path = ""
			Transition.change_scene(dest, Transition.Style.WIPE)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Loading: failed to load " + _target_path)
			_target_path = ""
			_label.text = "Gagal memuat"
