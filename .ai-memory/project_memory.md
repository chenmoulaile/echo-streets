# echo-streets 项目记忆

> 单文件入口。新会话先读本文件，再按需读 `20261124/topics.md` 与 `20261124/daily.md`。

## 1. 项目身份

| 项 | 值 |
| --- | --- |
| 项目名 | echo-streets（像素丧尸 FPS，Doom 式伪 3D） |
| 根目录 | `D:\mygame` |
| 引擎 | Godot 4.7.2.stable.official.ed1daf0bf |
| 可执行 | `D:\DevTools\Godot\Godot_v4.7.2-stable_win64.exe` / `..._console.exe` |
| 渲染 | Compatibility（OpenGL 3.3，实测 Intel Arc Graphics） |
| 语言 | GDScript，**单文件 ≤ 300 行（PDF 硬红线）** |
| 需求来源 | `C:\Users\chenk\Downloads\像素丧尸FPS游戏开发流程.pdf` |
| 当前阶段 | **Phase 2 四章 demo 已闭环 + Windows 桌面端已导出**（4 章 × 5 波 + 章节推进 + 章节横幅 + 照片级场景 + 丧尸 5 状态动画 + 伪 3D 像素 viewmodel + 全场景材质像素化 + `palette_levels 12` 后处理） |
| 导出产物 | `build\echo-streets.exe`（单文件内嵌 pck，121561672 B / 约 121 MB） |

## 1.1 四章一览

| # | id | title | 空间类型 | 尺寸 (W×L×H) | 灯数 | 天空 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `chapter_01` | ECHO LOBBY | 企业大堂（白石 + 方柱 + 落日幕墙） | 22×46×3.6 | 41 | 无（幕墙贴 `sky_window`） |
| 2 | `chapter_02` | OFFICE FLOOR | 开放式办公层（木地板 + 工位阵列 + 玻璃会议室） | 24×40×3.2 | 25 | 无 |
| 3 | `chapter_03` | MALL ATRIUM | 商场中庭（泳池蓝白 + 二层环廊 + 自动扶梯 + 玻璃橱窗） | 26×36×5.2 | 41 | 无 |
| 4 | `chapter_04` | ROOFTOP DECK | 停机坪天台（水泥 + 太阳能板 + 落日 skybox） | 30×34×6.0 | 8 | `sky_rooftop_equirect` |

总击杀 92 / 102 / 114 / 132，每章 5 波，通关进下一章，第 4 章通关显示 `DEMO CLEARED - PRESS R TO RESTART`。

## 2. 目录契约

```
D:\mygame\
├── project.godot          # 主场景 / 480x270 / 6 物理层 / gl_compatibility
├── scenes\                # 8 个 .tscn（main + player + wave_spawner + director + 4 丧尸）
├── scripts\               # 39 个 .gd，按 core/components/player/weapons/enemies/director/ui/level 分域
│   └── level\             # level / chapter_data / chapter_builder / chapter_kit / light_baker / light_ao / mesh_builder / chapters / chapter_01..04 + chapter_01_props / chapter_03_props / chapter_04_props
├── shaders\               # 8 个 .gdshader（含 panorama_sky_rot）
├── data\                  # 7 个 .tres（weapon_pistol/shotgun + wave_1..5）
├── assets\textures\       # wall_stone / floor_tile / ceiling + sky_rooftop_equirect(2048x1024) + sky_window(3860x520)
├── assets\materials\      # 54 张现代材质 200x200（从参考项目提取）
├── assets\sprites\        # 4 张丧尸立绘 96x96 + zombie_frames\ 80 帧动画 + viewmodel\ 20 帧自绘伪 3D 像素武器
├── assets\fx\             # muzzle_flash / blood_splat
├── .ai-memory\            # 项目记忆（本文件 + 日期子目录）
├── tmp\                   # 构建器、探针、截帧器、素材生成器、C# 量化助手（不参与运行时）
└── trae-images\           # AI 生图原始 1920x1920 jpg
```

## 3. 核心架构（分层与单一职责）

| 层 | 文件 | 职责 |
| --- | --- | --- |
| 事件总线 | `scripts/core/event_bus.gd` | 24 个 signal（含 `chapter_started` / `chapter_advanced`），Autoload，全局唯一通信面 |
| 层掩码 | `scripts/core/game_layers.gd` | WORLD/PLAYER/ZOMBIE/WEAKSPOT/PROJECTILE/INTERACT + 三组 MASK + 6 个 group 名 |
| 输入 | `scripts/core/input_setup.gd` | 13 个键位动作 + 3 个鼠标动作；`missing_actions()` / `unbound_actions()` 自检 |
| 状态机 | `scripts/core/game_manager.gd` | BOOT/PLAYING/PAUSED/DEAD/LEVEL_COMPLETE + 慢动作 + JSON 存档 |
| 池化 | `scripts/core/object_pool.gd` | acquire/release + `_on_pool_acquired`/`_on_pool_released` 回调 |
| 玩家 | `scripts/player/player.gd` | 移动/输入路由/血量接线（295 行）；策略层已拆出三个文件 |
| 玩家·回复 | `scripts/player/player_vitals.gd` | 击杀回复预算（每秒上限 20）+ 死亡清理；实例化持有 |
| 玩家·视角 | `scripts/player/player_look.gd` | 全 static：俯仰钳制 `apply_look()` / 后坐回正 `tick_recoil()` / 后坐叠加 `add_recoil()` |
| 玩家·武器槽 | `scripts/player/player_arsenal.gd` | 收集 / 切换（打断换弹）/ 循环 / 弹药重置；实例化持有 |
| 武器 | `scripts/weapons/weapon.gd` + `weapon_data.gd` | 射线 hitscan、弹匣/备弹、逐发装填、弱点判定（278 行） |
| 武器·弹道 | `scripts/weapons/weapon_ballistics.gd` | 全 static：扩散 `apply_spread()` / 单发 `fire_pellet()` / 弱点与金属判定 |
| 存档 IO | `scripts/core/save_io.gd` | 全 static：`write(payload)` / `read()` / `exists()`；`SAVE_PATH` 常量在此 |
| 敌人 | `scripts/enemies/zombie_base.gd` + `zombie.gd` + `zombie_steering.gd` + `zombie_sprite.gd` | 基类管池化与自省，子类管 AI 状态机，steering 全 static 纯函数 |
| 导演 | `scripts/director/director.gd` + `wave_spawner.gd` + `wave_config.gd` | 四路加权压力 → 刷怪间隔乘数 + 特感权重加成 |
| UI | `scripts/ui/hud.gd` + `hud_widgets.gd` | 状态文字与 EventBus 接线 / 全部读数部件与动画 |
| 关卡 | `scripts/level/level.gd` | 解析五节点 → 按章构建世界 → `GameManager.start_level()`；DEAD 时 R 重开、LEVEL_COMPLETE 时 R 重开 demo |
| 章节数据 | `scripts/level/chapter_data.gd` | `ChapterData`：id/title/subtitle/objective/出生点/几何原语/灯位/刷怪点/波次/环境色/后期参数/天空 |
| 章节构建 | `scripts/level/chapter_builder.gd` | 把原语翻成 MeshInstance3D + StaticBody3D；材质缓存；`fill_spawns()`；`build_sky()` |
| 章节原语 | `scripts/level/chapter_kit.gd` | 全 static：`m()` / `box(…, step, rot)` / `panel(…, tiled, emissive)` / `lamp(…, down_only)` / `lamp_row()` / `curtain()` / `light_strip()` / `ceiling_grid()` / `floor_seams()` / `solid()` |
| 光照烘焙 | `scripts/level/light_baker.gd` | 构建期顶点色烘焙：`_direct()` 能量守恒饱和 + `HORIZON_GAIN` 半球项 + 地板反弹层 + `_knee()` 软压缩 + AO 乘子 |
| 环境光遮蔽 | `scripts/level/light_ao.gd` | 全 static：AABB 网格遮挡（只收 `body=true` 的 box）+ **法线正半球过滤** + 墙脚 smoothstep 接触阴影 |
| 章节注册 | `scripts/level/chapters.gd` | 4 章脚本路径表 + `count()` / `script_path()` / `load_chapter()`（只登记路径不 preload） |
| 章节定义 | `scripts/level/chapter_0{1..4}_*.gd` | 每章一个 `static func build() -> ChapterData`：ch01 ECHO LOBBY / ch02 OFFICE FLOOR / ch03 MALL ATRIUM / ch04 ROOFTOP DECK |
| 章节道具 | `scripts/level/chapter_01_props.gd` / `chapter_04_props.gd` | 章节私有几何子模块（幕墙+售货机 / 太阳能板+机组+栏板+天光灯），全 static；**必须重复声明尺寸常量**（反向 preload 父文件会 Cyclic reference） |
| 网格生成 | `scripts/level/mesh_builder.gd` | 全 static：`axes()` / `build_panel()` / `build_box()`，含绕序与 UV 修正；`light_baker.gd` 尾部用 `static func` 转发（412→246 行） |
| 光照烘焙 | `scripts/level/light_baker.gd` | 构建期顶点色烘焙（无运行时灯）：能量守恒饱和 + 地板反弹 + 水平增益 + 软压缩 |
| 章节原语 | `scripts/level/chapter_kit.gd` | `box/panel/lamp/lamp_row/curtain/light_strip`，全 static |
| 四章定义 | `scripts/level/chapter_0[1-4]_*.gd` + `chapters.gd` | 01 大堂 / 02 办公层 / 03 商场中庭 / 04 天台；`chapters.gd` 只登记路径不 preload |

## 3.5 章节系统（四章 demo 的骨架）

`GameManager` 持有 `_chapter_index`，`_on_all_waves_cleared()` 判断 `has_next_chapter()`：
有下一章 → `advance_chapter()`（复位 time_scale/paused/slowmo → emit `chapter_advanced` → `reload_current_scene()`）；
无 → `complete_level()`。`restart_demo()` 把 index 归 0 再重载。存档 payload `version=2` 含 `chapter_index` / `chapter_total`。

四章实测基线（`tmp/chapter.log`，24 张截帧全部 `save=0`，已挂 PostFX）：

| 章 | 空间 | 尺寸 | meshes | bodies | tris | lamps | materials | sky |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 01 ECHO LOBBY | 企业大堂 | 22×46×3.6 | 217 | 147 | 7825 | 41 | 15 | 无（幕墙贴 `sky_window`） |
| 02 OFFICE FLOOR | 开放办公层 | 24×40×3.2 | 291 | 229 | 5538 | 25 | 13 | 无 |
| 03 MALL ATRIUM | 商场中庭（二层环廊 + 扶梯） | 26×36×5.2 | 245 | 47 | 7466 | 41 | 13 | 无 |
| 04 ROOFTOP DECK | 天台停机坪 | 30×34×6.0 | 161 | 153 | 4264 | 8 | 11 | 有 |

**运行时一盏 OmniLight3D 都不留**。Compatibility(OpenGL3) 实测 `max_lights_per_object=8` / `max_renderable_lights=32`，铺 20 盏吊灯会静默丢 12 盏；且材质是 `SHADING_MODE_UNSHADED`，灯本就不参与着色。所以灯只作为构建期数学光源参与顶点色烘焙。
**硬契约**：用烘焙色的材质必须 `vertex_color_use_as_albedo = true`，否则顶点色被丢弃、画面全白平涂。

**光照管线五层**（`light_baker.gd` + `light_ao.gd`，全部构建期计算）：
1. `_direct()`：逐灯 `atten = t²`、`ndl = WRAP_BASE + (1-WRAP_BASE)·max(n·L,0)`，累加后走**能量守恒饱和** `out = amb + (1-amb)·(1-exp(-sum))`，`LIGHT_GAIN = 5.2` 找回弱光层次。
2. `HORIZON_GAIN = 1.05`：环境光按 `(1 + 1.05·(1-|n.y|))` 放大，只提墙面（`|n.y|` 小），地板/天花 `horizon=0` 不受影响 —— 这是**不连带削顶**的关键。
3. 地板反弹层：朝下的面采样正下方地板的 `_direct`，`k = 0.78 · 0.26 · |n.y|`。
4. `_knee()`：0.78 以上软压缩 `0.78 + 0.22·(1-exp(-(v-0.78)/0.22))`，保留贴图细节不烧成纯白。
5. `LightAO.at()`：AABB 网格遮挡（只收 `body=true` 的 box）+ **法线正半球过滤** + 墙脚 smoothstep 接触阴影。AO 乘在 `_knee` 之后，不参与能量守恒。

**天空**：`assets/textures/sky_rooftop_equirect.png`（2048x1024 真 2:1 等距柱状）由 `tmp/BuildSky.gd` 从 3860x960 的 `SkyTexture_Sunset.png` 重制（地平线在源图 50%，下半压暗成雾霭 + 三层城市天际线 + 260 个雾化矩形 + 90 个远楼剪影，`rng.seed=20261124` 保证可复现）。**楼群尺度铁律**：等距柱状上半 512px 对应 90°，`1px ≈ 0.176°`；2 公里外 200m 高楼仰角 5.7° ≈ 32px，远层 4~14px、近层 20~64px。`shaders/panorama_sky_rot.gdshader`（`shader_type sky`）转 `EYEDIR` 实现方位角，因为 `Sky`/`WorldEnvironment` 都没有 `rotation` 属性。`tonemap_mode` 用 `TONE_MAPPER_FILMIC`（ACES 会把落日橙压成土黄）。

## 4. 节点契约（改场景时必须遵守）

**Player**（CharacterBody3D，`player.gd`）
子节点名固定：`HealthComponent`、`CameraRig`(y=1.6)、`CameraRig/Camera3D`(fov=75, current)、`CameraRig/Camera3D/WeaponMount`(0.3,-0.25,-0.5)。WeaponMount 下 Weapon 子节点顺序即槽位 0/1/2。

**Weapon**（Node3D，`weapon.gd`）
必须赋 `data:WeaponData`，否则 `_ready` push_error 且 `set_process(false)`。`shooter_path` 在场景里写死 `^"../../../.."`（Pistol→WeaponMount→Camera3D→CameraRig→Player），因为 Player 入组晚于 Weapon._ready，group 兜底拿不到。

**Zombie**（CharacterBody3D，`zombie.gd : ZombieBase`）
子节点名固定：`HealthComponent`、`Sprite3D`、`NavigationAgent3D`(可空)、`Weakspot`(Area3D, layer=WEAKSPOT, 头部 y=body_height-0.22, SphereShape3D r=0.18)。

**WaveSpawner**（Node3D）
子节点：`SpawnPoints`（Node3D/Marker3D 子节点即候选点，12 个）、`Pools`（空节点，池挂这里）。

## 5. 已修复缺陷（回归清单，改动后必须重验）

| # | 缺陷 | 根因 | 修复 |
| --- | --- | --- | --- |
| 1 | 所有输入失效 | `InputSetup` 注册 `action_fire`/`pause_game`，消费方读 `fire`/`pause` | 重写动作名对齐消费方；新增 `missing_actions()`/`unbound_actions()` |
| 2 | 无 Player 的场景按 ESC 崩 | autoload 的 `_unhandled_input` 读 `pause`，动作未注册 | `GameManager._ready()` 调 `InputSetup.ensure_defaults()` |
| 3 | 丧尸越复用越强 | `wave_spawner._apply_difficulty()` 每次出池乘 `move_speed`/`max_health`，出池只复位血量 | `ZombieBase` 记录 `_base_move_speed`/`_base_max_health`，出池先还原再加乘数 |
| 4 | 弱点永远打不出倍伤 | `add_to_group()` 在节点入树前调用，PackedScene 不序列化 groups | `zombie.gd._ensure_weakspot_group()` 在 `_ready` 幂等补组 |
| 5 | viewmodel 不显示 | `Player._ready()` 同步发 `weapon_switched`，Hud._ready 更晚 → 信号被丢 | Hud `_pull_initial_state.call_deferred()` 主动拉 `active_weapon()` |
| 6 | 弹药显示成另一把枪 | 两个 Weapon 的 `_ready` 各自 `_broadcast_ammo.call_deferred()`，后者覆盖 | 删除 Weapon 侧广播；`Player._equip()` 末尾统一补发 |
| 7 | 画面平均亮度 6/255 | 纹理偏暗 + 后期 vignette 0.35/scanline 0.18/saturation 0.85 叠加 | 纹理整体提亮约 2 倍 + 后期参数显式写死（brightness 1.16/lift 0.035/vignette 0.20/scanline 0.10）→ 实测 76/255 |
| 8 | HUD 文字糊成一团 | 字号 9 行高 13px，文字 232+13=245 与血条 246 相接；弹药在右下被 viewmodel 遮 | 血条下移 252；弹药移右上 (388,26)；换弹条移准星正下方 (168,152) |
| 9 | 启动报 "no main scene defined" | `ProjectSettings.set_setting("run/main_scene", …)` 少了 `application/` 前缀，落到 `[run]` 段 | 改为 `application/run/main_scene` |
| 10 | 章节场景地板/天花/部分墙整片消失 | `build_panel` 绕序判反：Godot 正面是顺时针，可见条件是「三角形几何法线 = −顶点法线」 | `var flip := (u_axis.cross(v_axis)).dot(n) < 0.0`；flip 真用 `[v00,v10,v01, v10,v11,v01]`，假用 `[v00,v01,v10, v10,v01,v11]`。取证：`tmp/WindProbe.gd` 实测 A 序亮度 0.000 / B 序 0.680 |
| 11 | 光照削顶：地板/柱面/墙全部 1.000，贴图烧成纯白 | `_direct` 把每盏灯贡献直接 `acc +=`，多灯叠加超 1；`_knee` 软压缩把 0.78 以上全挤到 0.99 | `_direct` 改能量守恒饱和 `out = amb + (1-amb)*(1-exp(-sum))`；补 `LIGHT_GAIN = 4.5` 找回弱光层次。四章实测全部 <1.0 且无灰暗 |
| 12 | 发光面比周围天花还暗，灯槽读成「顶上一道黑沟」 | 发光面 panel 也走 `sample()` 烘焙得 lit≈0.6 | `panel()` 加第 8 参 `emissive`，`build_panel` 里 emissive 时顶点色直接写 tint 跳过烘焙；`_add_panel` 透传。五处发光面加 `emissive=true` |
| 13 | 木地板满屏孤立黑点 | 54 个材质 `.import` 都是 `mipmaps/generate=false` + `TEXTURE_FILTER_NEAREST`，远处缩小采样随机命中板缝 | 54 个 `.import` 全改 `mipmaps/generate=true`；`chapter_builder.gd` 改 `TEXTURE_FILTER_NEAREST_WITH_MIPMAPS`（近景硬边像素风 + 远景自动降采样） |
| 14 | 大厅地面远处叠成棋盘摩尔纹 | `PoolTiles` 是 200px 马赛克小砖，平铺 26x36 米每 0.2 米重复一次 | 换 `CeramicFloor_White` + tint(0.80,0.90,1.00) 压冷蓝。**小尺度纹理不能铺大面积** |
| 15 | 工位隔板/会议地毯呈黄绿脏块、桌腿像悬空黑色积木 | 材质平均色选错：`survival__Backroom__CarpetFloor` #C9C178 是黄绿，`MetalWall` #4F4F4F 太黑 | 换 `WhiteWall_Dirty`(#C0C0C0) 与 `MetalPlateWall`(#959E9D)。**选材质前必须 `[Crop]::Avg` 量平均色，不靠 tint 硬拉** |
| 16 | 换章后所有丧尸掉到环形兜底位 | `WaveSpawner._spawn_points_root` 是 `@onready` 缓存引用，换掉 `SpawnPoints` 整节点会让它悬空 | `chapter_builder.fill_spawns(data, holder)` 复用已存在的 `SpawnPoints` 节点，只换子 Marker |
| 17 | 换章后 `reload_current_scene()` 探针自己消失、进程挂到超时 | 探针挂在 `current_scene` 里被一起释放；启动器 `await` 探针的协程随场景销毁，`print`/`quit` 全丢 | 探针必须挂 `get_tree().root` 下；收尾由探针自己 `print` + `quit`。`_ready` 期间 `add_child` 到 root 会报 busy，要 `_spawn.call_deferred()` → `await process_frame` → 同步 `add_child` |
| 18 | 换章后每次开局刷 "waves 为空，已自动生成占位配置" 警告 | `WaveSpawner._ready` 早于 `Level._ready` 检查 `waves` | 真实波次必须在 `Level._enter_tree()` 里塞进 spawner，早于所有子节点 `_ready` |
| 19 | 画面正中一条贯穿上下的纯白竖线，把画面劈开 | 中轴灯带 / `ceiling_grid` 的 `axis="z"` 梁正好压在 x=0。**玩家站在中轴朝 -Z 看，任何沿视线轴延伸且过视点的细长物体都投影成屏幕竖线 —— 透视的必然**，改宽度/分段都无效 | `ceiling_grid` 内 `if along_z and absf(center.x + t) < 0.6: continue`；中轴不放任何吊顶特征（ch01/ch03 灯带已整段删除）。视线引导改用两侧边线与筒灯 |
| 20 | 柱子读成"金属圆柱"、四条竖棱糊掉 | `K.box` 只有全局 `_step=1.0`，1.1 米宽的柱子每面 2x4 顶点，顶点色被 Gouraud 插值抹平 | `box()` 加第 7 参 `step`（0 = 用章节默认），柱身传 0.4。实测柱面 rgb(88)→102，棱角立住 |
| 21 | 天花读成"一团灰雾"、大片均匀灰 | `WhiteCeiling` 近纯白无细节，22x46 米整片铺开被 mipmap 抹平 | 新增 `K.ceiling_grid(center, span, axis, step, drop, mat, tint)` 画吊顶格栅梁（两向 4.0/6.0 米，梁宽 0.09，tint 压到 0.62 才看得出分格） |
| 22 | 探针截帧和游戏实机亮度完全不同，改 `with_post` 一个数字都不变 | `tmp/ChapterProbe.gd` 只建 Camera3D + WorldEnvironment，**没有 PostFX 层** | 探针必须自建 layer=1 CanvasLayer + 铺满 ColorRect + `pixelzombie_postprocess` 材质；`_apply_post()` 先把 7 个键复位到 main.tscn 基线再按章覆盖，否则串味 |
| 23 | 接上后期后天花整片烧成纯白 `white=15.92%` | 之前把 tint 提到 1.30 是为了补偿"探针没挂后期"的假暗，后期接上后变成二次叠加 | tint 与 brightness 必须**在挂后期的基线上**重新标定。ch01 brightness 1.18→1.02、天花 tint 1.30→1.04、柱身 1.35→1.02、导视带 1.30→1.06 |
| 24 | 白墙/天花全渲染成中灰（墙 rgb(104) 而贴图本身 197） | `AMB_SKY=0.40` 太低，灯 range 6.5 在 12 米外 `atten=0.053`，墙面几乎只吃环境光 | `HORIZON_GAIN` 0.60→1.05（只放大 `|n.y|` 小的面，地板/天花 `horizon=0` 不受影响，不会连带削顶）。墙腰回到 0.60~0.65 |
| 25 | 桌面被自己桌腿的 AO 压成近黑棕（mean 0.189） | AO 把"正下方的遮挡物"也算进遮挡，`grow(0.03)` 边界对采样点不成立 | `at()` 里加 `if (closest - p).dot(n) <= 0.02: continue` —— **遮挡物必须落在法线正半球**。物理上朝上的面看不到脚下的桌腿。实测柱子顶面 ao 0.474→1.0 |
| 26 | 21 盏灯全不发光，读成天花上的深灰长条 | 发光面 UV 走 `p*0.5`，灯位 z 全是 6 的倍数 → `v` 恒为整数，NEAREST 采样压在第 0 行边框（`WhiteCeiling_MetalEdge` row0 是蓝灰边框、row1 纯黑） | `build_panel` 里 `if emissive: uvs[idx] = Vector2(0.5, 0.5)` 锁死贴图中心；`_add_panel` 的 `panel_tiled = tiled and not emissive`（**triplanar 会完全忽略网格 UV**） |
| 27 | 玻璃读成黑色实心矮墙（连续 25 行 L<20） | 默认 `DEPTH_DRAW_OPAQUE` 让玻璃挡住身后天空深度，混合阶段拿不到背景色 | `_material` 的 `alpha<1.0` 分支加 `depth_draw_mode = DEPTH_DRAW_DISABLED` |
| 28 | 太阳能板"伪倾斜"穿模，黑柱从板面穿出 0.26m | 后立柱顶 1.15 > 板顶 0.89（前低后高写反了） | 后柱 `0.82` 高 at y=0.41、前柱 `0.68` 高 at y=0.34、板框顶 0.82、板面 0.86 —— 所有支撑件顶面必须低于板底 |
| 29 | ch04 地面零光斑、整片 mean 0.938 | 18 盏不可见天光灯 range 14~16 把地面烘到饱和，指数饱和压平高杆灯 | 删掉全部天光灯，只留 4 盏高杆灯（energy 2.4 / range 11）并给灯头加 emissive panel。lamps 22→8 |
| 30 | 探针 `FAIL 玩家受伤扣血 [dealt=0.0 hp=0.0]` | 前面的近战用例里丧尸把玩家咬死，`take_damage` 因 `_is_dead` 直接返回 0，把"玩家已死"误判成"受伤坏了" | `_spawner.stop()` 后调 `player.reset_player()`。**不能用 `heal()`** —— heal 只加血不复位 `_is_dead` |
| 31 | `SCRIPT ERROR: Nonexistent function 'max_health' in base 'Node (HealthComponent)'` | `hc` 静态类型是 `Node`，脚本属性不能直接点号访问 | 用 `hc.get(&"max_health")` |
| 32 | 外部写入的 PNG 改了但截帧完全不变 | 引擎不会自动重新导入外部改动的贴图，`read_image` 拿到同一 sha256 | 每次改完 PNG 必须重跑 `--headless --import` |
| 33 | 中轴导视带怎么调 tint 都是"地板上一条黑沟"，**三次不同 tint 渲染出逐字节相同的值** | **顶点色在 1.0 处硬截断**。`light_baker.gd:200` 把 `tint * lit` 写进 `PackedColorArray`，GPU 顶点色缓冲是 8-bit UNORM，>1.0 全被 clamp。任何 >1.0 的 tint 都是死值 | 想比材质本身更亮**只能换更亮的材质**。5 处死 tint 全改「换亮材质 + tint 落回合法区间」：ch01 导视带 `CeramicFloor_Gray`→`CeramicFloor_White` tint 0.60；ch03 导视带同法 tint 0.62；ch02 天花 tint 1.24→0.95；ch04 地面 `ConcreteWall`(0.42)→`WhiteWall_Dirty`(0.75) tint 0.68；ch04 机组基座 tint 1.10→0.96。**排查命令**：`Select-String -Path scripts\level\chapter_0*.gd -Pattern 'Color\(1\.[1-9]\|Color\([2-9]\.'` |
| 34 | **玻璃在数学上等于不存在**：玻璃会议室/幕墙/天台栏板全部看不见，或只剩几根青色高光线 | `chapter_builder._material` 的 alpha 是**与贴图 alpha 相乘**。`tmp/TexAlpha` 实测 `Glass.png` 的 alpha 中位只有 26/255 = 0.102（mean 33 / p90 26 / opaque 3.1%），章节再传 0.24~0.30 → 最终只剩 3% 不透明度 | **章节 alpha 一律传 1.0**，让贴图自身的 0.102 当真实玻璃透明度。ch01 幕墙、ch03 栏板+橱窗、ch04 栏板全部改 1.0。工具：`Add-Type -Path tmp\TexAlpha.cs` → `[TexAlpha]::Hist(path)` |
| 35 | 30 个品牌/门头灯箱一个都不渲染 | `chapter_03_atrium.gd` 的 `:131`/`:151` 把 axis 写反：右墙 sx>0 传 `"x+"`（法线朝墙外）、左墙 sx<0 传 `"x-"`，玩家永远在墙内侧 → 全被背面剔除。A/B 实验确证：`"x-"` 渲染出 1300 黄像素、`"x+"` 零 | 改为 `"x+" if sx < 0.0 else "x-"`（**左墙朝 +X、右墙朝 −X**，与 `_shell` 墙裙的写法一致） |
| 36 | 修好方向后灯箱变成 10 个纯黑方块 | emissive 面 UV 锁死 (0.5,0.5)，而 `RGB_Screen` 贴图中心 texel 实测是**纯黑 (0,0,0)**；`ComputerScreen_BlueScreen` 中心是纯蓝 | 灯箱材质换 `WhiteCeiling_MetalEdge`（中心 rgb(237,234,227)）；`signs` 轮换表删掉 `RGB_Screen` 与 `ComputerScreen_BlueScreen`。**屏幕类贴图不能当 emissive 面用** |
| 37 | 商场中庭天花整片均匀灰雾，天花区 sd 只有 0.118（全图 0.237 的一半） | `ceiling_grid()` 写完从未被调用 | `_ceiling()` 开头补 `d.add(K.ceiling_grid(Vector3(0, H-0.06, 0), Vector2(W,L), "x", 3.0, 0.06, "MetalPlateWall", Color(0.72,0.74,0.78)))`。**必须用 `"x"`**，`"z"` 会在中轴投影成竖线 |
| 38 | 柱础/踢脚线把自己压成纯黑（柱础 mean 0.163、min 0.000） | AO 把"矮台座自己"当遮挡物。柱础 y∈[0,0.28]，采样点就在它上面 | `light_ao.gd` 新增 `const OCCLUDER_MIN_TOP := 0.5`，`build()` 里 `if b.position.y + b.size.y < OCCLUDER_MIN_TOP: continue`。**矮于 0.5 米的台座不参与遮挡** |
| 39 | 右墙脚成片死黑，`dark<38` 达 30%（y=180..228 整段 20~30%） | 踢脚线 tint 0.48 × `MetalWall` 反照率 0.312 = 0.150 × lit 0.51 × AO 0.12 = 0.0092 ≈ 2/255 | 三重：踢脚线 tint → `(0.95,0.96,0.98)`；`CONTACT_DARK` 0.58→**0.75**；`light_ao.gd` 末尾 clamp 下限 0.12→**0.30** |
| 40 | 天花恒比地板暗（同距离 dz6 天花 0.673 / 地板 0.783），违反室内光照 | 反弹层用 `FLOOR_ALBEDO=0.78`（白瓷砖实测 0.92）且 `BOUNCE_GAIN` 只有 0.26 | `FLOOR_ALBEDO` 0.78→**0.92**、`BOUNCE_GAIN` 0.26→**0.34** |
| 41 | 白墙永远只吃到环境光（墙实测 rgb(83,88,93) 而贴图本身 197） | ch01 灯在 x=±3、墙在 x=11、采样点 y=1.8 → 距离 8.13 米，而灯 `range=6.0`，墙 100% 落在衰减半径外 | ①`HORIZON_GAIN` 1.05→**1.55**（只放大 `\|n.y\|` 小的面，地板/天花 `horizon=0` 不受影响）；②`_ceiling()` 改**双排灯位** `[[-1,3.0,3.2],[1,3.0,3.2],[-1,7.6,2.6],[1,7.6,2.6]]`，墙面距灯 8.0→3.4 米落进 range。实测 `ch01_03_right lum 0.294→0.411`、sd 0.154→0.221 |
| 42 | 画面可见色阶断层 + dither 棋盘噪点 + 幕墙被压成平色块（04_left 纯红像素占 10.82%） | `pixelzombie_postprocess` 的 `palette_levels=8` / `dither_strength=1.0` / `curvature=0.06` 从未被章节 post 覆盖，一直走 shader 默认 | 四章 `with_post` 全部显式加 `"palette_levels": 24.0, "dither_strength": 0.45, "curvature": 0.0, "chromatic_aberration": 0.35` |
| 43 | 发光面四周露出 0.1 米黑框；格栅梁与灯槽实体相交穿透 | 发光面 (1.7,0.34) 比灯槽 (1.9,0.44) 小一圈；梁 x=3.667 落在灯槽 x∈[2.05,3.95] 内且 y 完全重合 | 发光面 → **(1.86,0.40)**；灯槽下沉 y `H-0.045`→**`H-0.14`**、发光面 y `H-0.095`→**`H-0.19`**、lamp y `H-0.2`→**`H-0.35`** |
| 44 | ch01 画面中央一条横贯全宽的暗带（y=114..116） | `ceiling_grid` 的 `along_x` 梁在 z=0 正好过视点，与中轴竖线同一类透视陷阱 | `ceiling_grid` 循环内补 `if not along_z and absf(center.z + t) < 0.6: continue` |
| 45 | 俯视机位拍到"墙外"：ch01 有 15.62% 背景色、ch03 有 22.9% 纯背景色 | `_05_top` 写死 `start + (0, 6.5, 6.0)` / pitch −38。ch01 层高 3.6 → 相机在天花上方 4.5 米；ch03 层高 5.2、start z=15 → z=21 出南墙 3 米，且 pitch −38 下最近可见地面 z=19.35 > 18，整个房间不在视锥里 | 改成按 geometry 自适应：遍历 `k=="panel" and axis=="down"` 取最高 y 作层高上限，`cam_y = min(ceil_y − 0.75, 4.9)`、`cam_z = start.z * 0.5`、pitch **−52** |
| 46 | 售货机/储物柜/踢脚线背面与墙 panel 精确共面（间隙 0.000） | 摆放位置用 `HALF_W − 半厚` 算，正好贴合墙面 | 统一离墙 0.04 米：售货机 `HALF_W-0.40`、储物柜 `HALF_W-0.30`、踢脚线 `HALF_W-0.06` |
| 47 | 前台在出生点视角只有 31x10 像素，读不出是前台 | 前台在 z=-21.4，玩家出生点 z=18，距离 40.84 米，fov75 折 4.31 px/米 | 前台 `cz` → **−16.0**（距离 34 米）、台体 7.0→**10.0** 宽、台面 7.3→**10.3**、背景发光墙 9.0→**11.0** 宽，门/灯同步前移 |
| 48 | 幕墙玻璃底边出现 7 行纯暗红断层 (64,0,0) | 玻璃底边 y=0.9 与蓝裙顶 y=0.9 **精确共面**，深度冲突 | 玻璃高 `H-1.05`→**`H-1.12`**（底 0.94），与蓝裙顶 0.9 留 0.04 米间隙 |
| 49 | 玻璃栏板/幕墙渲染成**不透明青白板**，比背后天空亮 0.23（ch04 y=138 rgb(187,234,249) L=0.883 vs 天空 0.651） | 章节传 `alpha=1.0` 时 `chapter_builder._material` 的 `if alpha < 1.0` 分支不进入 → `TRANSPARENCY_DISABLED` → 引擎完全忽略贴图 alpha 通道 | 判定改 `if alpha < 1.0 or tex_has_alpha:`，其中 `tex_has_alpha = tex.get_image().detect_alpha() != Image.ALPHA_NONE`。全项目只有 `Glass` 被章节引用（used=8），其余 8 个带 alpha 材质 used=0 |
| 50 | ch01 天花对全部 28 盏灯直射光为 **0**，天花/地面亮度比只有 39.3~82.6%，天花占屏高 31.5% | `_hemisphere(dy) = clampf(0.5 - dy/0.6, 0, 1)`：灯 y=3.25、天花 y=3.60 → dy=+0.35 → 0.5−0.583=−0.083 → clamp 到 0 | 新增 `HEMI_BAND = 1.6`，`return clampf(0.5 - dy / HEMI_BAND, 0.0, 1.0)`；dy=+0.35 得 0.281，天花拿到 28% 直射。实测比值回到 **1.02~1.27** |
| 51 | 灯间天花出现规则暗斑（最低 113，灯下 232，差 118） | 灯槽 `K.box(...)` 第 5 参 `body` 缺省 true → 灯槽盒进 AO 遮挡网格；槽顶 y=3.505 距天花 3.60 仅 0.095 米，`t=0.94 → occ=0.885 → k=0.583` | 灯槽第 5 参改 `false`。**ch02 早就写了 `body=false` 并注明理由，ch01 漏了**。修后 y=60 剖面最低 233 |
| 52 | 天花暗斑消除后整章亮度冲到 0.770、`white` 1.52% 开始削顶 | 去掉 AO 压暗后烘焙值整体抬升 | 天花 tint 0.99→**0.88**、`ceiling_grid` tint 0.92→**0.84**（梁若比板亮，分缝读成发光的线） |
| 53 | 前台双开门与台面穿插，门可见仅 53.5% | 门 z∈[-16.56,-16.44]、台面 z∈[-16.525,-15.475]，z 重叠 0.085 米、y 相交 0.09 米 | 台体深 0.9→**0.60**、台面深 1.05→**0.70**、门改 `Vector3(3.2, 2.90, 0.08) @ (0, 1.45, cz-0.52)` |
| 54 | 玩家能从 2.44 米宽的左墙玻璃穿出去掉出世界（全项目无 kill_plane） | 玻璃 `body=false` 不建体、墙裙只到 0.90 米，而 `jump_velocity=5.0` 跳高 1.276 米 > 0.90 | 新增 `K.solid(size, pos)` 原语（只建 StaticBody3D 不建网格）+ `chapter_builder` 的 `"solid"` 分支；幕墙每格补 `K.solid(Vector3(0.10, H-0.9, pane), Vector3(-HALF_W, 0.9+(H-0.9)*0.5, cz))` |
| 55 | 售货机宽深比反了（0.72 宽 < 1.00 深），真实是 1.15~1.40 | `Vector3(0.72,1.95,1.0)` 宽深写反 | `Vector3(1.00,1.95,0.72)`，灯位同步到 `(HALF_W-0.85, 1.62, z)` energy 0.60 range 4.5（贴图下三分之一是出货口暗区，`f=0.8 dark 61.5%`） |
| 56 | 工位区读不出是工位（全章 `chair\|seat\|plant\|printer` 零匹配，`sat=0.112` 六图最低） | `_desks` 每桌只有 5 个 box | 加椅面/椅背/椅柱/笔记本/绿植盆/绿植冠六件；`04_left` 机位也从贴墙 1.6 米改到走道对侧（原整幅被墙占满，审核据此误判） |
| 57 | 会议桌读成"烧焦木板"（B 通道 0~19） | `WoodenBox` 反照率 (160,104,33) 是高饱和橙棕 + 桌下 AO 下限 0.30 | 换 `MetalPlateWall` tint `(0.72,0.70,0.66)`；腿板长 0.20→**3.2**（原只撑中央 1.3 米，两端各悬空 1.05 米）、tint 0.72→0.92 |
| 58 | 天花板下一段 0.65 米"空框"，该区 lum 只有 32~53 | 玻璃高 2.55 而天花 3.2 | 玻璃高 → **3.18**（`gh := 3.18`、`gy := gh*0.5`），顶梁 y 同步 `gh+0.03` |
| 59 | 会议室四面围合，玩家胶囊半径 0.4 挤不进 0.3 米缺口，6 个刷怪点困室内 | 长玻璃与短玻璃之间留 0.3 米 | 长玻璃拆两段，在 `cz` 处留 **0.7 米门洞**；竖挺 `if absf(mz - cz) < 0.45: mz += 2.5; continue` |
| 60 | 玻璃会议室读成"几根青线"（正立面青像素仅 25%） | 章节 alpha 0.42 × 贴图 p50 0.102 = **0.043**，与白墙混合后 B−R 只有 3 | 新建 `Glass_Pane.png`（alpha ×4，`GAIN=4.0`，p50 26→104）；章节改 `"Glass_Pane"` + alpha 0.72；竖挺 tint 0.62→**0.30**（实测渲染 146~190，理论 81×0.62=50，说明烘焙值远高于预期） |
| 61 | 所有陶瓷地砖上有一条贯穿消失点的竖线（ch02 x=237~241，最暗 x=238 = 185.8 vs 邻列 202，差 **18.9 灰阶**） | **两层暗线叠加**：①素材最外一圈 1px 程序化描边（`CeramicFloor_White` 四边 206 vs 心 236，`Gray` 四边 0 vs 心 125）；②**内部真砖缝 col196-198 = rgb(214,215,214)**（正常砖面 236）。triplanar `u = world_x*0.5`，世界 x=0 → u=0 采样 col0；x 略小于 0 → u 为负 → fract 回绕到 **col198**，两者差 25 级 | **只修描边没用**（第一轮把 col0 对齐到 239，col198 仍是 214，竖线仍在，实测 187.6）。正解是**把砖缝滚出轴线**：`tmp/EdgeSeam.gd` 把贴图沿 X 滚 100px，砖缝落到 col96-98（世界 x≈0.97），世界 x=0 落在砖面中部。实测逐列 L=201.7~202.1，**最大偏差 0.4**（修前 18.9）。**滚动只能滚一个轴** —— 同时滚 X/Y 会把贴图边缘行移到中间变成横线 |
| 62 | 露天章左右两侧亮度**逐位相同**（0.532/0.532），落日零方向光 | 全项目零 `DirectionalLight3D`，材质全是 `SHADING_MODE_UNSHADED`，光只在构建期烘焙 | `light_baker.gd` 加 `SUN_DIR Vector3(-0.50,0.70,0.51)` / `SUN_COLOR Color(1.0,0.78,0.52)` / `static var sun_gain`，`_direct` 里 `sum += sun_color * (sun_gain * maxf(n.dot(SUN_DIR), 0.0))`；`chapter_data.with_sky(tex, rot, energy, sun)` 第 4 参透传 |
| 63 | 加了太阳反而**更暗**（朝 -X 墙面 r 0.950→0.944） | `SUN_AMB_GAIN` 抬 amb 会压缩直射项 —— `out = amb + (1-amb)(1-e^-sum)` 里 amb 出现两处且符号相反 | `SUN_AMB_GAIN` 必须 **0.0**。地面因离饱和远仍 0.587→0.719，掩盖了这个 bug |
| 64 | 露天章 `horizon_gain=1.55` 把垂直面 amb 顶到 **0.994**，`(1-amb)` 只剩 0.006，太阳被完全吃掉（±X 墙都是 0.914，差 0.000） | `HORIZON_GAIN` 只该放大 `\|n.y\|` 小的面，但对露天章垂直面全命中 | `with_sky` 里 `if sun > 0.0: horizon_gain = 0.0`；`chapter_builder._run` 把 `data.horizon_gain` 灌进 `LightBaker.horizon_gain` |
| 65 | 关掉 `horizon_gain` 后 ch04 整章变灰、`lum=0.442` **跌破 0.45 红线** | 它同时是垂直面与地面的天光来源，不只是"提亮补偿" | 抬 `with_ambient` 到 `Color(0.62,0.57,0.52)` / `Color(0.42,0.38,0.34)`，地面 tint 0.68→**0.80**。实测回到 0.497~0.516 |
| 66 | 露天章地面读成一片均匀灰（`gsd` 0.031~0.055） | 单张 200px 材质铺 30×34 米，无分块无接缝 | 4 块微差色 patch（0.74/0.79/0.86/0.90）+ 4 条横向伸缩缝（`jz ∈ [-12,-4,4,12]`，宽 0.10、tint 0.46）。**缝不能沿 Z 铺** —— 过视点必投影成贯穿竖线 |
| 67 | 太阳能板"伪倾斜"：跨 200px 只升 6px；前柱顶 0.68 与板框底 0.76 差 0.08 米（柱子没顶到板）、后柱顶 0.82 = 板框顶 0.82 完全共面 Z-fight | 前低后高的柱高算错，且板本身没有旋转 | `chapter_kit.box` 加第 8 参 `rot`；`PANEL_TILT 12.0`、`rear_top = frame_y + 1.05*PANEL_TAN - half_t - 0.003`、`front_top = frame_y - 1.05*PANEL_TAN - half_t - 0.003`。**旋转必须用 pivot 节点**（顶点是世界坐标，`mi.rotation_degrees` 会绕世界原点转 —— 板被抬到 y≈3.08）；**碰撞体不跟旋转**（旋转 AABB 会变成斜插地面的隐形墙） |
| 68 | 太阳能板穿进空调机组，AABB 重叠 **0.074 m³** | 板框 x 到 ±11.71、机组 x 从 ±11.10 起 | 机组移到 `Vector3(±13.3, 0, ±13.6)`、尺寸 2.6→2.3；板起点 `-11.4 + i*4.0` 共 7 组 |
| 69 | 天际线是"比天空更饱和的纯色剪影"（楼体 sat 0.769 > 天空 0.758，y=500 五个采样点全 rgb(78,48,18)），亮度直方图只有两峰、中间调仅 4.6% | 单色 `fill_rect` 填充；**降饱和用 `tone.lerp(haze, 0.35)` 会把楼体整体提亮**（haze 是亮米色 L≈0.58） | 往**自身等亮度灰**拉：`tone_l = r*0.299+g*0.587+b*0.114` 然后 `tone.lerp(Color(tone_l,tone_l,tone_l), 0.45)` —— 只改色度不动亮度；三层 `h_max 18+95*depth`、楼宽 `44+40*layer`、每栋加竖向窗带 + 逐行 `lerp(haze, smoothstep(0.45,1.0,prog))` 底部渐隐 |
| 70 | 地平线"暗→爆亮→暗"三明治硬切（y=498 L=0.213 → y=512 L=0.466，14 行反弹 0.253、R +96） | `HAZE_PX=56` 且权重 `a=t*t`，在 512 行只剩 0.25，压不住 146 行铺的城市底色 | `HAZE_PX 56→96`、`a = smoothstep(0.0,1.0,t)`（中段 0.25→0.5）、带心上移到 `half-18`、城市底色改 `haze.lerp(cool, smoothstep(0.0,0.45,t))` |
| 71 | 城市地面画成"马赛克棋盘/砖墙" | 硬边矩形 `_blend_rect` + 轴对齐固定行距 —— **只要还在"矩形+固定行距"里怎么调都是砖** | 硬边矩形全换 `_blend_ellipse`（椭圆 + `1-d²` 软权重）；`cool` 从 0.090 抬到 **0.150**（0.090 只有约 40 级，读成黑色虚空）；删掉 `_paint_haze` 调用（用 haze 去雾化已从 haze 出发的地面 = 横贯全宽的纯 haze 亮带） |
| 72 | 4 盏高杆灯地面无光斑，灯脚 L=0.454 比 8 米外 0.568 还暗（环向 72 采样极差仅 0.036） | 4 盏天光灯 energy=1.15/range=26 把全场 lit 抬到 ≥0.750，高杆灯只能推到 0.999，`_knee(0.999)−_knee(0.750)=0.169`，×albedo 0.512 后差仅 0.086 | 天光灯 energy 1.15→**0.30**、range 26→**15** |
| 73 | H 标识不可读，被量化撕成横条纹（y=180..210 全 0 白像素），且比旁边地面还暗 0.013 | 三条白条全在 y=0.014 同平面，横条 x∈[−1.75,1.75] 与竖条贴边相接零深度分离 | 材质换 `WhiteCeiling_MetalEdge`、y 抬到 **0.020** |
| 74 | 中轴黄线是黄黑警示纹不是虚线，且投影宽度 y=168 9px → y=240 23px 中心恒定（透视竖线） | `WarningLine.png` 自带每 16~24px 一条 L≈0.35 深灰横带；单条 `Vector2(0.34, L)` 沿 Z 全长铺 | 改 17 段虚线 `for i in 17: seg_z = -16.0 + i*2.0`、`Vector2(0.24, 1.4)` |
| 75 | 落日天空 R 通道被打爆（天空区 R≥250 占 **35.43%**，G/B 各 0.00%，区均值 rgb(240,138,23)），但 `white=0.00%` 看不出来 | `brightness 1.14` + `lift 0.045` 同向叠加；Stats 的 white 判据要求 RGB 三通道都 ≥250 | `brightness 1.14→1.02`、`lift 0.045→0.020`、`tonemap_white 1.6→2.2`、`sky_energy 1.05→0.92`。修后 R≥250 降到 **0.14%** |
| 76 | 露天章地面 `sd` 只有 0.110（全图 sd 0.196 来自"天空 0.092 / 地面 0.107 两块各自均匀"的拼接反差） | `light_baker.gd` 反弹条件 `if n.y < -0.35 and p.y - floor_y > 0.3:` —— 只有朝下的面（天花板）拿到反弹，ch04 无天花板 | 条件改 `if p.y - floor_y > 0.3:`，强度乘 `(0.4 + 0.6 * clampf(n.y, 0.0, 1.0))` |
| 77 | 21 个发光面 panel 各建 (2.0,0.2,0.30) 碰撞体悬在 y=3.115（占 bodies 16.7%） | `_add_panel` 无条件建体，与"灯是发光薄面"的视觉事实矛盾 | 建体段包进 `if not emissive:`。bodies：ch01 119→91、ch02 222→201、ch03 51→15、ch04 157→153 |
| 78 | ch03 `contrast` 抬到 1.16 后整章削顶 **5.89%**（蓝白瓷砖烧白） | `contrast` 与 `brightness` 同向叠加 | `contrast` 只到 1.12 且 `brightness` **反向降**到 1.04（`saturation` 保持 1.18） |
| 79 | 整片地面读成"一块白塑料 / 一层棕雾 / 一整块蓝白塑料"，没有任何尺度参照 | 贴图自带砖缝被 mipmap 抹平：`CeramicFloor_White` 世界 2 米一格、宽 2cm，480x270 下不到 1px；`WoodenFloor` 同源 | 新增 `K.floor_seams(center, span, step, mat, tint, width)` 显式铺铺装缝：ch01 4.0 米 tint 0.58、ch02 2.4 米 tint 0.62、ch03 2.0 米 tint (0.56,0.62,0.72)。**世界 x≈0 / z≈0 的那条必须跳过**（投影成劈开画面的线）。抬到 y=0.006 避免 Z-fight |
| 80 | 天花分缝梁完全看不见（相对对比度 7.5~10.9%） | 梁 tint 0.84 与吊顶 0.88 只差 4.5%，24 阶量化后差不到 2 级 | 梁 tint 到 **0.70**（20% 相对对比度）；再低读成"脏污" |

## 6. 素材管线

**丧尸立绘**：`trae_draw_image`（seedream_5，1920x1920，洋红底 + 右下水印）→ `tmp/PxConv.cs`（C#/System.Drawing：洋红抠图 → 内容包围盒 → 方形裁剪脚底贴底边 → 前景面积平均降采样 → KMeans 40 色全局调色板量化 → alpha 二值化）→ 96x96 PNG。
关键：`Downsample` 只对前景像素平均（防洋红渗色），并做 despill `excess = min(r-g, b-g); r -= excess*0.85; b -= excess*0.85`。

**场景贴图 / viewmodel**：`tmp/gen_assets.py`（手写 PNG，纯 stdlib zlib+struct）+ `tmp/regen_look.py`（提亮调色板）。

**场景材质像素化（27 张，`tmp/MatPixel.py`）**：`--scale 3 --colors 12 --apply`。三步：①`Image.BOX` 面积平均降采样到 1/N（texel 变成看得见的方块）②只用 `alpha>40` 像素做中位切分量化（`MEDIANCUT` + `Dither.NONE`，mask 外像素先替换成 mask 中位色避免主导调色板）③`Image.NEAREST` 回放到原尺寸（产生 N×N 硬边方块，**文件尺寸与 `.import` 都不变**）。alpha 也一起降采样+回放。备份 `tmp\mat_orig\`（27 张，幂等不覆盖）。
- **降采样倍数不影响调色板规模，只影响色块物理尺寸；决定像素质感的是色阶数**（`--scale 2 --colors 8` → 206 色；`--scale 2 --colors 12` → 298 色；`--scale 3 --colors 8` → 216 色）。
- 定稿 `--scale 3 --colors 12`：9579 → 317 色（3.3%）。木纹需 12 色，8 色会压成 3 条横带。
- **材质本身无动态范围才是 `sd` 偏低的根源**：`WhiteWall` 197/197/197/197 完全平坦、`WhiteCeiling` 233~239、`CeramicFloor_White` 230~237。`PoolTiles`(15~195)、`SolarPanel`(82~255)、`VendingMachine`(14~148)、`WoodenFloor`(2962 唯一色) 才是摄影级高频纹理 —— **像素风要治的是纹理频率，不是色阶**。

**后处理像素化（`palette_levels 24 → 12`）**：四章 `with_post` 的 `palette_levels 12.0` / `dither_strength 0.18`，brightness 回到 1.10/1.06/1.04/1.02，**lift 各加 0.0208 增量**（ch01 0.051 / ch02 0.031 / ch03 0.063 / ch04 0.041）。
- `floor()` 量化平均损失 `-0.5/L`，L 减半损失翻倍 → 只需补**新增量** `0.5/12-0.5/24 = 0.0208`。
- **不能用 brightness 补偿**（乘法会把近 1.0 像素推成纯白，white% 反涨 0.34→0.71%）。
- `dither_strength 0.55→0.18`：0.55 在 3 倍放大下地面满屏 Bayer 棋盘格噪点；0.18 干净且保留色阶过渡。8 倍放大确认 3cm texel 在 3m 外只占 1 屏幕像素，**玩家看到的抖动比纹理更明显**。

**viewmodel（伪 3D 像素风格，12 轮迭代后定稿）**：**几何直接沿用参考帧**（`tmp/fp_png/Handgun__HandgunIdle.png` 245x262、`Shotgun__ShotgunIdle.png` 464x275），只换材质与配色：`tmp/VmRebuild.py` 换色 → `tmp/VmFrames3.py` 整数平移合成 20 帧 → `assets/sprites/viewmodel/`（手枪 146x150、霰弹枪 259x150）。
- 换色三件事：①藏青手套 → 裸手肤色（按明度 24/38/58/84 四档 LUT 映射，保留原有体积分层）②中性灰枪身 → 深蓝灰自研配色（`GUN_LUT` 保明度排序，只换色相/饱和度）③套筒上缘**沿轮廓每列最上缘铺 1~2px** 青色识别线（`ACCENT=(86,214,230)`），**不画色块**（色块会变成突兀的青色方块）。
- 四类掩码：`skin = op&(r-b>28)&(r-g>12)&(lum>90)&(lum<235)&(sat<110)`、`shirt = op&(lum>200)&(sat<45)`、`navy = op&(lum<100)&(b>r+18)`、`gun = op&~skin&~shirt&~navy`。
- 动画帧只用**整数像素平移**（`shift(im,dy,dx)` 保持画布尺寸）+ 程序化弹匣（`paste_mag` 11x16，左 2px 受光 + 底 3px 黄铜）。**像素画旋转会产生锯齿断线**。
- `base()` 必须左右各留 `PAD_X = 3` 边距，否则内容质心偏右 58% 会被贴图右缘硬切。
- **RGBA 不能用 `MEDIANCUT`**（`ValueError: Fast Octree (method == 2) and libimagequant (method == 3) are the only valid methods for quantizing RGBA images`），必须剥 alpha 走 RGB 量化再 `putalpha` 贴回。

**透视铁律（这是"视角正确"的判据，别再走错）**：参考帧是「枪管指向屏幕深处」的**强透视压缩**视角 —— 枪身 bbox 112x250，**高宽比 2.23**，看到的是套筒**顶面与背面**，枪口在远处变小。判据不是角度数值，而是**有没有顶面透视**（`taper` 佐证：参考帧 gun 行宽从枪口到握把 `25 52 78 87 79 50 25` 前端收窄）。
早期版本拿 AI 生成的**纯侧视剖面**（高宽比 0.98）旋转 70 度硬凑「枪管竖直」—— 侧视图没有顶面，旋转只能得到一张转来转去的侧视图，于是枪管看起来「朝天花板」（用户原话："手枪视角没对啊，枪管现在是朝着天花板的而不是朝着前方或敌人的，这哪里正确了，不要随意下定论"）。

**viewmodel 十二轮迭代的教训（不要重走）**：
1~3 轮：纯 2D 手绘 / 斜二测伪 3D / 侧视旋转 —— 全部被否决。斜二测的根因：把枪轴 z 分量同时投到屏幕 x 和 y，枪管与枪托在屏幕上重叠，读成一块方块。
4~5 轮：前臂方向三次纠正 —— 方向必须朝屏幕下方（不能沿枪轴，否则连成贯穿画面的斜带）、宽度控制在枪身厚度 1.2~1.5 倍、`reach` 必须越过裁剪窗口下缘由窗口切边。
6~8 轮：裸手画法 —— 四指必须锚在握把前缘直线上、只露 5 单位指背；霰弹枪前手只画手背 + 三道指缝，不画露出的指节（否则读成"枪管上粘了四颗肉色胶囊"）。
9 轮：Godot 真 3D 渲染（BoxMesh 拼装）→ **在 132px 尺度上不可能有插画体积感，读成一堆方块**。踩坑：`SPECULAR_SCHUMANN` 在 4.7 不存在（用 `SPECULAR_SCHLICK_GGX`）、`Environment` 没有 `transparent_bg` 属性（透明只靠 `SubViewport.transparent_bg`）、`Camera3D.current` 必须显式设置。
10 轮：AI 生图 + 量化 —— 用户定调「伪 3D 像素风格才是真正的要求」，但生成的是侧视剖面，透视仍错。
11 轮：**度量口径两次失败** —— `tmp/RefGeom.py` 的 PCA 主轴 / 枪口 x 均值被手部大面积像素拉偏，把参考帧误读成 `+10.5°`，据此旋转 `-70°` 后枪口朝右上。`tmp/BarrelAxis.py` 的 `barrel_deg` 也不稳定（扫角最小误差出现在 `delta=-24` 与 `-70` 两个不同解）。**角度不能当唯一判据。**
12 轮：**参考帧几何 + 只换材质 → 成功**。用户原话已指明「手臂视角正确，但是手臂不是原创的手臂而是使用的星野的手臂」—— 透视本来就是对的，错的只是材质。

**魔搭（ModelScope）API 不可用（不要再试）**：`ms-***` token 有效（`GET /v1/models` → 200，38 个模型全是文本/多模态 LLM，仅 `Qwen/Qwen-Image-Edit` 与 `MusePublic/Qwen-Image-Edit` 两个图像**编辑**模型，无文生图），但 `POST /v1/images/generations` 与 `/v1/chat/completions` 均 401 `{"errors":{"message":"Please bind your Alibaba Cloud account before use."}}`。**账号未绑阿里云。**
`trae_draw_image`（seedream_5）在有 VPN 时连续 504（`Powered by volc-dcdn`），失败有 30 秒冷却。

## 7. 验证工具链（改代码后按序跑）

> **交付纪律（用户 m12650 明确要求，长期有效）**：每次向用户交付功能改动，**必须同时重新导出桌面端** `build\echo-streets.exe`，并在回复里给出路径 + 字节数 + 时间戳 + 一段「怎么测」。只改代码不导出、或只跑探针不给 exe = 未交付；旧 exe 会带着上一轮 bug 交到用户手上。导出后必须四步取证：①`Get-Item` 报字节数与 mtime（证明不是旧产物）；②启动 6 秒确认进程不早退；③在 exe 字节流里 grep 关键资源名（如 `scenes/title.tscn` / `weapon_projectile.gd` / `zombie_fodder_run_0`）证明新资源已打进内嵌 pck；④`--write-movie` 抓 2~3 帧真实画面（`PrintWindow` 抓 OpenGL 全黑，`CopyFromScreen` 会被 GUI 遮挡）。

```powershell
# 1. 新增 class_name / 新 PNG / 外部改图后必须重导入，否则报 "Could not find type" 或截帧不变
& $GODOT --path D:\mygame --headless --import

# 2. 重建全部场景与资源（改了 tmp\BuildWorld.gd 才需要）
& $GODOT --path D:\mygame --headless res://tmp/build_runner.tscn

# 3. 端到端契约探针（34 项断言）
& $GODOT --path D:\mygame --headless res://tmp/probe_runner.tscn

# 4. 冒烟测试（含死亡动画延迟回收）
& $GODOT --path D:\mygame --headless res://tmp/smoke_test.tscn

# 5. 章节契约（79 项断言，逐章建场）
& $GODOT --path D:\mygame --headless res://tmp/chapter_flow_runner.tscn

# 6. 真实换章（14 项断言，必须带窗口）
& $GODOT --path D:\mygame res://tmp/advance_runner.tscn

# 7. 30 秒实战 soak（帧率 / 击杀 / 波次 / 血量，必须带窗口）
& $GODOT --path D:\mygame --disable-vsync --max-fps 0 res://tmp/soak_runner.tscn

# 8. 四状态截帧（必须带窗口，headless 抓不到画面）
& $GODOT --path D:\mygame res://tmp/shot_runner.tscn

# 9. 四章 24 张截帧（含 PostFX 层，必须带窗口）
& $GODOT --path D:\mygame res://tmp/chapter_runner.tscn

# 10. 存档往返（13 项断言：字段齐全 / version=2 / 换章后 index 跟随）
& $GODOT --path D:\mygame --headless res://tmp/save_runner.tscn

# 11. 标题屏 → 设置面板 → 主场景切场景流（17 项断言）
& $GODOT --path D:\mygame --headless res://tmp/title_flow_runner.tscn

# 12. 弹道飞行时间（22 项断言，毫秒口径）
& $GODOT --path D:\mygame --headless res://tmp/ballistics_runner.tscn

# 13. 丧尸七态动画逐帧（run / grab 必须报 anim=run / anim=grab）
& $GODOT --path D:\mygame --headless res://tmp/anim_runner.tscn

# 14. HUD 专项 7 张截帧（命中刻线 / 换弹环 / 低血 / 空仓，必须带窗口）
& $GODOT --path D:\mygame res://tmp/hud_shot_runner.tscn

# 15. 导出 Windows 桌面端（单文件内嵌 pck）
& $GODOT --path D:\mygame --headless --export-release "Windows Desktop" "D:/mygame/build/echo-streets.exe"
```

**交付纪律见第 7 节开头**（每次交付必须重导 exe + 四步取证），此处不再重复。

**导出的坑**：
- 导出后**必须删掉 `%APPDATA%\Godot\app_userdata\echo-streets\logs\godot.log` 再启动**，否则读到的是上一次的日志。`logbytes=0` 才算启动零错误。
- **验证导出版本画面不能用 `PrintWindow`**：OpenGL 内容不在 GDI 表面上，抓出来全黑。也不能用 `CopyFromScreen`（窗口会被 DSH web GUI 覆盖）。正解：`build\echo-streets.exe --write-movie "D:/mygame/tmp/movie/f.png" --fixed-fps 8 --quit-after 24`，直接拿到 24 张真实渲染帧。**注意帧号是 `f00000000` 起**，`--quit-after 20` 就只有 `f00000000..f00000019`。
- `--write-movie` 帧文件名固定 `f%08d.png`，录制前先 `Remove-Item tmp\movie\*` 否则新旧混在一起。
- `soak` 必须 `--disable-vsync --max-fps 0`，否则撞 60Hz 上限得 59fps（假回归）。

**退出码恒为 1** 属正常：`RID allocations leaked at exit` / `Texture with GL ID leaked` 是强制 quit 的固有现象，不是失败。判定看 stdout 的 `RESULT` / `SOAK RESULT` / `CHAPTERFLOW` / `ADVANCE` 行。

**量化审核工具**（`tmp/` 下 C# 助手，用 `Add-Type -Path '...' -ReferencedAssemblies System.Drawing` 加载）：
| 类 | 方法 | 用途 |
| --- | --- | --- |
| `Crop` | `Run(src,dst,x,y,w,h,scale)` / `Avg(src,x,y,w,h)` | 放大裁切取证 / 求区域平均色 |
| `Audit` | `Stats(path)` / `Grid(path)` / `Rows(path,step)` | `lum= sd= white= black= sat=` / 九宫格亮度 / 逐行剖面 |
| `Alpha` | `BBox(path)` / `Trim(src,dst,pad)` | 不透明包围盒 / 裁透明边 |
| `Diff` | `Region(a,b,x0,y0,x1,y1)` | 两图指定区域掩码差异（验证相邻动画帧是否真不同） |
| `FrameBox` | `One(path)` / `Scan(dir,prefix,states,dirs)` | 单帧包围盒 / 按状态切分统计 |
| `Cols` | `Profile(path,y0,y1)` | 逐行 alpha 掩码，定位身体部位边界 |
| `Strip` | `Run(files[],outPath,scale)` | 多帧横向拼胶片条，判断动画连贯性 |

## 8. 实测基线（回归对照）

| 指标 | 值 | 来源 |
| --- | --- | --- |
| 契约探针 | pass=34 fail=0 | `tmp/probe_runner.tscn` |
| 冒烟测试 | ALL PASS | `tmp/smoke_test.tscn` |
| 章节契约 | pass=79 fail=0 | `tmp/chapter_flow_runner.tscn` |
| 真实换章 | pass=14 fail=0 | `tmp/advance_runner.tscn` |
| 30s soak 帧率 | 143.7 fps（avg_dt 6.961ms，worst 150.0ms） | `tmp/soak_runner.tscn` |
| 30s soak 战况 | wave=0 phase=3 kills=9 alive=1 shots=4264 hp=100 | 同上 |
| 存档往返 | pass=13 fail=0 | `tmp/save_runner.tscn` |
| 桌面端产物 | `build\echo-streets.exe` 138720472 B（132.3MB），2026-11-26 08:52:32，sha256 前 16 位 `EBD689166F2F95F9`，启动零错误、`--write-movie` 出帧正常 | `--export-release` + 实跑 |
| 桌面端画面 | `tmp\movie\f00000014.png` 480x270，标题屏 `ECHO STREETS` + START/SETTINGS/QUIT 三按钮 | `--write-movie` |
| ch01 构建 | meshes 217 / bodies 147 / tris 7825 / lamps 41 / materials 15 / 679~794ms | `tmp/chapter_runner.tscn` |
| ch02 构建 | meshes 291 / bodies 229 / tris 5538 / lamps 25 / materials 13 / 425~530ms | 同上 |
| ch03 构建 | meshes 245 / bodies 47 / tris 7466 / lamps 41 / materials 13 / 558~680ms | 同上 |
| ch04 构建 | meshes 161 / bodies 153 / tris 4264 / lamps 8 / materials 11 / 281~335ms（sky=true） | 同上 |
| ch01 画面 | lum 0.707 / sd 0.176 / sat 0.080 / white 0.62% | `tmp/AuditShots.py` |
| ch02 画面 | lum 0.666 / sd 0.177 / sat 0.203 / white 1.06% | 同上 |
| ch03 画面 | lum 0.653 / sd 0.194 / sat 0.162 / white 0.10% | 同上 |
| ch04 画面 | lum 0.508 / sd 0.117 / sat 0.507 / white 0.00% | 同上 |
| 实战画面 `01_idle` | 88586 B，枪在中轴、枪管指屏幕深处、套筒顶面可见 | `tmp/shot_runner.tscn` |
| 开火扣弹 | mag 12→11 | 探针 |
| 射线伤害 | hp 100→78（pistol 22 × 1.0 非弱点） | 探针 |
| 池化基准还原 | 三次乘数 2.88→2.88→2.88，还原 2.40/100.0 | 探针 |
| 导演压力 | 0.36（警戒） | 探针 |

**`white%` 口径已变更**：`tmp/AuditShots.py` 每 3px 采样、`white = lum>=0.98`，会把**设计上就发光的灯板**（ch02 天花 `rgb(255,248,238)`）算进 white。历史基线「≤0.13%」用的是另一套判据（可能未算发光面），**不能跨口径对比**。同口径 A/B 已证明 white% 与材质像素化无关（`ch02_02_back` 两组都是 `0.650/0.208/0.220/1.17%/0.85%`）。
**`black` 已归零**：旧基线的 `black 7.06~7.41%` 全部是 `tmp/ChapterProbe.gd` 的 CRT 黑边伪影（`curvature=0.06` 从未被覆盖），四章 `with_post` 写 `curvature 0.0` 后 `black` 降到 0.00~0.19%。任何 `black>1%` 都要先怀疑取证器而不是场景。
**`soak` 的 fps 必须在 `--disable-vsync --max-fps 0` 下测**：默认跑会撞显示器 60Hz 上限得 59~60fps（假回归），加参数后 683.5fps。

## 9. 已知限制（未实现 / 未验证）

- **拖曳者（zombie_dragger）**仍是旧版 449B 占位图，AI 生图两次因内容审核失败（prompt 含"断腿血淋淋"），未做像素化重制，也未进 `wave_config` 的 `special_scenes`。
- **自爆者 / 尖啸者 / 冲锋者**只有立绘与速度/血量/伤害差异，**专属技能未实现**（自爆 AoE、尖啸召唤、冲锋突进）。
- **血特效着色器**（`blood_hit_effect*.gdshader`）已编译通过但**未接入命中流程**；`retro_palette_filter`、`zombie_hit_flash_2d` 同样未接线。
- **子弹/弹壳/血迹全对象池化**只做到丧尸池化，弹道特效走的是即时着色器，未池化。
- **同屏 60 只压力**只在专家脚本下验证过（avg 4.126ms），当前 30s soak 峰值只到 8 只，未在真实关卡复现 60 只。
- **局内肉鸽词条、三层武器库（科研特制 / BA 道具）、章节 BOSS、人形敌、追猎者**均未开始。
- **音频**完全空白（`assets/audio` 未建）。
- 手感参数（移速 6.0、后坐 12.0 回收、开火 kick 3.0）由 AI 设定，**未经人工试玩校准**——PDF 明确要求手感判断由人完成。
- **章节切换是 `reload_current_scene()` 整场重载**，没有过场动画、没有进度保留（只保留 `chapter_index`），每章从满血开局。
- **四章审核员全部已交付**（ch01 5/10、ch02 6/10、ch03 4.5/10、ch04 4/10），报告驱动的 P0 已修完；P1/P2 仍有残留（见第 5 节）。审核结论是量化 + 截帧，**未经人类美术复核**。
- ch02 `white=0.00%` / ch04 `sat=0.508`（落日天空本身高饱和，属设计意图）；四章 `sd` 0.10~0.23，低于「照片级」通常要求的 0.28+。**`sd` 偏低的主因是材质本身动态范围窄**（`CeramicFloor_White` R 通道只有 35/255），不是光照。补 `floor_seams` 铺装缝后 ch01 sd 0.168→0.169、ch02 0.173→0.178、ch03 0.195→0.196，说明结构线对 sd 贡献有限 —— 真正缺的是**材质本身的明暗变化**。
- ch02/ch03 有 0.5~1.5% 的 `lum<0.05` 像素，位置集中在 x≈230、y≈150 的工位显示器与扶梯深色扶手带，是真实深色物体（`MetalPlateWall` tint 0.34~0.42 乘烘焙 0.4 后落到 0.05 以下），不是死黑伪影。
- `BuildSky.gd` 的 `below_hvar` 自检阈值 0.002 与实测 0.0008 不匹配，阈值需按目视正确态重标（目视楼群已清晰可辨）。
- **顶点色上限是 1.0**：任何 `tint > 1.0` 都是死值，想更亮只能换更亮的材质。这一条限制决定了整套配色只能用「材质反照率 × ≤1.0 tint × 烘焙光」的乘积落进 [0,1]。
- **PDF 正文不可提取**（39 FlateDecode 流全是内嵌字体数据，无 pdftotext/pip）。`单文件 ≤ 300 行` 等硬红线依据 `project_memory.md:14` 的记录执行，已全部满足（最大 `zombie.gd 298`）。

## 10. 踩坑速查

| 症状 | 原因 | 正解 |
| --- | --- | --- |
| 中文源码变乱码、`\t` 变字面反斜杠t | PowerShell `Get-Content -Raw` 按 ANSI 读 UTF-8 再 `Set-Content -Encoding utf8` | **禁止用 PowerShell 正则改含非 ASCII 的源文件**，用 write 工具整文件重写 |
| C# 内联在 PowerShell here-string 里编译失败 | 中文注释被编码破坏，`//` 吞掉下一行 | C# 抽成独立纯 ASCII 文件，用 `Add-Type -Path` |
| `--script` 模式报 `Identifier not found: EventBus` | `--script` 不加载 Autoload | 改用最小 .tscn + `--headless res://xxx.tscn` 在场景树里跑 |
| `No loader found for resource: *.png` | PNG 无 `.import` 元数据 | 先跑 `--headless --import` |
| `Could not find type "HudWidgets"` | 新增 class_name 后未重导入 | 同上 |
| Godot 4 着色器注释报错 | 写成 `#` | 用 `//` |
| `fragment()` 内 `return` 报错 | Godot 4 禁止在 fragment 内 return | 改条件分支或提前算好 |
| Sprite3D 挂 canvas_item 着色器渲成灰块 | 着色器类型与节点不匹配 | 3D 用 spatial 版，贴图用 `set_shader_parameter("albedo_texture", tex)` 手动绑 |
| 无 texture 的 TextureRect 挂着色器无效果 | 整节点不绘制 | 改用 ColorRect |
| 中文字符**能**正常显示 | 4.7.2 默认字体会回退到系统字体，不需要自带 TTF | 实测 `tmp/shots/title/01_settings.png` 里 `CONTROLS: 求生之路（中键开镜 / 右键推挤）` 无方块。HUD 与教程文案用英文是**风格统一**（与 CH / WAVE / KILLS 同语言），不是字体限制 |
| AI 生图边缘洋红辉光 | 洋红键在剪影边缘造成 R、B 同高 | 降采样只算前景 + despill 削 R/B |
| 换章后丧尸全掉到环形兜底位 | `WaveSpawner._spawn_points_root` 是 `@onready` 缓存引用，整节点换掉后悬空 | 用 `ChapterBuilder.fill_spawns(data, holder)` 复用已有 `SpawnPoints`，只换子 Marker |
| 换章探针自己消失 / 进程挂到超时 | 探针挂在 `current_scene` 里被 `reload_current_scene()` 一起释放；启动器 `await` 的协程随场景销毁 | 探针挂 `get_tree().root` 下，收尾由探针自己 `print`+`quit`；`_ready` 里 `add_child` 到 root 会 busy，要 `call_deferred` → `await process_frame` → 同步 `add_child` |
| 地板/天花/墙整片消失 | `build_panel` 绕序判反（Godot 正面顺时针，可见条件是几何法线 = −顶点法线） | `flip = (u×v)·n < 0`，flip 真用 `[v00,v10,v01,v10,v11,v01]` |
| 材质全白、细节全丢 | 材质没开 `vertex_color_use_as_albedo`，烘焙顶点色被丢弃 | 用烘焙色的材质必须 `vertex_color_use_as_albedo = true` |
| 地面/墙面一片纯白削顶 | 多灯贡献直接相加超 1；硬 clamp 把 >1 全烧成同一片白 | `out = amb + (1-amb)*(1-exp(-sum))` 能量守恒饱和 + `LIGHT_GAIN` 找层次 |
| 发光面比周围天花暗，灯读成黑沟 | 发光面也走光照烘焙 | `panel(..., emissive=true)`，`build_panel` 直接写 tint 跳过烘焙 |
| 远处材质满屏黑点噪点 | `.import` 的 `mipmaps/generate=false` + `TEXTURE_FILTER_NEAREST` | 材质 `.import` 改 `mipmaps/generate=true`；材质过滤器改 `TEXTURE_FILTER_NEAREST_WITH_MIPMAPS` |
| 大面积地面出现棋盘摩尔纹 | 小尺度纹理（`PoolTiles` 200px 马赛克砖）铺几十米 | 小尺度纹理不铺大面积；换大尺度材质 + tint 调色 |
| 材质怎么调 tint 都不对 | 没量过材质本身平均色 | **先 `[Crop]::Avg(path,0,0,200,200)` 量平均色再选材质**，不靠 tint 硬拉 |
| 换章每次开局刷 "waves 为空" 警告 | `WaveSpawner._ready` 早于 `Level._ready` 检查 `waves` | 真实波次在 `Level._enter_tree()` 里塞进去 |
| 同一处 tint 改成 1.4、1.7 渲染值**逐字节相同** | **顶点色 8-bit UNORM 在 1.0 处硬截断**，>1.0 的 tint 全是死值 | 想更亮只能换更亮的材质，tint 必须 ≤1.0。排查：`Select-String -Path scripts\level\chapter_0*.gd -Pattern 'Color\(1\.[1-9]\|Color\([2-9]\.'` |
| `Get-Content` 看到源码全是 `涓ら棿鐜荤拑` 类乱码 | PowerShell 按 GBK 解码 UTF-8 文件，**只是显示乱码，文件没坏** | 判断文件是否真坏要用 read 工具，不要急着重写 |
| 改了 `with_post` 参数但截帧一个数字都不变 | `tmp/ChapterProbe.gd` 没有 PostFX 层，看到的是未过后期的原始烘焙 | 探针自建 layer=1 CanvasLayer + 铺满 ColorRect + `pixelzombie_postprocess`；`_apply_post` 先复位 7 个键再按章覆盖 |
| 接上后期后天花/走道烧成纯白 | tint 与 brightness 二次叠加（tint 曾为补偿"没挂后期"的假暗提到 1.3） | 所有 tint 与 brightness 必须在**挂后期的基线**上重新标定 |
| 白墙渲染成中灰（贴图 197 渲染 104） | `AMB_SKY` 太低 + 灯 range 覆盖不到 12 米外的墙，墙面只吃环境光 | `HORIZON_GAIN` 0.60→1.05，只放大 `\|n.y\|` 小的面，地板/天花不受影响 |
| 桌面/柱顶被自己脚下物体压成黑块 | AO 把"法线背面的遮挡物"也算进遮挡 | `if (closest - p).dot(n) <= 0.02: continue` —— 遮挡物必须在法线正半球 |
| 一排灯全不亮，读成天花上的深灰长条 | 发光面 UV 走 `p*0.5`，灯位坐标是格距整数倍 → `v` 恒为整数，NEAREST 压在第 0 行边框 | `if emissive: uvs[idx] = Vector2(0.5,0.5)` 锁死贴图中心；且 `tiled = tiled and not emissive`（**triplanar 会完全忽略网格 UV**） |
| 玻璃读成黑色实心墙 | `DEPTH_DRAW_OPAQUE` 让玻璃挡住身后深度，混合阶段拿不到背景 | `depth_draw_mode = DEPTH_DRAW_DISABLED` |
| 画面正中一条贯穿上下的竖线 | 沿视线轴延伸且过视点的细长物体必然投影成屏幕竖线（透视必然，改宽度无效） | 中轴不放任何沿 Z 延伸的细长特征；`ceiling_grid` 里 `if along_z and absf(center.x + t) < 0.6: continue` |
| 柱子四条竖棱糊成一团渐变 | 顶点太少（1.1 米宽柱子每面 2x4 顶点），顶点色被 Gouraud 插值抹平 | `box()` 加 `step` 参数，柱子传 0.4 |
| 天空楼群像"一栋楼贴着天台边竖起来" | 等距柱状上半 512px 对应 90°，**1px ≈ 0.176°**；楼高 170px = 30° 仰角 | 2 公里外 200m 高楼仰角 5.7° ≈ 32px。远层 4~14px、近层 20~64px |
| 城市地面画成"砖墙" | 轴对齐矩形 + 固定行距 + 贯穿全宽的街道线 = 砖缝 | 只要还在"矩形 + 固定行距"画法里怎么调都是砖。改「宽雾化渐变 + 低频亮度扰动」 |
| 探针 `FAIL 玩家受伤扣血 [dealt=0.0]` | 前面的用例里丧尸把玩家咬死，`take_damage` 因 `_is_dead` 返回 0 | `reset_player()` 而非 `heal()`（heal 只加血不复位 `_is_dead`） |
| `Nonexistent function 'max_health' in base 'Node'` | 静态类型是 `Node`，脚本属性不能点号访问 | `hc.get(&"max_health")` |
| 玻璃门/栏板/橱窗完全看不见，只剩几根青线 | 材质 alpha 是**与贴图 alpha 相乘**；`Glass.png` 自身 p50=26/255=0.102，章节再传 0.24~0.30 → 剩 3% | **章节 alpha 传 1.0**，让贴图的 0.102 当真实透明度。量法：`[TexAlpha]::Hist(path)` |
| 一面墙上的灯箱/招牌一个都不渲染 | panel 的 axis 法线朝墙外，玩家在墙内侧 → 全被背面剔除 | 左墙（x<0）法线朝 **+X** 传 `"x+"`，右墙朝 **−X** 传 `"x-"`。A/B 验证：错的方向黄像素 0，对的方向 1300 |
| emissive 灯箱变成纯黑方块 | 锁死 (0.5,0.5) 的贴图中心 texel 恰好是纯黑（`RGB_Screen`）或纯蓝（`ComputerScreen_BlueScreen`） | **屏幕类贴图不能当 emissive 面**。换 `WhiteCeiling_MetalEdge` 这类中心是亮色的材质 |
| 天花整片均匀灰雾、sd 只有全图一半 | 写好的 `ceiling_grid()` 从未被调用 | 天花必须显式 `d.add(K.ceiling_grid(...))`；**用 `"x"` 不用 `"z"`**（`"z"` 在中轴投影成竖线） |
| 柱础/踢脚线把自己压成纯黑（min 0.000） | AO 把采样点脚下的矮台座当遮挡物 | `OCCLUDER_MIN_TOP = 0.5`，矮于 0.5 米的台座不登记为遮挡体 |
| 墙脚一整条成片死黑（`dark<38` 达 30%） | 踢脚线 tint 0.48 × 深色金属反照率 0.312 × lit 0.51 × AO 0.12 ≈ 2/255 | 三重：踢脚线 tint → 0.95；`CONTACT_DARK` → 0.75；AO clamp 下限 → 0.30 |
| 天花恒比地板暗（0.673 vs 0.783） | `FLOOR_ALBEDO` 写 0.78（白瓷砖实测 0.92）、`BOUNCE_GAIN` 只有 0.26 | `FLOOR_ALBEDO` 0.92、`BOUNCE_GAIN` 0.34 |
| 白墙永远是中灰（贴图 197 渲染 83） | 灯 `range=6` 而墙距灯 8.13 米，墙面 100% 只吃环境光 | ①`HORIZON_GAIN` → 1.55（只放大 `\|n.y\|` 小的面）；②改**双排灯位**把墙面距灯压到 3.4 米 |
| 画面可见色阶断层 + dither 棋盘 + 幕墙压成平色块 | `palette_levels=8` / `dither_strength=1.0` / `curvature=0.06` 是 shader 默认，从未被章节 post 覆盖 | 四章 `with_post` 显式写 `palette_levels 24 / dither_strength 0.45 / curvature 0 / chromatic_aberration 0.35` |
| 发光面四周一圈黑框 | 发光面尺寸比灯槽小一圈，露出金属槽底 | 发光面放大到接近灯槽内沿；灯槽整体下沉到 y=`H-0.14`，避开格栅梁 |
| 画面正中一条横贯全宽的暗带 | `ceiling_grid` 的 along_x 梁正好过 z=0 视点 | `if not along_z and absf(center.z + t) < 0.6: continue` |
| 俯视截图里 15~23% 是背景色 / 只拍到天花背面 | 机位写死高度与 pitch，层高不同的章会穿出天花或穿出墙 | 从 geometry 取最高 `axis=="down"` 的 panel y 当层高上限，`cam_y = min(ceil_y−0.75, 4.9)`、pitch −52 |
| 贴墙家具背面与墙共面闪烁 | 位置用 `HALF_W − 半厚` 算，正好贴合 | 统一离墙 0.04 米 |
| 远处的前台/招牌只有几十像素 | 距离 40 米 + fov75 = 4.31 px/米 | 把主体前移（前台 −21.4→−16.0）并加宽，不要靠拉 fov |
| 玻璃底边一条纯暗红断层 | 玻璃底边与墙裙顶**精确共面** | 留 0.04 米间隙（玻璃高 `H-1.12`，底 0.94） |
| `Get-Content x.gd` 数出的行数比真实少一半（`light_baker.gd` 报 277 实际 412） | `Get-Content` 对无 BOM 的 UTF-8 + 混合换行计数不可靠 | 用 `([regex]::Matches([System.IO.File]::ReadAllText($p),"``n")).Count+1`，或 `cmd /c find /c /v """"` |
| `Set-Content -Encoding utf8` 生成的 `.tscn` 报 `Parse Error: Expected '['` | 该开关写入 UTF-8 **BOM**（`ef bb bf`），Godot 不认 | `[System.IO.File]::WriteAllText($p, $t, (New-Object System.Text.UTF8Encoding($false)))` |
| 改了 PNG 但截帧 sha256 逐字节不变 | Godot 读 `.godot/imported/*.ctex` 缓存，外部改图不触发重导入 | `Remove-Item .godot\imported\<name>.png-*.ctex, *.md5` 再 `--headless --import` |
| `--headless` 跑截帧报 `Parameter "t" is null` | headless 下 `get_viewport().get_texture().get_image()` 返回 null | 截帧类 runner **去掉 `--headless`** |
| 陶瓷地砖上出现一条贯穿消失点的竖线 | **两层**：①素材最外圈 1px 描边（`CeramicFloor_White` 边 206 vs 心 236）；②**内部真砖缝 col196-198 = 214**（砖面 236）。triplanar 使世界 x=0 采样 col0、x 略小于 0 时 fract 回绕到 col198，25 级台阶沿 Z 无限延伸过视点 | **只修描边没用**（修完 col0=col199 竖线仍在）。正解 `tmp/EdgeSeam.gd` 把贴图**沿 X 滚 100px**，砖缝落到世界 x≈0.97。实测逐列 L 最大偏差 18.9→**0.4**。**滚动只能滚一个轴** —— 同时滚 X/Y 会把边缘行移到中间变成横线 |
| 玻璃会议室读成"几根青线"或"不透明青白板" | `Glass.png` alpha p50=26/255；章节传 0.42 → 有效 4.3%；传 1.0 → `if alpha < 1.0` 不成立 → `TRANSPARENCY_DISABLED` | 判定改 `if alpha < 1.0 or tex_has_alpha:`；需要真玻璃的章用 `Glass_Pane.png`（alpha ×4）+ 章节 alpha 0.72 |
| 灯间天花出现规则暗斑（最低 113 vs 灯下 232） | 灯槽 `box()` 第 5 参 `body` 缺省 true → 灯槽进 AO 遮挡网格，槽顶距天花仅 0.095 米 | 灯槽 `body=false`（**ch02 早就这么写了，ch01 漏了**） |
| 只加 `SUN_DIR` 方向光，左右两侧亮度仍逐位相同 | ①`SUN_AMB_GAIN` 抬 amb 会压缩直射项（`out = amb+(1-amb)(1-e^-sum)` 里 amb 出现两处且符号相反）；②`HORIZON_GAIN 1.55` 把垂直面 amb 顶到 0.994，`(1-amb)` 只剩 0.006 | `SUN_AMB_GAIN` 必须 0.0；露天章 `horizon_gain` 置 0（`with_sky` 第 4 参 sun>0 时自动） |
| 关掉 `horizon_gain` 后整章变灰、`lum` 跌破 0.45 | 它同时是垂直面与地面的天光来源，不只是"提亮补偿" | 抬 `with_ambient`（ch04 到 0.62/0.57/0.52 + 0.42/0.38/0.34）并抬地面 tint 到 0.80 |
| 露天章地面读成一片均匀灰（`gsd` 0.03~0.05） | 单张 200px 材质铺 30×34 米，无分块无接缝 | 加 4 块微差色 patch + 4 条横向伸缩缝；**缝不能沿 Z 铺**（过视点投影成贯穿竖线） |
| 加 `contrast` 后整章削顶 5.89% | `contrast` 与 `brightness` 同向叠加 | 抬 contrast 必须反向降 brightness（ch03 定 1.04/1.12/1.18） |
| 拆分后 `Parse Error: Function "xxx()" not found` | 切片删函数体时把相邻的小工具函数一起删了（`weapon.gd` 的 `_exclude_rids()`） | 拆完必须跑 `probe_runner`（34 断言），不能只看 `--import` 无报错 |
| `Cyclic reference` | props 子模块 `preload` 父文件，父文件又 `preload` 子模块 | 子模块**重复声明**尺寸常量，不反向 preload；转发用 `load("...").fn()` 而非 preload alias |
| `powershell -File x.ps1` 报 `error 800705af` | Windows PowerShell 5.1 托管运行时加载失败（与项目无关） | 用当前 pwsh 内联 `Add-Type -AssemblyName System.Drawing`，不要开 5.1 子进程 |
| 图像统计输出 `n=0 mean=NaN min=1.000` | PowerShell 变量名**大小写不敏感**，`$W`（宽）与 `$w`（白像素计数）是同一个变量 | 宽度用 `$wpx`、计数用 `$cntw`、累加用 `$acc` |
| 加 `rot` 的构件（太阳能板/扶梯）被甩到别处、柱子留在原地 | `light_baker.build_box` 顶点是**世界坐标**（顶点色要按世界位置采样灯光），`mi.rotation_degrees` 会让网格绕**世界原点**转 | 套 pivot 节点：`pivot.position = center` + `pivot.rotation_degrees = rot` + `mi.position = -center`（`T(c)·R·T(-c)·v = R·(v-c)+c`）。实测 ch04 板被抬到 y≈3.08 |
| 整片地面读成"一块白塑料/棕雾/蓝白塑料"，没有尺度感 | 贴图自带砖缝被 mipmap 抹平（`CeramicFloor_White` 世界 2 米一格、宽 2cm，480x270 下不到 1px） | `K.floor_seams(center, span, step, mat, tint, width)` 显式铺铺装缝（ch01 4.0 / ch02 2.4 / ch03 2.0 米）。**世界 x≈0 或 z≈0 的那条必须跳过**，否则投影成劈开画面的线 |
| 天花分缝梁完全看不见（相对对比度 7.5~10.9%） | 梁 tint 与吊顶只差 4.5%（0.84 vs 0.88），24 阶量化后差不到 2 级 | 梁 tint 到 **0.70**（20% 相对对比度）才读得出是梁；再低就读成"脏污" |
| 手绘 viewmodel 前臂变成一根贯穿画面的宽板 | 前臂沿枪轴方向延展（枪轴旋转后指向左上，顺着往右下延就连成斜带） | 方向必须朝**屏幕下方** `(0.30,0.95)`；宽度 ≤ 枪身厚度 1.5 倍；`reach` 越过裁剪窗口下缘由窗口切边 |
| 握枪的手读成"香肠" | 四指整根画在握把前侧，露出来的部分太多 | 手指锚在握把前缘直线 `(44,-8)→(30,-54)`（斜率 0.3043）上，只露 5 单位指背；正拳握持时手指大部分被握把挡住 |
| 霰弹枪护木上"粘了四颗肉色胶囊" | 在紧贴枪管上沿的位置画了露出的指节 | 前手只画手背帆布 + 三道指缝，不画指节 |
| 3D BoxMesh 拼的枪在 132px 尺度读成"一堆方块" | 低分辨率下体积感靠插画的明暗分层，不靠几何面 | **不要走 3D 渲染路线**。用 AI 生图底板 + 降采样量化 |
| AI 抠图把白袖口/皮肤一起抠掉 | 洋红判定用亮度阈值，白袖口与皮肤亮度同样高 | 用**色相**：`bg = ((r-g) > 80) & ((b-g) > 20)`。洋红 `(247,127,190)` 满足，皮肤 `(241,191,158)` 的 `r-g=50` 不满足 |
| numpy 亮度直方图出现 `lum=-11` 等负值 | `255*587` 在 int16 下溢出 | 亮度必须 `astype(np.int32)` |
| 像素画动画帧旋转后边缘锯齿断线 | 像素画没有抗锯齿，旋转必然产生非整数像素 | 只用**整数像素平移** `shift(im,dy,dx)`，画布尺寸不变 |
| 导出后启动 exe 抓到全黑窗口 | OpenGL 内容不在 GDI 表面上，`PrintWindow` 抓不到；`CopyFromScreen` 会被 DSH web GUI 覆盖 | 用 `--write-movie "path/f.png" --fixed-fps 8 --quit-after 24` 拿真实渲染帧 |
| 导出后误读 `godot.log` 有错误 | 日志文件是上一次运行残留 | 启动前 `Remove-Item`，`logbytes=0` 才算零错误 |
| `palette_levels` 从 24 降到 12 后全章 `lum` 系统性降 0.02 | `floor()` 量化的平均损失 = `-0.5/L`，L 减半使损失翻倍 | 补偿只需 **新增量** `0.5/12-0.5/24 = 0.0208`（旧损失已含在原 lift 里）。用 lift 补，**不要用 brightness**（乘法会把近 1.0 像素推成纯白，white% 反涨） |
| 材质像素化后 `white%` 从 0.13% 涨到 1.42% | 判据口径变了：`AuditShots.py` 的 `white = lum>=0.98` 把**设计上就发光的灯板**（ch02 天花 `rgb(255,248,238)`）算进去了 | 同口径 A/B 才是判据。把 `tmp\mat_orig` 恢复后重跑，两组逐位相同 → 与像素化无关。**不能跨口径对比历史基线** |
| 像素化后担心引入接缝 | 降采样 + 量化确实会改变边缘 texel | 实测**边缘绝对亮度差全部变小或持平**（`ExitDoor` 124.4→25.3、`SolarPanel` 156.6→93.8）。最大亮度也普遍降低（`Locker` 239→255 例外），不可能造成削顶 |
| 统计截帧时数字莫名偏大 | `tmp\shots\chapter` 混有旧审核截图 `audit3_*` / `k_*` / `n_*` | 只读 `ch0*.png` |
| `soak` 帧率从 143fps 掉到 59fps | 显示器 60Hz 垂直同步上限，不是性能回归 | 必须 `--disable-vsync --max-fps 0` 才有比较意义（实测 683.5fps） |
| `ValueError: Fast Octree (method == 2) and libimagequant (method == 3) are the only valid methods for quantizing RGBA images` | PIL 的 `MEDIANCUT` 不支持 RGBA | 剥 alpha → RGB 量化 → `putalpha` 贴回 |
| viewmodel 枪管"朝天花板" | 拿 AI 生成的**纯侧视剖面**（高宽比 0.98）旋转 70 度硬凑「枪管竖直」。侧视图没有顶面，旋转只能得到转来转去的侧视图 | **判据是「有没有顶面透视」不是角度数值**：参考帧枪身 bbox 112x250、高宽比 2.23，看到套筒顶面与背面，枪口远处变小（`taper` 行宽 `25 52 78 87 79 50 25`）。正解：**直接沿用参考帧几何，只换材质配色** |
| 用 PCA 主轴 / 枪口 x 均值当"枪管角度" | 手部大面积像素把主轴拉偏，把参考帧误读成 `+10.5°` | 排除 `skin`/`shirt`/`navy` 后只对 `gun` 掩码算。但**角度仍不能当唯一判据**（扫角最小误差同时出现在 `delta=-24` 与 `-70` 两个解） |
| 识别条画成"一块突兀的青色方块盖在枪身上" | 用固定矩形 `band` 画色块 | **沿 gun 掩码每列最上缘铺 1~2px**：`for x in range(gx0+span*0.25, gx0+span*0.85)` + `if top > gy0+(gy1-gy0)*0.55: continue` |
| `Image.rotate(a)` 后角度读数反而变大 | PIL 旋转符号与直觉相反 | 实测 `rotate(+28.9)` 让 `gun_axis` 从 117.9 → 147.0，即**读数增加** |
| 魔搭 API `POST /v1/images/generations` 报 401 | `{"errors":{"message":"Please bind your Alibaba Cloud account before use."}}` —— token 有效但账号未绑阿里云；且 `/v1/models` 返回的 38 个模型里**没有文生图**，只有两个图像编辑模型 | 魔搭路线废弃，改用 `trae_draw_image` |
| `trae_draw_image` 连续 504 | `504 Gateway Time-out ... Powered by volc-dcdn`，与 VPN 有关 | 失败有 30 秒冷却（"上一次生图刚失败过，请 23 秒后再试"）。降敏 prompt 可绕 `code=2001 image security check failed` |
| `SyntaxWarning: "\m" is an invalid escape sequence` | Python docstring 里写了 `D:\mygame` | docstring 加 `r` 前缀 |
| `| Select-Object -First 3` 后 Python 退出码 1 | 截断管道导致 Python 收 SIGPIPE | 用 `Select-String` 过滤或全量输出 |
| `Select-String` 过滤 Godot 的 `print` 输出后一个字都没有 | Godot 的 stdout 与 pwsh 管道交互异常 | `*>&1 | Out-File tmp\x.txt -Encoding utf8` 整份落文件再读 |

## 11. 术语表

| 术语 | 定义 |
| --- | --- |
| 纸片人 | Sprite3D billboard 贴 2D 立绘，不转向，只用 `flip_h` 表现朝向 |
| 池化乘数累积 | 对象池复用实例时难度乘数被反复乘到基础值上导致指数膨胀 |
| 处决慢动作 | 弱点击杀按概率触发 `Engine.time_scale=0.25`，0.4~0.6 秒恢复 |
| 导演系统 | 按玩家生命/弹药/最近受击间隔/敌人密度四路加权算压力，输出刷怪间隔与特感权重 |
| 契约探针 | `tmp/Probe.gd`，加载 main.tscn 逐项断言节点契约与运行时行为 |
| soak | 连续真实推进 30 秒并持续开火，验证帧率与循环不崩 |
