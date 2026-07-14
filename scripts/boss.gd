class_name Boss
extends Enemy

# Boss 基类:复用 Enemy 的 hp/damage/speed/radius/take_damage/apply_debuff 全套机制,
# 额外携带 boss_name 用于过场显示。加入 "boss" group 便于后续 boss 专属逻辑扩展。
var boss_name := "Boss"


func _ready() -> void:
	super()
	add_to_group("boss")


func apply_config(config: Dictionary) -> void:
	super(config)
	boss_name = str(config.get("boss_name", boss_name))
