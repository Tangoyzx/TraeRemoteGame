class_name BossIntro
extends Node

# Boss 出场过场控制器。
# process_mode = ALWAYS,确保在 get_tree().paused = true 期间仍能驱动镜头。
#
# 时序:
#   FOCUS_IN  0.5s  关闭镜头平滑,tween 镜头到 boss 位置
#   STAY      2.0s  显示 boss 名字 + 镜头震动
#   FOCUS_OUT 0.5s  tween 镜头回到玩家位置
#   DONE      -     隐藏名字,恢复镜头平滑,解暂停
#
# 注意:暂停期间 main._process 不会跑,所以镜头跟随逻辑天然不冲突,
# 这里直接读写 camera.global_position / position_smoothing_enabled。

signal finished

const FOCUS_IN_DURATION := 0.5
const STAY_DURATION := 2.0
const FOCUS_OUT_DURATION := 0.5
const SHAKE_AMPLITUDE := 8.0

enum State { IDLE, FOCUS_IN, STAY, FOCUS_OUT, DONE }

var _camera: Camera2D
var _name_label: Label
var _boss
var _player
var _map_rect: Rect2

var _state: int = State.IDLE
var _timer: float = 0.0
var _tween: Tween
var _focus_origin: Vector2  # 玩家位置(用于 FOCUS_OUT 回归)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func play(boss, camera: Camera2D, name_label: Label, player, map_rect: Rect2) -> void:
	_boss = boss
	_camera = camera
	_name_label = name_label
	_player = player
	_map_rect = map_rect
	_state = State.FOCUS_IN
	_timer = 0.0
	# 关闭引擎内置平滑,改由 tween 精确控制镜头位置
	_camera.position_smoothing_enabled = false
	_focus_origin = _camera.global_position
	# 显示 boss 名字
	if _name_label != null:
		_name_label.text = str(boss.boss_name)
		_name_label.visible = true
	# tween 镜头到 boss(经过 map 边界 clamp)
	# set_pause_mode(APAUSE_PROCESS) 确保暂停期间 tween 仍运行
	var target := _clamp(boss.global_position)
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_camera, "global_position", target, FOCUS_IN_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	if _state == State.IDLE or _state == State.DONE:
		return
	_timer += delta
	match _state:
		State.FOCUS_IN:
			if _timer >= FOCUS_IN_DURATION:
				_state = State.STAY
				_timer = 0.0
		State.STAY:
			# 震动:在 boss 位置附近随机偏移
			if is_instance_valid(_boss):
				var base := _clamp(_boss.global_position)
				_camera.global_position = base + Vector2(
					randf_range(-SHAKE_AMPLITUDE, SHAKE_AMPLITUDE),
					randf_range(-SHAKE_AMPLITUDE, SHAKE_AMPLITUDE)
				)
			if _timer >= STAY_DURATION:
				_state = State.FOCUS_OUT
				_timer = 0.0
				# 隐藏名字
				if _name_label != null:
					_name_label.visible = false
				# tween 回到玩家位置
				var back := _clamp(_player.global_position) if is_instance_valid(_player) else _focus_origin
				_tween = create_tween()
				_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				_tween.tween_property(_camera, "global_position", back, FOCUS_OUT_DURATION)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		State.FOCUS_OUT:
			if _timer >= FOCUS_OUT_DURATION:
				_state = State.DONE
				# 恢复镜头平滑
				if _camera != null:
					_camera.position_smoothing_enabled = true
				if _name_label != null:
					_name_label.visible = false
				finished.emit()
				_state = State.IDLE


func _clamp(pos: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, _map_rect.position.x, _map_rect.end.x),
		clampf(pos.y, _map_rect.position.y, _map_rect.end.y)
	)
