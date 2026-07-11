class_name StatMath
extends RefCounted

# 通用属性枚举。详见 docs/skill-system-framework.md §3。
enum Stat { COUNT, FREQUENCY, DAMAGE, AREA, PIERCE, DURATION, SPEED }

# 单属性单技能堆叠上限。
const MAX_STACKS := 5

# 每层基础幅度(百分比类属性用;COUNT/PIERCE 为整数型,不经过此表)。
const _BASE_MAGNITUDE := {
	Stat.COUNT: 1.0,
	Stat.FREQUENCY: 0.15,
	Stat.DAMAGE: 0.25,
	Stat.AREA: 0.20,
	Stat.PIERCE: 1.0,
	Stat.DURATION: 0.30,
	Stat.SPEED: 0.15,
}

# 边际递减系数。详见 docs/skill-system-framework.md §5。
const _DR_DIVISOR := {
	Stat.COUNT: 0.5,
	Stat.FREQUENCY: 0.4,
	Stat.DAMAGE: 0.4,
	Stat.AREA: 0.4,
	Stat.PIERCE: 0.5,
	Stat.DURATION: 0.4,
	Stat.SPEED: 0.4,
}

# 累积增益(加法倍率)。例如 FREQUENCY 堆 5 层返回约 0.466,代表 +46.6%。
# 第 i 层(0 起)贡献 = base / (1 + dr * i)。
# 注意:COUNT/PIERCE 为整数型,本函数不适用,请直接用 clampi(stacks, 0, MAX_STACKS)。
static func total_multiplier(stat: int, stacks: int) -> float:
	if stacks <= 0:
		return 0.0
	var base: float = _BASE_MAGNITUDE.get(stat, 0.0)
	var dr: float = _DR_DIVISOR.get(stat, 0.4)
	var total := 0.0
	for i in range(stacks):
		total += base / (1.0 + dr * float(i))
	return total


static func base_magnitude(stat: int) -> float:
	return _BASE_MAGNITUDE.get(stat, 0.0)


static func dr_divisor(stat: int) -> float:
	return _DR_DIVISOR.get(stat, 0.4)
