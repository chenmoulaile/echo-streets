## 物理层 / 分组 / 掩码常量表
## class_name: GameLayers
## 挂载节点类型: 无（纯常量脚本，extends RefCounted，只通过类名静态引用，不需要实例化）
## 依赖信号: 无
## 节点路径假设: 无
## 用法: 任何脚本直接写 GameLayers.PLAYER / GameLayers.MASK_HITSCAN，
##       禁止在玩法代码里散落魔法数字。
## 说明: 物理层编号与 Project Settings > Layer Names > 3D Physics 的第 1~6 层对齐，
##       但脚本在 _ready() 里会主动写入 collision_layer / collision_mask，
##       因此即使项目设置里没有命名这些层，运行时行为依然正确。
class_name GameLayers
extends RefCounted

# ── 物理层（位掩码）────────────────────────────────────────────
const WORLD: int = 1 << 0        ## 第 1 层：静态关卡几何（地面/墙体）
const PLAYER: int = 1 << 1       ## 第 2 层：玩家身体
const ZOMBIE: int = 1 << 2       ## 第 3 层：丧尸身体
const WEAKSPOT: int = 1 << 3     ## 第 4 层：弱点 Area3D（头部）
const PROJECTILE: int = 1 << 4   ## 第 5 层：抛射物
const INTERACT: int = 1 << 5     ## 第 6 层：可交互物（补给箱/门）

# ── 常用掩码组合 ───────────────────────────────────────────────
## 射线命中检测：墙体 + 丧尸身体 + 弱点（弱点用 Area3D，需 collide_with_areas）
const MASK_HITSCAN: int = WORLD | ZOMBIE | WEAKSPOT
## 玩家身体的碰撞掩码：撞墙、被丧尸挡住、触发交互物
const MASK_PLAYER_BODY: int = WORLD | ZOMBIE | INTERACT
## 丧尸身体的碰撞掩码：撞墙、撞玩家、彼此挤开（避免完全重叠）
const MASK_ZOMBIE_BODY: int = WORLD | PLAYER | ZOMBIE
## 抛射物逐帧射线检测
const MASK_PROJECTILE: int = WORLD | ZOMBIE | PLAYER

# ── 场景树分组名（全项目统一，避免字符串拼写漂移）───────────────
const GROUP_PLAYER := &"Player"
const GROUP_ZOMBIE := &"Zombie"
const GROUP_WEAKSPOT := &"Weakspot"
const GROUP_POOL := &"ObjectPool"
const GROUP_DIRECTOR := &"Director"
const GROUP_WAVE_SPAWNER := &"WaveSpawner"
