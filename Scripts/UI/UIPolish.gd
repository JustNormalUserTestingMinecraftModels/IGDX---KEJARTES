extends Node

## Auto-applies press feedback and tap SFX to every BaseButton in the
## tree, so individual scenes never have to wire it up.
##
## Opt a button out with:
##     my_button.set_meta(Juice.NO_AUTO_JUICE, true)
## which is what you want for buttons that are full-screen invisible
## click-catchers (e.g. AturJadwal's ColorRect/ClickArea), where a
## scale pulse would visibly distort the whole overlay.
##
## This is a plain script-only autoload (no .tscn, registered directly
## in project.godot) and carries no @tool annotation. That is
## deliberate: get_tree().node_added fires for EVERY node added to
## ANY SceneTree, and in the editor process that includes nodes the
## editor itself creates while a human is just clicking around
## building/editing unrelated scenes — not playing the game. A script
## autoload without @tool is only ever instantiated when the project
## is actually run (F5 / project_run), so _ready() here can never fire
## from ordinary scene-editing; there is nothing to guard the way
## AudioDirector's scene-based _ready() had to be guarded. (AudioDirector
## needed @tool because its .tscn is opened directly by its own test
## suite inside the editor; UIPolish has no such test — nothing here
## instantiates this script as a live node inside the editor process,
## so @tool would only add exposure to editor-side node_added noise for
## no testing benefit.)


## Master off switch -- false stops _on_node_added from juicing any new
## button, but does not un-juice buttons already wired.
@export var enabled: bool = true
## Buttons larger than this in either axis are treated as invisible
## click-catchers and skipped automatically.
@export var max_juiced_size: Vector2 = Vector2(1000, 1000)


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	# Catch anything already present when this autoload initializes.
	_scan(get_tree().root)


func _scan(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_scan(child)


func _on_node_added(node: Node) -> void:
	if not enabled or not (node is BaseButton):
		return
	var button := node as BaseButton
	if button.has_meta(Juice.NO_AUTO_JUICE):
		return
	# Wire once. Reparenting fires node_added again; `is_connected` can't
	# be used as the guard here because `_on_button_down.bind(button)`
	# produces a distinct Callable on every call, so it never matches a
	# previously-connected one — an explicit meta flag is the only
	# reliable "already wired" marker.
	if button.has_meta(&"_uipolish_wired"):
		return
	button.set_meta(&"_uipolish_wired", true)
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))
	button.pressed.connect(_on_button_pressed.bind(button))


## Re-checked on every press, not just at wire time: node_added fires
## when a node ENTERS the tree, which happens before any script's
## _ready() runs (children enter before parent _ready(), and _ready()
## itself runs bottom-up after entry). A screen that sets
## Juice.NO_AUTO_JUICE inside its own _ready() (as the brief's
## AturJadwal opt-out does) therefore always sets it AFTER this
## autoload has already seen node_added and wired the button — the
## meta is missing at wire time no matter how early in _ready() it's
## set. Checking again here, at the moment of an actual press, is what
## makes the opt-out effective despite that ordering.
func _skip(button: BaseButton) -> bool:
	if button.has_meta(Juice.NO_AUTO_JUICE):
		return true
	return button.size.x > max_juiced_size.x or button.size.y > max_juiced_size.y


func _on_button_down(button: BaseButton) -> void:
	if _skip(button):
		return
	Juice.press(button)


func _on_button_up(button: BaseButton) -> void:
	if _skip(button):
		return
	Juice.release(button)


func _on_button_pressed(button: BaseButton) -> void:
	if _skip(button):
		return
	AudioDirector.play_sfx(&"tap")
