# 技能校准表

本文档把现有技能套进 [skill-system-framework.md](./skill-system-framework.md) 的框架,做基线 DPS 分析、适配系数校准、升级数值规划。数值来自代码常量,改动代码后需同步更新本文。

## 1. 本次校准覆盖

| 技能 | 代码位置 | 类型 |
|---|---|---|
| 子弹 AutoShooter | [scripts/weapons/auto_shooter.gd](../scripts/weapons/auto_shooter.gd) | 瞄准单体直线弹 |
| 环绕剑 OrbitSword | [scripts/weapons/orbit_sword.gd](../scripts/weapons/orbit_sword.gd) | 环绕持续碰撞 |

> 子弹实体见 [scripts/projectile.gd](../scripts/projectile.gd)。

## 2. 基线数值(取自代码常量)

### AutoShooter
| 参数 | 值 | 来源 |
|---|---|---|
| `FIRE_INTERVAL` | 1.10 s | [auto_shooter.gd:4](../scripts/weapons/auto_shooter.gd#L4) |
| `PROJECTILE_DAMAGE` | 1 | [auto_shooter.gd:6](../scripts/weapons/auto_shooter.gd#L6) |
| `PROJECTILE_SPEED` | 520.0 | [auto_shooter.gd:5](../scripts/weapons/auto_shooter.gd#L5) |
| `MUZZLE_OFFSET` | 28.0 | [auto_shooter.gd:7](../scripts/weapons/auto_shooter.gd#L7) |
| 弹体 `RADIUS` | 6.0 | [projectile.gd:4](../scripts/projectile.gd#L4) |
| 弹体 `lifetime` | 2.2 s | [projectile.gd:8](../scripts/projectile.gd#L8) |
| 单发命中 | 销毁(无穿透) | [projectile.gd:31-34](../scripts/projectile.gd#L31-L34) |
| 每次发射弹数 | 1(瞄最近单体) | [auto_shooter.gd:52-63](../scripts/weapons/auto_shooter.gd#L52-L63) |

### OrbitSword
| 参数 | 值 | 来源 |
|---|---|---|
| `DAMAGE` | 1 | [orbit_sword.gd:4](../scripts/weapons/orbit_sword.gd#L4) |
| `ORBIT_RADIUS` | 186.0 | [orbit_sword.gd:5](../scripts/weapons/orbit_sword.gd#L5) |
| `ORBIT_SPEED` | 3.4 rad/s | [orbit_sword.gd:6](../scripts/weapons/orbit_sword.gd#L6) |
| `SIZE` | 52 × 12 | [orbit_sword.gd:7](../scripts/weapons/orbit_sword.gd#L7) |
| `HIT_COOLDOWN_SECONDS` | 0.45 s | [orbit_sword.gd:8](../scripts/weapons/orbit_sword.gd#L8) |
| 剑数 | 1 | [main.gd:472-476](../scripts/main.gd#L472-L476) |

## 3. 基线 DPS 分析

### AutoShooter(单体)
```
DPS = DAMAGE / FIRE_INTERVAL = 1 / 1.10 = 0.909
```
- **有效射程** = `SPEED × lifetime` = 520 × 2.2 = **1144 单位**
- 群体 DPS = 0.909 × min(敌人数, 弹数) = 0.909(弹数=1)
- 定位:**单体聚焦**,DPS 高,群体能力弱

### OrbitSword(环内每个敌人)
旋转周期 = `2π / ORBIT_SPEED` = 2π / 3.4 = **1.848 s/圈**

剑的角宽度 ≈ `长度 / 半径` = 52 / 186 = 0.280 rad,扫过定点耗时 ≈ 0.280 / 3.4 = 0.082 s < `HIT_COOLDOWN` 0.45 s → **每圈每敌只命中 1 次**。
```
DPS(环内单敌) = DAMAGE / 旋转周期 = 1 / 1.848 = 0.541
```
- **覆盖环周长** = 2π × 186 = **1168.7 单位**
- 群体 DPS = 0.541 × N(N = 环内敌人数,无上限)
- 定位:**群体控制**,单敌 DPS 偏低,但群体线性放大

### 基线平衡结论

| 场景 | AutoShooter | OrbitSword | 谁优 |
|---|---|---|---|
| 单体 BOSS | 0.909 | 0.541 | AutoShooter |
| 2 敌人 | 0.909(只打 1 个) | 1.082 | OrbitSword |
| N 敌人(N≥2) | 0.909 | 0.541×N | OrbitSword |

→ **基线平衡健康**:聚焦 vs 控群的角色分工成立,无需调基线。

## 4. 通用属性 → 技能参数映射

### AutoShooter
| 通用属性 | 翻译 | 当前值 |
|---|---|---|
| `COUNT` | 每次发射弹数(各瞄不同最近敌) | 1 |
| `FREQUENCY` | `FIRE_INTERVAL` ↓ | 1.10 s |
| `DAMAGE` | `PROJECTILE_DAMAGE` ↑ | 1 |
| `AREA` | 弹体 `RADIUS` ↑(可选溅射) | 6.0 |
| `PIERCE` | 命中后存活的敌人数 | 0 |
| `DURATION` | 弹体 `lifetime` ↑ | 2.2 s |
| `SPEED` | `PROJECTILE_SPEED` ↑ | 520 |

### OrbitSword
| 通用属性 | 翻译 | 当前值 |
|---|---|---|
| `COUNT` | 剑数(均匀分布) | 1 |
| `FREQUENCY` | `ORBIT_SPEED` ↑ | 3.4 |
| `DAMAGE` | `DAMAGE` ↑ | 1 |
| `AREA` | `ORBIT_RADIUS` ↑ + `SIZE` ↑ | 186 / 52×12 |
| `PIERCE` | `HIT_COOLDOWN_SECONDS` ↓(每圈命中同一敌多次) | 0.45 |
| `DURATION` | (无意义)→ 折叠进 AREA,加剑长 | — |
| `SPEED` | (无独立意义)→ **折叠进 FREQUENCY** | — |

> OrbitSword 的 `SPEED` 直接折叠进 `FREQUENCY`(都是"转得更快"),`DURATION` 折叠进 `AREA`(剑变长 = 覆盖更多)。这保证 7 个通用属性里 6 个对剑都有可感知效果。

## 5. 适配系数 `k`(校准结果)

公式:`技能实际增益幅度 = 通用升级幅度 × k`

| 通用属性 | AutoShooter `k` | OrbitSword `k` | 调整理由 |
|---|---|---|---|
| `COUNT` | 1.0 | 1.0 | 字面 +1 实体,直觉一致;失衡用稀有度 + DR 压制(见 §7) |
| `FREQUENCY` | 1.0 | **0.95** | 剑加速额外附带视觉压制力(手感增益),微调下压 |
| `DAMAGE` | 1.0 | 1.0 | 双方线性,天然平衡 |
| `AREA` | 1.0 | **0.9** | 剑的 AREA 同时放大半径(覆盖)+ 剑长(命中),双重收益 |
| `PIERCE` | 1.0 | **0.8** | 剑的 PIERCE = 命中冷却 ↓,直接提 DPS 且提覆盖,偏强 |
| `DURATION` | 1.0 | **0.5** | 剑无寿命概念,折叠进 AREA,只取半价 |
| `SPEED` | 1.0 | **折叠→FREQUENCY** | 不单独投放,合并进 FREQUENCY |

## 6. 两个用户案例的平衡分析

### 案例 A:子弹增加(Count +1)

| 技能 | 单体 DPS | 群体 DPS(N 敌) | 增益类型 |
|---|---|---|---|
| AutoShooter | 0.909 → 0.909(不变) | 0.909 → 1.818(N≥2) | **覆盖增益** |
| OrbitSword | 0.541 → 1.082(×2) | 0.541×N → 1.082×N(×2) | **DPS 增益** |

**失衡点**:环绕型白赚单体 DPS ×2,子弹型单体 DPS 不变。

**校准方案**(三联压制,不改字面效果):
1. **稀有度**:COUNT 投放权重 35(见框架 §8),比 FREQUENCY/DAMAGE 的 100 低近 3 倍。
2. **边际递减更陡**:COUNT 的 `dr_divisor = 0.5`,第 2 把剑收益仅 67%。
3. **`k` 保持 1.0**:维持"+1 实体"的直觉,不靠改效果数值平衡。

> 不用调 `k` 的原因:Count 的字面效果(+1 实体)是玩家最直观的预期,改 `k` 会出现"2 把剑但只算 1.7 把"的奇怪体验。靠投放频率和 DR 控制更隐性。

### 案例 B:减少施法时间(Frequency +15%,堆叠 1 次)

| 技能 | 计算 | DPS | 增益 |
|---|---|---|---|
| AutoShooter | 间隔 1.10 → 1.10/1.15 = 0.957s | 1 / 0.957 = 1.045 | +15.0% |
| OrbitSword | 转速 3.4 → 3.4×1.15×0.95 = 3.710 | 3.710/(2π) = 0.590 | +9.1% |

**结论**:Frequency 天然接近平衡(差 ~6%),OrbitSword 的 0.95 系数把它的额外手感增益压回区间内。**无需进一步调整**。

> 印证框架 §4.4:Frequency 是最安全的基准属性,新技能上线先用 Frequency 校准 DPS 锚点。

## 7. 边际递减参数(本版本)

沿用框架 §5 全局曲线,本版本确认参数:

```
effective(stat, stacks) = base(stat) / (1 + dr(stat) * (stacks - 1))
```

| 属性 | `base`(每层基础幅度) | `dr_divisor` |
|---|---|---|
| `COUNT` | +1 实体 | 0.5 |
| `FREQUENCY` | +15% | 0.4 |
| `DAMAGE` | +25% | 0.4 |
| `AREA` | +20% | 0.4 |
| `PIERCE` | +1 敌人(子弹) / -0.10s 命中冷却(剑) | 0.5 |
| `DURATION` | +30% 寿命 | 0.4 |
| `SPEED` | +15% 弹速(仅子弹) | 0.4 |

单属性单技能上限 **5 层**。

## 8. 升级数值表(每次升级的实际效果)

下表为"堆叠 1 次"时,每个技能实际获得的参数变化(已乘 `k`、已应用 DR 第 1 层=100%)。后续堆叠按 §7 曲线递减。

| 通用升级 | AutoShooter 实际效果 | OrbitSword 实际效果 |
|---|---|---|
| `COUNT +1` | +1 弹(瞄下一个最近敌) | +1 剑(均匀分布) |
| `FREQUENCY +15%` | `FIRE_INTERVAL` ÷1.15 → 0.957s | `ORBIT_SPEED` ×1.1425 → 3.884 |
| `DAMAGE +25%` | `PROJECTILE_DAMAGE` ×1.25 → 1.25 | `DAMAGE` ×1.25 → 1.25 |
| `AREA +20%` | `RADIUS` ×1.2 → 7.2 | `ORBIT_RADIUS` ×1.18 → 219.5;`SIZE` ×1.18 → 61×14 |
| `PIERCE +1` | 命中后存活 +1 敌(穿透) | `HIT_COOLDOWN` -0.10s → 0.35s |
| `DURATION +30%` | `lifetime` ×1.3 → 2.86s(射程→1486) | 折叠:剑长 ×1.15(半价 0.5×30%) |
| `SPEED +15%` | `PROJECTILE_SPEED` ×1.15 → 598 | 折叠进 FREQUENCY(同上) |

## 9. DPS 校验(目标区间 +10%~+25%)

堆叠 1 次时各升级对每个技能的 DPS 增益:

| 升级 | AutoShooter DPS | 增益 | OrbitSword DPS | 增益 | 在区间? |
|---|---|---|---|---|---|
| 基线 | 0.909 | — | 0.541 | — | — |
| `FREQUENCY` | 1.045 | +15.0% | 0.590 | +9.1% | ✅(剑稍低,接受) |
| `DAMAGE` | 1.136 | +25.0% | 0.676 | +25.0% | ✅ |
| `AREA`(子弹按射程内多命中近似) | ≈0.909 | +0%(主覆盖) | ≈0.640 | +18.3% | ✅(子弹偏覆盖,接受) |
| `PIERCE +1`(2 敌场景) | 1.818(打 2 敌) | +100%* | 0.676(冷却↓) | +25.0% | ⚠ 见下 |
| `COUNT +1`(2 敌场景) | 1.818 | +100%* | 1.082 | +100%* | ⚠ 见下 |
| `DURATION` | 0.909(射程外多打) | +0%(主覆盖) | 0.622(剑长↑→角宽↑) | +15.0% | ✅ |
| `SPEED` | 0.909(主覆盖) | +0%(主覆盖) | 折叠 | — | ✅ |

> `*` 标记的 +100% 是**多敌场景下的群体 DPS**,单体 DPS 不增。这类"覆盖增益"不套用 +10%~+25% 的 DPS 锚点,改用**覆盖增益锚点**:每次 COUNT/PIERCE 升级应让可同时命中的敌人数 +1,等价于群体 DPS ×(N+1)/N。靠稀有度(权重 35)和 DR(`dr=0.5`)控制其投放频率,而非压低数值。

**校验结论**:除 COUNT/PIERCE 的群体增益(设计上就是强覆盖升级)外,其余升级的 DPS 增益全部落在 +9%~+25% 区间。剑的 FREQUENCY 略低(+9.1%),属于刻意压制其手感增益,可接受。

## 10. 极端 build 测试(单属性堆满 5 层)

| Build | AutoShooter | OrbitSword |
|---|---|---|
| FREQUENCY ×5 | 间隔 1.10 / (1+0.15×(1+0.71+0.56+0.45+0.38)) = 1.10/1.465 = 0.751s → 1.33 DPS(+46%) | 转速 3.4×1.425×(1.465 累积) → 0.793 DPS(+47%) |
| DAMAGE ×5 | 1×(1+0.25×1.465)=1.366 → 1.24 DPS(+37%) | 同左 |
| COUNT ×5 | 6 弹(群体 6 倍) | 6 剑(单体 6 倍 = 3.25 DPS) |

5 层 FREQUENCY 累积 +46% DPS,仍在合理范围(约 2 个普通升级的量)。COUNT ×5 的 6 倍是预期的"高投入高回报",靠稀有度让其难凑齐。

## 11. 落地状态

框架已落地到代码。各组件实现位置:

- [x] `StatMath` 工具类:[scripts/stat_math.gd](../scripts/stat_math.gd) — 枚举、`total_multiplier(stat, stacks)`(§7 DR 曲线)、`MAX_STACKS`
- [x] AutoShooter `apply_stat` + `_recompute`:[scripts/weapons/auto_shooter.gd](../scripts/weapons/auto_shooter.gd) — 7 个 stat 全部映射
- [x] OrbitSword `apply_stat` + `_recompute`:[scripts/weapons/orbit_sword.gd](../scripts/weapons/orbit_sword.gd) — SPEED/DURATION 折叠、多剑管理(`SwordBlade` 内部类)
- [x] 升级池加权随机 + 3 选 1:`main.gd` 的 `stat_upgrade_defs` / `_build_stat_pool` / `_pick_weighted`
- [x] 自定义升级积分阈值:`main.gd` 的 `LEVEL_REQUIRED_SCORES = [0, 50, 200, 99999]`,Level 1 固定武器二选一、Level 2+ stat 升级
- [x] Level 1 武器解锁 / Level 2+ stat 升级:`_show_level_up_options` 分级,`_apply_upgrade`(解锁)与 `_apply_stat_upgrade`(堆叠)分离
- [x] AutoShooter COUNT 多目标:`_find_nearest_enemies(count)` 取最近 K 个不同敌人各射 1 弹
- [x] OrbitSword COUNT 多剑:角度偏移 `i * TAU / N` 均匀分布
- [x] OrbitSword SPEED→FREQUENCY、DURATION→AREA 折叠:见 `_recompute`
- [x] Projectile 支持可变 radius/lifetime/伤害/穿透:[scripts/projectile.gd](../scripts/projectile.gd)
- [x] Enemy hp 改 float 以支持小数伤害:[scripts/enemy.gd](../scripts/enemy.gd)

### 已知简化 / 后续可扩展

- stat 升级卡当前只显示通用标题 + Lv.+ 描述,未逐武器展示具体数值变化(§11 末项的"可读性"待办:可在卡上列出"子弹: 冷却 1.10→0.96s / 剑: 转速 3.4→3.88")。
- Level 2+ 仅投放 stat 升级,第二把武器暂不出现在升级池(当前只能 Level 1 二选一)。若要支持后续解锁第二武器,把 `_create_weapon_card` 的选项加入 `_build_stat_pool` 即可。
- `apply_stat(stat, stacks)` 传的是**绝对堆叠数**(main 为唯一真相源),新武器解锁时由 `_sync_weapon_stats` 同步全部已累积堆叠,已支持多武器共存。

> 本文档为设计校准基准。代码常量改动后需回本文 §2 同步数值;适配系数 `k` 改动需回 §5 同步。
