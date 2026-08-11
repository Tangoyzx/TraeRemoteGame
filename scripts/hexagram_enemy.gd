class_name HexagramEnemy
extends RangedEnemy

# 六芒星敌方单位:可分裂,有近战(白)/远程(蓝)两态。
# 信号在分裂抖动结束时发射,由 main.gd 接收以生成同组子单位。
signal split_completed(parent: HexagramEnemy, child_form: String)

const FIRST_SPLIT_INTERVAL := 4.0
const SPLIT_INTERVAL := 10.0
const SHAKE_DURATION := 2.0
const RANGED_FORM_PROBABILITY := 0.50
const SHAKE_OFFSET := 2.5
const FLASH_FREQUENCY := 8.0

var form := "melee"
var group_id := -1

var _split_timer := 0.0
# 首次分裂等待更短,让玩家早见识分裂机制;分裂触发后切换为常规周期
var _split_threshold := FIRST_SPLIT_INTERVAL
var _shaking := false
var _shake_elapsed := 0.0
var _flash_time := 0.0
var _pending_child_form := "melee"
var _flash_red := false


func _ready() -> void:
	super()
	add_to_group("hexagram")


func apply_config(config: Dictionary) -> void:
	super(config)
	form = str(config.get("form", "melee"))


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	# 抖动期间原地停移,只推进抖动计时与红闪动画
	if _shaking:
		_shake_elapsed += delta
		_flash_time += delta
		queue_redraw()
		if _shake_elapsed >= SHAKE_DURATION:
			_finish_split()
		return
	# 移动:近战=追击(自带麻痹判断);远程=复用 RangedEnemy._process(含移动+开火)
	if form == "melee":
		if not is_paralyzed():
			var offset := target.global_position - global_position
			if offset.length() > 1.0:
				global_position += offset.normalized() * speed * delta
	else:
		super(delta)
	# 分裂计时(麻痹期间也推进,分裂为内部机制)
	_split_timer += delta
	if _split_timer >= _split_threshold:
		_split_timer = 0.0
		# 首次分裂后切换为常规周期,后续每 10 秒分裂一次
		_split_threshold = SPLIT_INTERVAL
		_start_split()


func _start_split() -> void:
	_shaking = true
	_shake_elapsed = 0.0
	_flash_time = 0.0
	var roll := randf()
	_pending_child_form = "ranged" if roll < RANGED_FORM_PROBABILITY else "melee"
	# 仅当即将分裂出远程形态时叠加红闪预警
	_flash_red = (_pending_child_form == "ranged")
	queue_redraw()


func _finish_split() -> void:
	_shaking = false
	_flash_red = false
	var child_form := _pending_child_form
	_pending_child_form = "melee"
	queue_redraw()
	split_completed.emit(self, child_form)


func _draw() -> void:
	var shake_offset := Vector2.ZERO
	if _shaking:
		shake_offset = Vector2(randf_range(-SHAKE_OFFSET, SHAKE_OFFSET), randf_range(-SHAKE_OFFSET, SHAKE_OFFSET))
	draw_set_transform(shake_offset, 0.0, Vector2.ONE)
	var fill_color := body_color
	if _flash_red:
		# 红闪:在体色与警示红之间按频率交替
		var phase := fmod(_flash_time * FLASH_FREQUENCY, 1.0)
		if phase < 0.5:
			fill_color = Color(1.0, 0.18, 0.18, 1.0)
	_draw_hexagram(fill_color, outline_color)
	# 复位变换,避免影响后续帧或其他同节点绘制
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# 六芒星=两个交叠三角形(大卫之星),与现有 _draw_square/_draw_triangle 视觉风格一致
func _draw_hexagram(fill_color: Color, outline_col: Color) -> void:
	var r := radius
	var up := PackedVector2Array([
		Vector2(0.0, -r),
		Vector2(r * 0.866, r * 0.5),
		Vector2(-r * 0.866, r * 0.5),
	])
	var down := PackedVector2Array([
		Vector2(0.0, r),
		Vector2(r * 0.866, -r * 0.5),
		Vector2(-r * 0.866, -r * 0.5),
	])
	draw_colored_polygon(up, fill_color)
	draw_colored_polygon(down, fill_color)
	var outline_up := PackedVector2Array(up)
	outline_up.append(up[0])
	draw_polyline(outline_up, outline_col, 3.0, true)
	var outline_down := PackedVector2Array(down)
	outline_down.append(down[0])
	draw_polyline(outline_down, outline_col, 3.0, true)
