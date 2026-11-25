## 全局事件总线（Autoload 单例）
## class_name: 无（Autoload 注册名 EventBus 已是全局标识符，再加 class_name 会报
##            "hides an autoload singleton" 解析错误）
## 挂载节点类型: Node（Project Settings > Autoload，名称 EventBus，
##               路径 res://scripts/core/event_bus.gd，启用 Global Variable）
## 依赖信号: 本文件是所有信号的声明处，不监听任何信号
## 节点路径假设: 无（不持有任何节点引用）
## 设计约束:
##   1. 只放 signal 与极少量只读状态，禁止写玩法逻辑（否则无法单场景测试、无法 GC）。
##   2. 玩法脚本之间禁止 get_node() 跨场景直连，一律走本总线。
##   3. 参数必须显式标注类型，禁止裸 Variant。
## 命名规范: snake_case，动词过去式或名词_过去式（health_changed / zombie_died）。
extends Node

# ── 玩家事件 ────────────────────────────────────────────────────
## 玩家血量变化（当前血量, 最大血量）。HUD 血量条直接连这个。
signal player_health_changed(current: float, max_value: float)
## 玩家受击（伤害值, 攻击来源节点）。用于屏幕红边、受击音效。
signal player_hit(damage: float, source: Node)
## 玩家死亡。GameManager 收到后切 DEAD 状态。
signal player_died
## 玩家成功开火（当前武器数据, 后坐力强度）。HUD 播开火帧、镜头后坐用。
signal player_fired(weapon_data: Resource, recoil: float)
## 空仓扣扳机（弹匣已空但仍有备弹）。HUD 换成空仓姿势，不放枪口火光。
signal player_dry_fire

# ── 武器 / 弹药事件 ─────────────────────────────────────────────
## 弹药变化（弹匣余量, 备弹余量）
signal ammo_changed(mag_ammo: int, reserve_ammo: int)
## 换弹开始（换弹总时长秒，供 HUD 进度条做 tween）
signal reload_started(duration: float)
## 换弹被中断（切枪 / 死亡）。HUD 需立刻隐藏进度条。
signal reload_cancelled
## 换弹完成
signal reload_finished
## 武器切换（新武器数据资源, 槽位索引）
signal weapon_switched(weapon_data: Resource, slot_index: int)

# ── 命中 / 击杀事件 ─────────────────────────────────────────────
## 子弹命中丧尸（丧尸节点, 实际伤害, 是否弱点）。伤害数字与血雾特效用。
signal zombie_hit(zombie: Node, damage: float, is_weakspot: bool)
## 子弹命中非血肉表面（命中点, 法线, 是否金属）。pixelfx 火花/碎屑用。
signal bullet_impact(position: Vector3, normal: Vector3, is_metal: bool)
## 丧尸死亡（丧尸节点, 击杀者节点）
signal zombie_died(zombie: Node, killer: Node)
## 处决慢动作请求（持续秒数）。GameManager 负责改 Engine.time_scale。
signal execution_slowmo(duration: float)

# ── 波次 / 导演事件 ─────────────────────────────────────────────
## 新一波开始（波次序号从 0 起, 本波丧尸总数）
signal wave_started(wave_index: int, total_count: int)
## 当前波清空（波次序号）
signal wave_cleared(wave_index: int)
## 全部波次打完（守点关通关判定依据）
signal all_waves_cleared
## 当前存活丧尸数变化（供 HUD 与 Director 压力计算）
signal zombie_count_changed(alive: int)
## 导演压力值变化（0.0 松弛 ~ 1.0 高压）。Director 发，HUD/音频收。
signal director_pressure_changed(pressure: float)

# ── 游戏流程事件 ────────────────────────────────────────────────
## 游戏状态切换（数值等于 GameManager.GameState 枚举）
signal game_state_changed(new_state: int)
## 击杀总数变化（累计击杀）
signal kill_count_changed(total_kills: int)
## 关卡目标完成（推进关的通关判定依据）
signal level_objective_completed

# ── 章节事件 ────────────────────────────────────────────────────
## 章节已构建完毕、即将开始（章节序号从 0 起, 章节总数, 章节标题, 章节目标文案）。
## HUD 收到后弹章节横幅；关卡根节点在 _load_chapter 末尾发出。
signal chapter_started(index: int, total: int, title: String, objective: String)
## 通关后进入下一章（新章节序号）。GameManager 发，关卡根节点/调试面板收。
signal chapter_advanced(index: int)

# ── 瞄准 / 推挤 / 操控方案事件 ──────────────────────────────────
## 开镜状态切换（true = 进入 ADS）。HUD 淡出准星、viewmodel 向中轴收拢。
signal ads_changed(aiming: bool)
## 推挤结算完成（命中数量 0~SHOVE_MAX_TARGETS）。音效与镜头抖动用。
signal player_shoved(hits: int)
## 单个丧尸被推挤命中。命中特效的粒度钩子。
signal zombie_shoved(zombie: Node)
## 操控方案切换（数值等于 InputSetup.Scheme）。
signal input_scheme_changed(scheme: int)
## 新手教程步骤推进（step 从 0 起；step < 0 表示教程结束）。
signal tutorial_step(step: int)
## 游戏进入正式开局（主菜单点开始游戏后）。关卡根节点据此投递教程提示。
signal run_started
## 玩家偏好变更（灵敏度 / 音量 / 操控方案）。面板每改一次发一次，
## 消费方（Player 的灵敏度、音频总线）主动重读 GameSettings，不做双向绑定。
signal settings_changed
