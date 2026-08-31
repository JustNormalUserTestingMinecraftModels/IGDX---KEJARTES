extends BaseMinigame

## SeniBudaya minigame: drag each of the four batik tools (Pencil,
## Canting, Pewarna, Kompor) onto the cloth canvas in the correct order
## (correct_sequence), revealing one pattern layer per correct step.
##
## Winning feeds the SeniBudaya stat (see StudentData.apply_minigame_result);
## a wrong tool marks that step failed (has_failed) without ending the
## game outright.

# ─── Tool 0 (Pencil) ─────────────────────────────────────────────────────────
@export_group("Tool 0 (Pencil)")
## Name shown on the Pencil tool slot and its tooltip.
@export var tool0_display_name: String = "Specialized Pencil"
## Tooltip body text for the Pencil tool.
@export_multiline var tool0_description: String = "Pengadaan akan sketsa pola awal untuk membuat pola yang kelihatan jelas diatas kain kosong."

# ─── Tool 1 (Canting) ────────────────────────────────────────────────────────
@export_group("Tool 1 (Canting)")
## Name shown on the Canting tool slot and its tooltip.
@export var tool1_display_name: String = "Canting"
## Tooltip body text for the Canting tool.
@export_multiline var tool1_description: String = "Alat untuk menggambar motif batik menggunakan malam (lilin) cair di atas kain."

# ─── Tool 2 (Pewarna) ────────────────────────────────────────────────────────
@export_group("Tool 2 (Pewarna)")
## Name shown on the Pewarna tool slot and its tooltip.
@export var tool2_display_name: String = "Pewarna"
## Tooltip body text for the Pewarna tool.
@export_multiline var tool2_description: String = "Larutan zat warna yang digunakan untuk mewarnai kain batik setelah motif selesai."

# ─── Tool 3 (Kompor) ─────────────────────────────────────────────────────────
@export_group("Tool 3 (Kompor)")
## Name shown on the Kompor tool slot and its tooltip.
@export var tool3_display_name: String = "Kompor"
## Tooltip body text for the Kompor tool.
@export_multiline var tool3_description: String = "Digunakan untuk memanaskan kain agar lilin meleleh dan warna meresap sempurna."

# ─── Visual - Background & Canvas ───────────────────────────────────────────
@export_group("Visual - Background & Canvas")
## Drag a PNG here for the minigame background image.
@export var background_texture: Texture2D = null
## Background fill used when background_texture is null.
@export var background_color: Color = Color(0.12, 0.08, 0.05, 1)
## Drag a PNG here for the batik cloth canvas texture.
@export var canvas_cloth_texture: Texture2D = null
## Canvas fill used when canvas_cloth_texture is null.
@export var canvas_cloth_color: Color = Color(0.94, 0.88, 0.73, 1)

# ─── Visual - Tool PNG Assets ───────────────────────────────────────────────
@export_group("Visual - Tool PNG Assets")
## PNG icon for Pencil (Tool 0)
@export var tool0_texture: Texture2D = null
## PNG icon for Canting (Tool 1)
@export var tool1_texture: Texture2D = null
## PNG icon for Pewarna (Tool 2)
@export var tool2_texture: Texture2D = null
## PNG icon for Kompor (Tool 3)
@export var tool3_texture: Texture2D = null
## Card background PNG for tool slots
@export var tool_slot_bg_texture: Texture2D = null
## Tint on drag/pressed
@export var tool_pressed_tint: Color = Color(0.65, 0.65, 0.65, 1.0)
## Scale a tool icon shrinks to on press.
@export var tool_press_scale: float = 0.90

# ─── Visual - Batik Step Pattern Layers ─────────────────────────────────────
@export_group("Visual - Batik Step Pattern Layers")
## Pattern PNG rendered on cloth after Pencil step
@export var layer0_pattern_texture: Texture2D = null
## Pattern PNG rendered on cloth after Canting step
@export var layer1_pattern_texture: Texture2D = null
## Pattern PNG rendered on cloth after Pewarna step
@export var layer2_pattern_texture: Texture2D = null
## Pattern PNG rendered on cloth after Kompor step
@export var layer3_pattern_texture: Texture2D = null

# ─── Visual - Tooltip & Typography ──────────────────────────────────────────
@export_group("Visual - Tooltip & Typography")
## Background for the tool tooltip panel. Null keeps the theme's default.
@export var tooltip_bg_texture: Texture2D = null
## Optional font override applied across the game. Null keeps the theme default.
@export var font: Font = null
## Font size for the game's title label.
@export var title_font_size: int = 48
## Font size for the on-screen instruction text.
@export var instruction_font_size: int = 30
## Font size for the "Lapisan ..." progress label.
@export var progress_font_size: int = 30
## Font size for the tooltip's tool name.
@export var tooltip_name_font_size: int = 40
## Font size for the tooltip's description text.
@export var tooltip_desc_font_size: int = 30
## Text colour for the title label.
@export var title_font_color: Color = Color(1.0, 0.92, 0.75, 1)
## Text colour for the instruction text.
@export var instruction_font_color: Color = Color(0.8, 0.75, 0.6, 1)
## Text colour for the tooltip's tool name.
@export var tooltip_name_color: Color = Color(1.0, 0.92, 0.75, 1)
## Text colour for the tooltip's description.
@export var tooltip_desc_color: Color = Color(0.85, 0.85, 0.85, 1)

# ─── Layer display colors per step ──────────────────────────────────────────
const LAYER_COLORS: Array = [
	Color(0.5, 0.5, 0.5, 0.6),      # Step 1: pencil grey
	Color(0.35, 0.22, 0.12, 0.6),   # Step 2: warm wax brown
	Color(0.18, 0.28, 0.72, 0.55),  # Step 3: dye blue
	Color(0.85, 0.60, 0.15, 0.5),   # Step 4: heat gold
]
const LAYER_LABELS: Array = ["Lapisan Sketsa", "Lapisan Malam", "Lapisan Warna", "Lapisan Pemanasan"]
const WRONG_LAYER_COLOR: Color = Color(0.8, 0.1, 0.1, 0.45)

# ─── Correct sequence ────────────────────────────────────────────────────────
var correct_sequence: Array = ["Tool0", "Tool1", "Tool2", "Tool3"]
var player_sequence: Array = []
var has_failed: bool = false
var auto_revealed_steps: Array = []   # Array of step indices placed by reveal_answers

# ─── Scene nodes ─────────────────────────────────────────────────────────────
@onready var canvas_rect: Control = $CanvasRect
@onready var layers_container: Control = $CanvasRect/LayersContainer
@onready var progress_steps_label: Label = $CanvasRect/ProgressStepsLabel
@onready var tools_container: HBoxContainer = $ToolsContainer
@onready var tooltip_panel: PanelContainer = $TooltipPanel
@onready var tooltip_name: Label = $TooltipPanel/MarginContainer/TooltipVBox/TooltipName
@onready var tooltip_desc: Label = $TooltipPanel/MarginContainer/TooltipVBox/TooltipDesc

# ─── Drag state ──────────────────────────────────────────────────────────────
var active_tool: Control = null
var active_tool_name: String = ""
var active_tool_start_pos: Vector2
var active_tool_start_local: Vector2
var drag_ghost: Control = null   # floating visual during drag

# ─── Tooltip hold state ──────────────────────────────────────────────────────
var hold_timer: float = 0.0
const HOLD_DURATION: float = 0.5
var hovered_tool: Control = null
var tooltip_visible: bool = false
var tooltip_tween: Tween = null

func _ready() -> void:
	super._ready()
	if not has_time_limit:
		start_minigame(1, 30.0)
	tooltip_panel.visible = false
	tooltip_panel.modulate.a = 0.0
	
	# Scramble the layout order of tools
	randomize()
	var tools = tools_container.get_children()
	for s in range(3):
		tools.shuffle()
	for i in range(tools.size()):
		tools_container.move_child(tools[i], i)
	
	# Prevent tooltip panel and its children from blocking mouse inputs to tools
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin = tooltip_panel.get_node_or_null("MarginContainer")
	if margin:
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vbox = tooltip_panel.get_node_or_null("MarginContainer/TooltipVBox")
	if vbox:
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tooltip_name:
		tooltip_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tooltip_desc:
		tooltip_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	for i in range(tools_container.get_child_count()):
		var tool = tools_container.get_child(i)
		tool.mouse_filter = Control.MOUSE_FILTER_STOP
		tool.gui_input.connect(_on_tool_gui_input.bind(tool))
		tool.mouse_entered.connect(_on_tool_mouse_entered.bind(tool))
		tool.mouse_exited.connect(_on_tool_mouse_exited.bind(tool))
		
		# Prevent tool children (Bg ColorRect, IconLabel) from stealing input focus
		for child in tool.get_children():
			if child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_apply_visual_exports()
	_update_progress_label()

func _apply_visual_exports() -> void:
	# Background
	var bg_node = get_node_or_null("Background")
	if bg_node:
		if background_texture:
			if bg_node is ColorRect:
				var tex_rect = TextureRect.new()
				tex_rect.name = "Background"
				tex_rect.texture = background_texture
				tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
				tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				add_child(tex_rect)
				move_child(tex_rect, 0)
				bg_node.queue_free()
		elif bg_node is ColorRect:
			bg_node.color = background_color

	# Cloth canvas
	var canvas_bg = get_node_or_null("CanvasRect/CanvasBackground")
	if canvas_bg:
		if canvas_cloth_texture:
			if canvas_bg is ColorRect:
				var tex_rect = TextureRect.new()
				tex_rect.name = "CanvasBackground"
				tex_rect.texture = canvas_cloth_texture
				tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
				tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				canvas_rect.add_child(tex_rect)
				canvas_rect.move_child(tex_rect, 0)
				canvas_bg.queue_free()
		elif canvas_bg is ColorRect:
			canvas_bg.color = canvas_cloth_color

	# Tool textures
	var tool_texs = [tool0_texture, tool1_texture, tool2_texture, tool3_texture]
	for i in range(min(4, tools_container.get_child_count())):
		var tool_node = tools_container.get_child(i)
		var icon_lbl = tool_node.get_node_or_null("IconLabel") as Label
		var tool_tex = tool_texs[i]
		if tool_tex:
			if icon_lbl: icon_lbl.visible = false
			var tex_rect = tool_node.get_node_or_null("ToolTextureRect") as TextureRect
			if not tex_rect:
				tex_rect = TextureRect.new()
				tex_rect.name = "ToolTextureRect"
				tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tool_node.add_child(tex_rect)
			tex_rect.texture = tool_tex

	# Tooltip style
	if tooltip_panel and tooltip_bg_texture:
		var sb = StyleBoxTexture.new()
		sb.texture = tooltip_bg_texture
		tooltip_panel.add_theme_stylebox_override("panel", sb)

	# Fonts
	var title_lbl = get_node_or_null("TitleLabel") as Label
	if title_lbl:
		title_lbl.add_theme_font_size_override("font_size", title_font_size)
		title_lbl.add_theme_color_override("font_color", title_font_color)
		if font: title_lbl.add_theme_font_override("font", font)

	var inst_lbl = get_node_or_null("InstructionLabel") as Label
	if inst_lbl:
		inst_lbl.add_theme_font_size_override("font_size", instruction_font_size)
		inst_lbl.add_theme_color_override("font_color", instruction_font_color)
		if font: inst_lbl.add_theme_font_override("font", font)

	if progress_steps_label:
		progress_steps_label.add_theme_font_size_override("font_size", progress_font_size)
		if font: progress_steps_label.add_theme_font_override("font", font)

	if tooltip_name:
		tooltip_name.add_theme_font_size_override("font_size", tooltip_name_font_size)
		tooltip_name.add_theme_color_override("font_color", tooltip_name_color)
		if font: tooltip_name.add_theme_font_override("font", font)

	if tooltip_desc:
		tooltip_desc.add_theme_font_size_override("font_size", tooltip_desc_font_size)
		tooltip_desc.add_theme_color_override("font_color", tooltip_desc_color)
		if font: tooltip_desc.add_theme_font_override("font", font)

func _process(delta: float) -> void:
	super._process(delta)
	if not is_game_active:
		return

	# Update drag ghost position & tooltip position during drag
	if active_tool:
		var mouse_pos = get_global_mouse_position()
		if drag_ghost:
			var offset = (drag_ghost.size * drag_ghost.scale) / 2.0
			drag_ghost.global_position = mouse_pos - offset
		_update_tooltip_position(mouse_pos)
	else:
		# Hover hold-to-tooltip timer (for desktop mouse hover)
		if hovered_tool:
			hold_timer += delta
			if hold_timer >= HOLD_DURATION and not tooltip_visible:
				_show_tooltip(hovered_tool)
		else:
			if tooltip_visible and not active_tool:
				_hide_tooltip()
			hold_timer = 0.0

func _on_tool_mouse_entered(tool: Control) -> void:
	if active_tool:
		return
	hovered_tool = tool
	hold_timer = 0.0

func _on_tool_mouse_exited(tool: Control) -> void:
	if hovered_tool == tool:
		hovered_tool = null
		hold_timer = 0.0
		if tooltip_visible and not active_tool:
			_hide_tooltip()

func _update_tooltip_position(at_pos: Vector2) -> void:
	if not tooltip_panel or not tooltip_visible:
		return
	
	# Clamp position so tooltip stays within screen bounds
	var vp_size = get_viewport_rect().size
	var tooltip_size = tooltip_panel.size
	
	# Position slightly above the finger/cursor offset
	var target_x = at_pos.x - tooltip_size.x / 2.0
	var target_y = at_pos.y - tooltip_size.y - 130.0
	
	# If dragging near the top of the screen, place below finger instead
	if target_y < 10.0:
		target_y = at_pos.y + 130.0

	target_x = clampf(target_x, 10.0, maxf(10.0, vp_size.x - tooltip_size.x - 10.0))
	target_y = clampf(target_y, 10.0, maxf(10.0, vp_size.y - tooltip_size.y - 10.0))

	tooltip_panel.global_position = Vector2(target_x, target_y)

func _show_tooltip(tool: Control) -> void:
	tooltip_visible = true
	tooltip_panel.visible = true
	var tool_name_str = ""
	var tool_desc_str = ""
	match tool.name:
		"Tool0":
			tool_name_str = tool0_display_name
			tool_desc_str = tool0_description
		"Tool1":
			tool_name_str = tool1_display_name
			tool_desc_str = tool1_description
		"Tool2":
			tool_name_str = tool2_display_name
			tool_desc_str = tool2_description
		"Tool3":
			tool_name_str = tool3_display_name
			tool_desc_str = tool3_description

	tooltip_name.text = "🔧 " + tool_name_str
	tooltip_desc.text = tool_desc_str
	
	# Force label & container size recalculation so tooltip_panel size is up to date
	tooltip_panel.reset_size()

	_update_tooltip_position(get_global_mouse_position())

	if tooltip_tween:
		tooltip_tween.kill()
	tooltip_tween = create_tween()
	tooltip_tween.tween_property(tooltip_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _hide_tooltip() -> void:
	tooltip_visible = false
	if tooltip_tween:
		tooltip_tween.kill()
	tooltip_tween = create_tween()
	tooltip_tween.tween_property(tooltip_panel, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tooltip_tween.tween_callback(func():
		if not tooltip_visible:
			tooltip_panel.visible = false
	)

func _on_tool_gui_input(event: InputEvent, tool: Control) -> void:
	if not is_game_active:
		return
	if tool.get_meta("used", false):
		return

	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed():
		active_tool = tool
		active_tool_name = tool.name
		active_tool_start_pos = tool.global_position
		active_tool_start_local = tool.position

		# Show tooltip immediately when player touches/presses a tool
		_show_tooltip(tool)
		hovered_tool = null

		# Create a ghost copy for dragging
		_create_drag_ghost(tool)

func _input(event: InputEvent) -> void:
	if not is_game_active or not active_tool:
		return

	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if not event.is_pressed():
			_check_tool_drop()

func _create_drag_ghost(tool: Control) -> void:
	if drag_ghost:
		drag_ghost.queue_free()

	# Duplicate the tool node so the ghost exactly mirrors the dragged tool visual
	var ghost = tool.duplicate() as Control
	ghost.name = "DragGhost"
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 10
	ghost.modulate.a = 0.88
	ghost.scale = Vector2(1.1, 1.1)

	# Ensure all nested children in the ghost ignore mouse filter
	for child in ghost.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for sub_child in child.get_children():
				if sub_child is Control:
					sub_child.mouse_filter = Control.MOUSE_FILTER_IGNORE

	drag_ghost = ghost
	add_child(drag_ghost)
	var offset = (drag_ghost.size * drag_ghost.scale) / 2.0
	drag_ghost.global_position = get_global_mouse_position() - offset

func _get_tool_color(tool_name: String) -> Color:
	match tool_name:
		"Tool0": return Color(0.5, 0.5, 0.5, 1)
		"Tool1": return Color(0.65, 0.16, 0.16, 1)
		"Tool2": return Color(0.1, 0.2, 0.6, 1)
		"Tool3": return Color(0.85, 0.75, 0.1, 1)
	return Color.WHITE

func _get_tool_icon(tool_name: String) -> String:
	match tool_name:
		"Tool0": return "✏"
		"Tool1": return "🖊"
		"Tool2": return "🎨"
		"Tool3": return "🔥"
	return "?"

func _check_tool_drop() -> void:
	if not active_tool:
		return

	var dropped_on_canvas = false

	if canvas_rect:
		var canvas_global_rect = canvas_rect.get_global_rect()
		var drop_pos = get_global_mouse_position()
		if canvas_global_rect.has_point(drop_pos):
			dropped_on_canvas = true

	if dropped_on_canvas:
		var step = player_sequence.size()  # 0, 1, or 2
		var expected = correct_sequence[step] if step < correct_sequence.size() else ""

		if active_tool_name == expected:
			# ✅ Correct tool — add a nice layer to the canvas
			player_sequence.append(active_tool_name)
			_add_correct_layer(step)
			active_tool.set_meta("used", true)
			active_tool.modulate.a = 0.35  # dim it visually
		else:
			# ❌ Wrong tool — add a "messed up" layer
			has_failed = true
			player_sequence.append(active_tool_name)
			_add_wrong_layer(step)
			# Force the remaining tools to be used but record failure
			active_tool.set_meta("used", true)
			active_tool.modulate.a = 0.35

		if player_sequence.size() >= correct_sequence.size():
			_on_all_steps_done(not has_failed)
	else:
		# Snap ghost back — just destroy ghost (tool stays in place)
		pass

	# Destroy ghost
	if drag_ghost:
		drag_ghost.queue_free()
		drag_ghost = null

	_hide_tooltip()

	active_tool = null
	active_tool_name = ""
	_update_progress_label()

func _add_correct_layer(step: int) -> void:
	# Hide previous layers' labels to prevent overlapping text
	for child in layers_container.get_children():
		for sub_child in child.get_children():
			if sub_child is Label:
				sub_child.visible = false

	var pattern_texs = [layer0_pattern_texture, layer1_pattern_texture, layer2_pattern_texture, layer3_pattern_texture]
	var step_tex: Texture2D = pattern_texs[step] if step < pattern_texs.size() else null

	var layer: Control
	if step_tex:
		var tex_rect = TextureRect.new()
		tex_rect.texture = step_tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
		layer = tex_rect
	else:
		var rect = ColorRect.new()
		rect.color = LAYER_COLORS[step]
		layer = rect

	layer.set_meta("step_idx", step)
	layer.set_meta("is_wrong", false)
	layer.anchor_right = 1.0
	layer.anchor_bottom = 1.0
	layer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl = Label.new()
	lbl.text = LAYER_LABELS[step]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.anchor_left = 0.0
	lbl.anchor_top = 0.0
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 1.0
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(lbl)

	layers_container.add_child(layer)

	# Animate fade in
	layer.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(layer, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _add_wrong_layer(step: int) -> void:
	# Hide previous layers' labels to prevent overlapping text
	for child in layers_container.get_children():
		for sub_child in child.get_children():
			if sub_child is Label:
				sub_child.visible = false

	var layer = ColorRect.new()
	layer.set_meta("step_idx", step)
	layer.set_meta("is_wrong", true)
	layer.color = WRONG_LAYER_COLOR
	layer.anchor_right = 1.0
	layer.anchor_bottom = 1.0
	layer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl = Label.new()
	lbl.text = "⚠ Urutan Salah!"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.anchor_left = 0.0
	lbl.anchor_top = 0.0
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 1.0
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(lbl)

	layers_container.add_child(layer)

	# Shake effect
	layer.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(layer, "modulate:a", 1.0, 0.3)
	tween.tween_property(layer, "position:x", -8.0, 0.06)
	tween.tween_property(layer, "position:x", 8.0, 0.06)
	tween.tween_property(layer, "position:x", -5.0, 0.05)
	tween.tween_property(layer, "position:x", 0.0, 0.05)

func reveal_answers() -> void:
	is_game_active = false
	_hide_tooltip()

	# Identify all step indices where the player made a mistake
	var wrong_step_indices: Array = []
	for i in range(player_sequence.size()):
		var expected = correct_sequence[i] if i < correct_sequence.size() else ""
		if player_sequence[i] != expected:
			wrong_step_indices.append(i)

	if wrong_step_indices.is_empty():
		return

	await get_tree().create_timer(0.4).timeout

	# 1. SELECTIVE UNDO: Remove ONLY the layers marked as wrong or belonging to wrong steps
	var layers = layers_container.get_children()
	for l in layers:
		var step_idx = l.get_meta("step_idx", -1)
		var is_wrong_layer = l.get_meta("is_wrong", false)
		if is_wrong_layer or step_idx in wrong_step_indices:
			var undo_tween = create_tween()
			undo_tween.tween_property(l, "modulate:a", 0.0, 0.35)
			await undo_tween.finished
			l.queue_free()

	await get_tree().create_timer(0.2).timeout

	# Un-dim tools that were used incorrectly
	for wrong_idx in wrong_step_indices:
		var wrong_tool_name = player_sequence[wrong_idx]
		for child in tools_container.get_children():
			if child.name == wrong_tool_name:
				child.set_meta("used", false)
				child.modulate.a = 1.0

	_update_progress_label()
	await get_tree().create_timer(0.4).timeout

	# 2. AUTO-DRAG correct tools for each missing or incorrect step
	var canvas_center = canvas_rect.get_global_rect().get_center()

	for step in range(correct_sequence.size()):
		# Skip steps where the player already placed the correct tool
		if step < player_sequence.size() and player_sequence[step] == correct_sequence[step] and step not in wrong_step_indices:
			continue

		var target_tool_name = correct_sequence[step]
		var tool_node: Control = null
		for child in tools_container.get_children():
			if child.name == target_tool_name:
				tool_node = child
				break

		if not tool_node:
			continue

		var start_pos = tool_node.get_global_rect().get_center()

		# Create smooth animated ghost duplicating the tool node so visuals match 100%
		var auto_ghost = tool_node.duplicate() as Control
		auto_ghost.name = "AutoDragGhost"
		auto_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		auto_ghost.z_index = 20
		auto_ghost.modulate.a = 0.88
		auto_ghost.scale = Vector2(1.1, 1.1)

		for child in auto_ghost.get_children():
			if child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
				for sub_child in child.get_children():
					if sub_child is Control:
						sub_child.mouse_filter = Control.MOUSE_FILTER_IGNORE

		add_child(auto_ghost)
		var ghost_offset = (auto_ghost.size * auto_ghost.scale) / 2.0
		auto_ghost.global_position = start_pos - ghost_offset

		# Show tooltip for target tool during auto drag
		_show_tooltip(tool_node)
		_update_tooltip_position(start_pos)

		var drag_tween = create_tween().set_parallel(true)
		drag_tween.tween_property(auto_ghost, "global_position", canvas_center - ghost_offset, 0.75)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		
		# Animate tooltip along with auto drag
		var tooltip_target_x = canvas_center.x - tooltip_panel.size.x / 2.0
		var tooltip_target_y = canvas_center.y - tooltip_panel.size.y - 130.0
		drag_tween.tween_property(tooltip_panel, "global_position", Vector2(tooltip_target_x, tooltip_target_y), 0.75)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

		await drag_tween.finished

		_hide_tooltip()
		auto_ghost.queue_free()

		# Apply correct layer & record as auto-revealed step
		if step < player_sequence.size():
			player_sequence[step] = target_tool_name
		else:
			player_sequence.append(target_tool_name)

		if step not in auto_revealed_steps:
			auto_revealed_steps.append(step)

		_add_correct_layer(step)
		tool_node.set_meta("used", true)
		tool_node.modulate.a = 0.35
		_update_progress_label()

		await get_tree().create_timer(0.45).timeout

	# Finished auto-revealing all correct steps — display result failure overlay
	await get_tree().create_timer(0.6).timeout
	_show_result_overlay(false, "Urutan Pembuatan Batik Kurang Tepat!")

func _on_all_steps_done(all_correct: bool) -> void:
	await get_tree().create_timer(0.6).timeout
	if all_correct:
		win_game()
	else:
		reveal_answers()

func _update_progress_label() -> void:
	var done = player_sequence.size()
	var total = correct_sequence.size()
	var text = ""
	for i in range(total):
		if i in auto_revealed_steps:
			text += "🟨 "
		elif i < done:
			var is_correct = (player_sequence[i] == correct_sequence[i])
			text += "✅ " if is_correct else "❌ "
		else:
			text += "⬜ "
	progress_steps_label.text = text.strip_edges()
