@tool
extends Node

## Global audio. Autoloaded as `AudioDirector` from
## Scenes/Audio/audio_director.tscn so every stream slot is assignable
## in the inspector — drop an .ogg on a slot, no code changes.
##
## Every slot may be null. Nothing here crashes on a null stream; it
## simply plays nothing. That is deliberate: the project ships with
## empty slots and the user fills them in over time.

const SFX_POOL_SIZE := 12
const SETTINGS_PATH := "user://audio.cfg"

@export_group("SFX")
@export var sfx_tap: AudioStream
@export var sfx_confirm: AudioStream
@export var sfx_cancel: AudioStream
@export var sfx_success: AudioStream
@export var sfx_fail: AudioStream
@export var sfx_coin: AudioStream
@export var sfx_whoosh: AudioStream
@export var sfx_pop: AudioStream
@export var sfx_swipe: AudioStream
@export var sfx_stamp: AudioStream
@export var sfx_unstamp: AudioStream
@export var sfx_popup_open: AudioStream
@export var sfx_popup_close: AudioStream
@export var sfx_select: AudioStream
@export var sfx_error: AudioStream
@export var sfx_reward: AudioStream

@export_group("BGM")
@export var bgm_titlescreen: AudioStream
@export var bgm_introcutscene: AudioStream
@export var bgm_lobby: AudioStream
@export var bgm_simulation: AudioStream
@export var bgm_result_win: AudioStream
@export var bgm_result_lose: AudioStream

@export_group("Mixing")
## Default crossfade for play_bgm/stop_bgm when no explicit fade is given.
@export var default_bgm_fade: float = 0.8
## Random pitch spread on each SFX so repeated taps do not sound robotic.
@export_range(0.0, 0.3) var sfx_pitch_variance: float = 0.06

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _bgm_a: AudioStreamPlayer
var _bgm_b: AudioStreamPlayer
var _bgm_active: AudioStreamPlayer
var _bgm_current_id: StringName = &""
var _bgm_tween: Tween
var _save_timer: SceneTreeTimer
var _save_count: int = 0
var _setup_ran: bool = false


func _ready() -> void:
	# @tool makes this script a "real" instance (not a placeholder) when the
	# in-editor test runner instantiates audio_director.tscn programmatically
	# and parents it under Engine.get_main_loop().root — that path must keep
	# running full setup so tests can exercise it.
	#
	# But @tool ALSO means _ready() fires for real when a human just opens
	# Scenes/Audio/audio_director.tscn in the editor (e.g. to drag an .ogg
	# onto a slot, per Assets/Audio/README.md). In that case this node IS
	# (or is inside) the editor's edited-scene tree, and running setup would
	# spawn live AudioStreamPlayers in the editor and let _load_volumes()/
	# _save_volumes() read and overwrite the real user://audio.cfg just from
	# having the scene open. Skip setup only for that case.
	if Engine.is_editor_hint():
		var tree := get_tree()
		var edited_root: Node = tree.edited_scene_root if tree else null
		if edited_root != null and (self == edited_root or edited_root.is_ancestor_of(self)):
			return

	_setup_ran = true
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx_pool.append(p)

	_bgm_a = _make_bgm_player()
	_bgm_b = _make_bgm_player()
	_bgm_active = _bgm_a

	_load_volumes()


func _make_bgm_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"BGM"
	add_child(p)
	return p


# -------------------------------------------------------------------- sfx

func play_sfx(id: StringName) -> void:
	var stream := _resolve_sfx(id)
	if stream == null:
		return
	var player := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-sfx_pitch_variance, sfx_pitch_variance)
	player.play()


func _resolve_sfx(id: StringName) -> AudioStream:
	match id:
		&"tap": return sfx_tap
		&"confirm": return sfx_confirm
		&"cancel": return sfx_cancel
		&"success": return sfx_success
		&"fail": return sfx_fail
		&"coin": return sfx_coin
		&"whoosh": return sfx_whoosh
		&"pop": return sfx_pop
		&"swipe": return sfx_swipe
		&"stamp": return sfx_stamp
		&"unstamp": return sfx_unstamp
		&"popup_open": return sfx_popup_open
		&"popup_close": return sfx_popup_close
		&"select": return sfx_select
		&"error": return sfx_error
		&"reward": return sfx_reward
		_: return null


## True only when `id` maps to a slot AND that slot holds a stream.
## Screens never need this — play_sfx is already null-safe — but tests
## and the audio-coverage suite use it to prove a slot got filled.
func has_sfx(id: StringName) -> bool:
	return _resolve_sfx(id) != null


# -------------------------------------------------------------------- bgm

func play_bgm(id: StringName, fade: float = -1.0) -> void:
	if id == _bgm_current_id and _bgm_active.playing:
		return
	var stream := _resolve_bgm(id)
	if stream == null:
		_bgm_current_id = id
		return

	var duration := default_bgm_fade if fade < 0.0 else fade
	var incoming := _bgm_b if _bgm_active == _bgm_a else _bgm_a
	var outgoing := _bgm_active

	incoming.stream = stream
	incoming.volume_db = -60.0
	incoming.play()

	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween().set_parallel(true)
	_bgm_tween.tween_property(incoming, "volume_db", 0.0, duration)
	_bgm_tween.tween_property(outgoing, "volume_db", -60.0, duration)
	_bgm_tween.chain().tween_callback(outgoing.stop)

	_bgm_active = incoming
	_bgm_current_id = id


func stop_bgm(fade: float = -1.0) -> void:
	var duration := default_bgm_fade if fade < 0.0 else fade
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_active, "volume_db", -60.0, duration)
	_bgm_tween.tween_callback(_bgm_active.stop)
	_bgm_current_id = &""


func _resolve_bgm(id: StringName) -> AudioStream:
	match id:
		&"titlescreen": return bgm_titlescreen
		&"introcutscene": return bgm_introcutscene
		&"lobby": return bgm_lobby
		&"simulation": return bgm_simulation
		&"result_win": return bgm_result_win
		&"result_lose": return bgm_result_lose
		_: return null


# ------------------------------------------------------------------ mixing

## Set a bus volume as a 0.0-1.0 linear value. Clamped. Persisted.
func set_bus_volume(bus: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		push_warning("AudioDirector: unknown bus " + String(bus))
		return
	var v := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(v))
	# linear_to_db(0.0) is -inf, which AudioServer stores but which reads
	# back as -inf; mute the bus instead so get_bus_volume returns 0.0.
	AudioServer.set_bus_mute(idx, is_zero_approx(v))
	_schedule_volume_save()


func get_bus_volume(bus: StringName) -> float:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return 0.0
	if AudioServer.is_bus_mute(idx):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(idx)), 0.0, 1.0)


func _save_volumes() -> void:
	_save_count += 1
	var cfg := ConfigFile.new()
	for bus in ["Master", "BGM", "SFX"]:
		cfg.set_value("volume", bus, get_bus_volume(bus))
	cfg.save(SETTINGS_PATH)


## Coalesce a burst of slider changes into one disk write. Dragging a
## slider fires value_changed per pixel; writing user://audio.cfg that
## often stutters on mobile storage.
func _schedule_volume_save() -> void:
	if _save_timer != null:
		return
	# _schedule_volume_save is only reached via set_bus_volume, and
	# _load_volumes() (the only caller before user interaction) runs from
	# _ready() once this node is already inside the tree, so get_tree()
	# is always valid here.
	var tree := get_tree()
	_save_timer = tree.create_timer(0.4, true, false, true)
	_save_timer.timeout.connect(func() -> void:
		_save_timer = null
		_save_volumes())


## Write any pending volume change immediately. Called on quit and by
## tests that need the file on disk before reading it back.
func flush_volume_save() -> void:
	_save_timer = null
	_save_volumes()


## Number of times the config has actually been written. Test hook.
func get_volume_save_count() -> int:
	return _save_count


func _notification(what: int) -> void:
	# Guard mirrors _ready(): if setup never ran (this instance is merely
	# sitting in an edited scene in the editor), there is nothing pending
	# to flush and doing so would read/write the real user://audio.cfg
	# just from the scene being open, e.g. on an editor focus-loss pause.
	if not _setup_ran:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		flush_volume_save()


func _load_volumes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for bus in ["Master", "BGM", "SFX"]:
		set_bus_volume(bus, cfg.get_value("volume", bus, 1.0))
