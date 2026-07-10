extends Node2D

const PlayerScene := preload("res://scripts/player.gd")
const EnemyScene := preload("res://scripts/enemy.gd")
const ProjectileScene := preload("res://scripts/projectile.gd")
const AutoShooterScene := preload("res://scripts/weapons/auto_shooter.gd")
const OrbitSwordScene := preload("res://scripts/weapons/orbit_sword.gd")

const VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const MAP_SIZE := Vector2(12800.0, 7200.0)
const MAP_RECT := Rect2(Vector2.ZERO, MAP_SIZE)
const ENEMY_CONFIG := {
	"radius": 18.0,
	"max_hp": 1,
	"damage": 1,
	"speed": 115.0,
	"score_value": 1,
}
const ENEMY_SPAWN_INTERVAL := 0.85
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
var game_over_label: Label
var spawn_timer: Timer
var score := 0
var is_game_over := false


func _ready() -> void:
	randomize()
	_build_world()
	_spawn_player()
	_spawn_weapons()
	_build_ui()
	_build_spawn_timer()
	_update_score_label()


func _unhandled_input(event: InputEvent) -> void:
	if is_game_over or player == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_set_player_target(get_global_mouse_position())
	elif event is InputEventScreenTouch and event.pressed:
		_set_player_target(get_canvas_transform().affine_inverse() * event.position)


func _process(_delta: float) -> void:
	if camera != null and player != null:
		camera.global_position = _clamp_to_map(player.global_position)


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


func _spawn_weapons() -> void:
	var auto_shooter := AutoShooterScene.new()
	auto_shooter.name = "AutoShooter"
	auto_shooter.setup(player, enemies_layer, projectiles_layer, ProjectileScene)
	weapons_layer.add_child(auto_shooter)

	var orbit_sword := OrbitSwordScene.new()
	orbit_sword.name = "OrbitSword"
	orbit_sword.setup(player)
	weapons_layer.add_child(orbit_sword)


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)

	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.position = Vector2(24, 20)
	score_label.add_theme_font_size_override("font_size", 32)
	ui_layer.add_child(score_label)

	game_over_label = Label.new()
	game_over_label.name = "GameOverLabel"
	game_over_label.visible = false
	game_over_label.text = "GAME OVER"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 72)
	game_over_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(game_over_label)


func _build_spawn_timer() -> void:
	spawn_timer = Timer.new()
	spawn_timer.name = "EnemySpawnTimer"
	spawn_timer.wait_time = ENEMY_SPAWN_INTERVAL
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_spawn_enemy)
	add_child(spawn_timer)


func _spawn_enemy() -> void:
	if is_game_over or player == null or enemies_layer.get_child_count() >= MAX_ENEMIES:
		return
	var enemy := EnemyScene.new()
	enemy.apply_config(ENEMY_CONFIG)
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


func _update_score_label() -> void:
	score_label.text = "Score: %d" % score


func _on_player_died() -> void:
	is_game_over = true
	game_over_label.visible = true
	if spawn_timer != null:
		spawn_timer.stop()
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
