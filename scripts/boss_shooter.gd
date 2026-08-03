class_name BossShooter
extends RangedEnemy

var boss_name := "Triangle Warden"

func _ready() -> void:
	super()
	add_to_group("boss")

func apply_config(config: Dictionary) -> void:
	super(config)
	boss_name = str(config.get("boss_name", boss_name))
