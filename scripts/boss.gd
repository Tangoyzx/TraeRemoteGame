class_name Boss
extends Enemy

# Boss reuses Enemy movement, health, damage, and death behavior.
var boss_name := "Boss"

func _ready() -> void:
	super()
	add_to_group("boss")

func apply_config(config: Dictionary) -> void:
	super(config)
	boss_name = str(config.get("boss_name", boss_name))
