# ECHO STREETS

像素风丧尸 FPS，Godot 4.7（`gl_compatibility` 渲染后端）。逻辑分辨率 480x270，`TEXTURE_FILTER_NEAREST`，全部贴图在构建期烘焙顶点色，运行时不点灯。

## 现状

四章 demo 已闭环，可从标题屏进入、逐章推进、通关存档：

| 章节 | 场景 | 尺寸 | 击杀目标 |
| --- | --- | --- | --- |
| ch01 | ECHO LOBBY（白石大堂 + 方柱 + 幕墙） | 22 x 46 x 3.6 m | 92 |
| ch02 | OFFICE FLOOR（木地板 + 工位 + 玻璃会议室） | 24 x 40 x 3.2 m | 102 |
| ch03 | MALL ATRIUM（冷蓝瓷砖 + 二层环廊 + 橱窗） | 26 x 36 x 5.2 m | 114 |
| ch04 | ROOFTOP DECK（水泥停机坪 + 落日天空 + 太阳能板） | 30 x 34 x 6 m | 132 |

## 操作

两套方案，设置面板（`O`）里可随时切换，切换即重绑 InputMap：

| 动作 | 求生之路方案（默认） | 经典方案 |
| --- | --- | --- |
| 开火 | 左键 | 左键 |
| 开镜 | 中键 | 右键 |
| 推挤丧尸 | 右键 | `V` |
| 换弹 / 交互 / 设置 / 暂停 | `R` / `E` / `O` / `ESC` | 同左 |

移动 `WASD`，疾跑 `Shift`，蹲 `Ctrl` 或 `C`，跳 `Space`，换枪 `1` `2` 或滚轮。

## 目录

```
assets/     贴图、材质、精灵帧（丧尸 80 帧、viewmodel 20 帧）
data/       WeaponData 资源（伤害、射速、散布、后坐）
docs/       美术生图提示词库
scenes/     8 个场景：title / main / player / wave_spawner / director / 四种丧尸
scripts/    core（事件总线、输入、存档、设置）level（章节构建、光照烘焙）player weapons enemies ui
shaders/    丧尸受击闪白、像素后期、全景天空旋转
tmp/        素材管线脚本（Python / C# / GDScript）。图片与截帧不入库，只留脚本
```

## 运行

```powershell
godot --path . --headless --import          # 首次必须，刷新 global_script_class_cache
godot --path .
```

导出 Windows 桌面端：`export_presets.cfg` 已配好单文件内嵌 pck，产物在 `build/`（不入库）。

## 素材管线

`assets/` 下的成品全部由 `tmp/` 里的脚本生成，脚本入库、中间图不入库，所以整条链路可复现：

- 丧尸帧：`tmp/ZombieAnim.cs` → 5 状态 20 帧 x 4 变体 = 80 张 128x96
- viewmodel：`tmp/VmRebuild.py`（掩码换材质）→ `tmp/VmFrames3.py`（降采样 + 量化）→ 20 帧
- 天空：`tmp/BuildSky.gd` → 2048x1024 等距柱状

`docs/art_generation_todo.md` 是待人工生图的提示词清单，美术基调为现实硬核，禁止科幻装饰件。
