extends Node2D

const PlayerScene := preload("res://scripts/player.gd")
const EnemyScene := preload("res://scripts/enemy.gd")
const ProjectileScene := preload("res://scripts/projectile.gd")
const AutoShooterScene := preload("res://scripts/weapons/auto_shooter.gd")
const OrbitSwordScene := preload("res://scripts/weapons/orbit_sword.gd")
const UpgradeUIFont := preload("uid://cay4nii3rtu3d")

const VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const MAP_SIZE := Vector2(12800.0, 7200.0)
const MAP_RECT := Rect2(Vector2.ZERO, MAP_SIZE)
const DEFAULT_LEVEL_REQUIRED_SCORE := 99999999
const UPGRADE_IMAGE_SIZE := Vector2(100.0, 200.0)
const BASIC_ENEMY_RADIUS := 18.0
const BASIC_ENEMY_SPEED := 115.0
const ENEMY_CONFIGS := {
	"basic": {
		"name": "初级怪",
		"radius": BASIC_ENEMY_RADIUS,
		"max_hp": 1,
		"damage": 1,
		"speed": BASIC_ENEMY_SPEED,
		"score_value": 1,
		"body_color": Color(0.92, 0.20, 0.20, 1.0),
		"outline_color": Color(1.0, 0.68, 0.68, 1.0),
	},
	"chubby": {
		"name": "小胖子",
		"radius": BASIC_ENEMY_RADIUS * 1.2,
		"max_hp": 3,
		"damage": 2,
		"speed": BASIC_ENEMY_SPEED * 0.8,
		"score_value": 2,
		"body_color": Color(0.80, 0.34, 0.95, 1.0),
		"outline_color": Color(0.96, 0.75, 1.0, 1.0),
	},
}
const SPAWN_STRATEGY := [
	{
		"start_time": 0.0,
		"rates": {
			"basic": 20.0,
		},
	},
	{
		"start_time": 20.0,
		"rates": {
			"basic": 40.0,
		},
	},
	{
		"start_time": 40.0,
		"rates": {
			"basic": 40.0,
			"chubby": 10.0,
		},
	},
	{
		"start_time": 60.0,
		"rates": {
			"basic": 40.0,
			"chubby": 10.0,
		},
	},
]
const UPGRADE_OPTIONS := {
	"auto_shooter": {
		"id": "auto_shooter",
		"title": "子弹",
		"description": "自动瞄准最近敌人发射子弹",
		"image_path": "res://assets/upgrades/bullet.svg",
		"weapon_type": "auto_shooter",
	},
	"orbit_sword": {
		"id": "orbit_sword",
		"title": "环绕剑",
		"description": "围绕角色旋转并持续伤害敌人",
		"image_path": "res://assets/upgrades/orbit_sword.svg",
		"weapon_type": "orbit_sword",
	},
}
const LEVEL_CONFIGS := {
	1: {
		"required_score": 0,
		"options": ["auto_shooter", "orbit_sword"],
	},
}
const ENEMY_SPAWN_MARGIN := 140.0
const MAX_ENEMIES := 120

var player: Player
var camera: Camera2D
var world_layer: Node2D
var enemies_layer: Node2D
var projectiles_layer: Node2D
var weapons_layer: Node2D
var ui_layer: CanvasLayer
var score_label: Label
var level_label: Label
var game_over_label: Label
var level_up_overlay: ColorRect
var level_up_title: Label
var level_up_options_box: HBoxContainer
var score := 0
var current_level := 0
var is_game_over := false
var is_level_up_open := false
var elapsed_seconds := 0.0
var _spawn_budgets := {}
var _acquired_upgrades := {}


func _ready() -> void:
	randomize()
	get_tree().paused = false
	_init_spawn_budgets()
	_build_world()
	_spawn_player()
	_build_ui()
	_update_score_label()
	_update_level_label()
	_check_level_up()


func _unhandled_input(event: InputEvent) -> void:
	if is_game_over or is_level_up_open or player == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_set_player_target(get_global_mouse_position())
	elif event is InputEventScreenTouch and event.pressed:
		_set_player_target(get_canvas_transform().affine_inverse() * event.position)


func _process(delta: float) -> void:
	if is_game_over or is_level_up_open:
		return
	elapsed_seconds += delta
	if camera != null and player != null:
		camera.global_position = _clamp_to_map(player.global_position)
	_update_enemy_spawns(delta)


func _build_world() -> void:
	world_layer = Node2D.new()
	world_layer.name = "World"
	add_child(world_layer)
	world_layer.add_child(_create_map_background())
	world_layer.add_child(_create_map_grid())
	world_layer.add_child(_create_map_border())

	enemies_layer = Node2D.new()
	enemies_layer.name = "Enemies"
	add_child(enemies_layer)

	projectiles_layer = Node2D.new()
	projectiles_layer.name = "Projectiles"
	add_child(projectiles_layer)

	weapons_layer = Node2D.new()
	weapons_layer.name = "Weapons"
	add_child(weapons_layer)

	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.enabled = true
	camera.zoom = Vector2.ONE
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(MAP_SIZE.x)
	camera.limit_bottom = int(MAP_SIZE.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 10.0
	add_child(camera)


func _create_map_background() -> Node2D:
	var background := MapBackground.new()
	background.name = "MapBackground"
	background.map_size = MAP_SIZE
	return background


func _create_map_grid() -> Node2D:
	var grid := MapGrid.new()
	grid.name = "MapGrid"
	grid.map_size = MAP_SIZE
	grid.cell_size = 320.0
	return grid


func _create_map_border() -> Node2D:
	var border := MapBorder.new()
	border.name = "MapBorder"
	border.map_size = MAP_SIZE
	return border


func _spawn_player() -> void:
	player = PlayerScene.new()
	player.name = "Player"
	player.global_position = MAP_SIZE * 0.5
	player.map_rect = MAP_RECT
	player.died.connect(_on_player_died)
	add_child(player)
	camera.global_position = player.global_position


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_layer)

	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.position = Vector2(24, 20)
	score_label.add_theme_font_size_override("font_size", 32)
	ui_layer.add_child(score_label)

	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.position = Vector2(24, 60)
	level_label.add_theme_font_size_override("font_size", 28)
	ui_layer.add_child(level_label)

	game_over_label = Label.new()
	game_over_label.name = "GameOverLabel"
	game_over_label.visible = false
	game_over_label.text = "GAME OVER"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 72)
	game_over_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(game_over_label)

	_build_level_up_ui()


func _build_level_up_ui() -> void:
	level_up_overlay = ColorRect.new()
	level_up_overlay.name = "LevelUpOverlay"
	level_up_overlay.visible = false
	level_up_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	level_up_overlay.color = Color(0.0, 0.0, 0.0, 0.70)
	level_up_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_up_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(level_up_overlay)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	level_up_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(720, 390)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	content.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_child(content)

	level_up_title = Label.new()
	level_up_title.name = "Title"
	level_up_title.text = "升级！选择一个强化"
	level_up_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_up_title.add_theme_font_override("font", UpgradeUIFont)
	level_up_title.add_theme_font_size_override("font_size", 34)
	content.add_child(level_up_title)

	level_up_options_box = HBoxContainer.new()
	level_up_options_box.name = "Options"
	level_up_options_box.alignment = BoxContainer.ALIGNMENT_CENTER
	level_up_options_box.add_theme_constant_override("separation", 28)
	level_up_options_box.process_mode = Node.PROCESS_MODE_ALWAYS
	content.add_child(level_up_options_box)


func _init_spawn_budgets() -> void:
	for enemy_type in ENEMY_CONFIGS.keys():
		_spawn_budgets[enemy_type] = 0.0


func _update_enemy_spawns(delta: float) -> void:
	if player == null or enemies_layer == null or enemies_layer.get_child_count() >= MAX_ENEMIES:
		return
	var rates := _get_current_spawn_rates()
	for enemy_type in rates.keys():
		if not ENEMY_CONFIGS.has(enemy_type):
			continue
		_spawn_budgets[enemy_type] = float(_spawn_budgets.get(enemy_type, 0.0)) + float(rates[enemy_type]) / 60.0 * delta
		while _spawn_budgets[enemy_type] >= 1.0 and enemies_layer.get_child_count() < MAX_ENEMIES:
			_spawn_enemy(enemy_type)
			_spawn_budgets[enemy_type] -= 1.0


func _get_current_spawn_rates() -> Dictionary:
	var current_rates := {}
	for phase in SPAWN_STRATEGY:
		if elapsed_seconds >= float(phase["start_time"]):
			current_rates = phase["rates"]
		else:
			break
	return current_rates


func _spawn_enemy(enemy_type: String) -> void:
	if is_game_over or player == null or enemies_layer.get_child_count() >= MAX_ENEMIES:
		return
	var enemy := EnemyScene.new()
	enemy.apply_config(ENEMY_CONFIGS[enemy_type])
	enemy.global_position = _get_spawn_position_near_view()
	enemy.target = player
	enemy.died.connect(_on_enemy_died)
	enemies_layer.add_child(enemy)


func _get_spawn_position_near_view() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = VIEWPORT_SIZE
	var center := camera.get_screen_center_position() if camera != null else player.global_position
	var half := viewport_size * 0.5
	var side := randi() % 4
	var spawn := center
	match side:
		0:
			spawn.x = center.x - half.x - ENEMY_SPAWN_MARGIN
			spawn.y = randf_range(center.y - half.y, center.y + half.y)
		1:
			spawn.x = center.x + half.x + ENEMY_SPAWN_MARGIN
			spawn.y = randf_range(center.y - half.y, center.y + half.y)
		2:
			spawn.x = randf_range(center.x - half.x, center.x + half.x)
			spawn.y = center.y - half.y - ENEMY_SPAWN_MARGIN
		_:
			spawn.x = randf_range(center.x - half.x, center.x + half.x)
			spawn.y = center.y + half.y + ENEMY_SPAWN_MARGIN
	return _clamp_to_map(spawn)


func _set_player_target(world_position: Vector2) -> void:
	player.set_move_target(_clamp_to_map(world_position))


func _clamp_to_map(world_position: Vector2) -> Vector2:
	return Vector2(
		clampf(world_position.x, MAP_RECT.position.x, MAP_RECT.end.x),
		clampf(world_position.y, MAP_RECT.position.y, MAP_RECT.end.y)
	)


func _on_enemy_died(enemy: Enemy) -> void:
	score += enemy.score_value
	_update_score_label()
	_check_level_up()


func _update_score_label() -> void:
	score_label.text = "Score: %d" % score


func _update_level_label() -> void:
	level_label.text = "Level: %d" % current_level


func _check_level_up() -> void:
	if is_game_over or is_level_up_open:
		return
	var next_level := current_level + 1
	var level_config := _get_level_config(next_level)
	var required_score := int(level_config.get("required_score", DEFAULT_LEVEL_REQUIRED_SCORE))
	var options: Array = level_config.get("options", [])
	if score >= required_score and not options.is_empty():
		_show_level_up_options(next_level, options)


func _get_level_config(level: int) -> Dictionary:
	return LEVEL_CONFIGS.get(level, {
		"required_score": DEFAULT_LEVEL_REQUIRED_SCORE,
		"options": [],
	})


func _show_level_up_options(level: int, option_ids: Array) -> void:
	is_level_up_open = true
	level_up_title.text = "等级 %d - 选择一个强化" % level
	for child in level_up_options_box.get_children():
		child.queue_free()
	for option_id in option_ids:
		if not UPGRADE_OPTIONS.has(option_id):
			continue
		level_up_options_box.add_child(_create_upgrade_card(option_id))
	level_up_overlay.visible = true
	get_tree().paused = true


func _create_upgrade_card(option_id: String) -> Control:
	var option: Dictionary = UPGRADE_OPTIONS[option_id]
	var card := VBoxContainer.new()
	card.name = "Upgrade_%s" % str(option.get("id", option_id))
	card.custom_minimum_size = Vector2(180, 300)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 8)
	card.process_mode = Node.PROCESS_MODE_ALWAYS

	var title := Label.new()
	title.text = str(option["title"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font", UpgradeUIFont)
	title.add_theme_font_size_override("font_size", 24)
	card.add_child(title)

	var image_button := TextureButton.new()
	image_button.name = "ImageButton"
	image_button.custom_minimum_size = UPGRADE_IMAGE_SIZE
	image_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	image_button.ignore_texture_size = true
	image_button.texture_normal = load(str(option["image_path"]))
	image_button.process_mode = Node.PROCESS_MODE_ALWAYS
	image_button.pressed.connect(_choose_upgrade.bind(option_id))
	card.add_child(image_button)

	var description := Label.new()
	description.text = str(option["description"])
	description.custom_minimum_size = Vector2(170, 0)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_override("font", UpgradeUIFont)
	description.add_theme_font_size_override("font_size", 16)
	card.add_child(description)

	return card


func _choose_upgrade(option_id: String) -> void:
	_apply_upgrade(option_id)
	current_level += 1
	_update_level_label()
	level_up_overlay.visible = false
	is_level_up_open = false
	get_tree().paused = false
	_check_level_up()


func _apply_upgrade(option_id: String) -> void:
	if _acquired_upgrades.has(option_id):
		return
	_acquired_upgrades[option_id] = true
	var option: Dictionary = UPGRADE_OPTIONS.get(option_id, {})
	match str(option.get("weapon_type", "")):
		"auto_shooter":
			_create_auto_shooter()
		"orbit_sword":
			_create_orbit_sword()


func _create_auto_shooter() -> void:
	var auto_shooter := AutoShooterScene.new()
	auto_shooter.name = "AutoShooter"
	auto_shooter.setup(player, enemies_layer, projectiles_layer, ProjectileScene)
	weapons_layer.add_child(auto_shooter)


func _create_orbit_sword() -> void:
	var orbit_sword := OrbitSwordScene.new()
	orbit_sword.name = "OrbitSword"
	orbit_sword.setup(player)
	weapons_layer.add_child(orbit_sword)


func _on_player_died() -> void:
	is_game_over = true
	is_level_up_open = false
	get_tree().paused = false
	if level_up_overlay != null:
		level_up_overlay.visible = false
	game_over_label.visible = true
	get_tree().call_group("enemy", "set_process", false)
	get_tree().call_group("projectile", "queue_free")
	get_tree().call_group("weapon", "set_process", false)


class MapBackground:
	extends Node2D

	var map_size := Vector2.ZERO

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.07, 0.09, 0.10, 1.0), true)


class MapGrid:
	extends Node2D

	var map_size := Vector2.ZERO
	var cell_size := 320.0

	func _draw() -> void:
		var grid_color := Color(0.16, 0.19, 0.20, 0.45)
		var x := 0.0
		while x <= map_size.x:
			draw_line(Vector2(x, 0.0), Vector2(x, map_size.y), grid_color, 2.0)
			x += cell_size
		var y := 0.0
		while y <= map_size.y:
			draw_line(Vector2(0.0, y), Vector2(map_size.x, y), grid_color, 2.0)
			y += cell_size


class MapBorder:
	extends Node2D

	var map_size := Vector2.ZERO

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.65, 0.72, 0.78, 1.0), false, 8.0)
