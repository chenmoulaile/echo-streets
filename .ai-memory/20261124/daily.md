# 20261124 · daily

## [18:16] - 任务启动：读 PDF + 专家分工

- **文件**：`tmp/pdf_text.txt`（提取的 459 行需求原文）
- **决策**：召唤「Godot 玩法脚本工程师」与「Godot 着色器开发者」两位专家并行交付脚本层与着色器层
- **验证**：专家交付 14 个 .gd + 7 个 .gdshader，各自声称冒烟测试通过

## [18:55] - 缺陷定位：输入动作名全不匹配

- **文件**：`scripts/core/input_setup.gd`（重写 72 行）、`scripts/core/game_manager.gd`
- **决策**：以消费方为准（`player.gd` 读 `fire`/`reload`/`weapon_1..3`/`jump`/`sprint`/`crouch`/`move_*`，`game_manager.gd` 读 `pause`），重写 InputSetup 动作表
- **验证**：`InputSetup.missing_actions()` 与 `unbound_actions()` 均返回空

## [19:00] - 缺陷修复：池化数值指数膨胀

- **文件**：`scripts/enemies/zombie.gd`、后续重构入 `scripts/enemies/zombie_base.gd`
- **决策**：`_ready` 记录 `_base_move_speed`/`_base_max_health`，`_on_pool_acquired` 先还原再加乘数
- **验证**：探针实测三次出池乘数恒为 2.88，还原值 2.40/100.0

## [19:14] - 场景生成链路打通

- **文件**：`tmp/BuildWorld.gd`（改为 `extends Node`）、`tmp/build_runner.tscn`
- **决策**：`--script` 模式不加载 Autoload，改用最小 .tscn 在场景树里跑构建器
- **验证**：8 个 .tscn + 7 个 .tres + project.godot 全部写出，无 SCRIPT ERROR

## [19:20] - 端到端契约探针

- **文件**：`tmp/Probe.gd`、`tmp/probe_runner.tscn`
- **决策**：断言按真实契约写，避免把池中休眠实例当活跃丧尸
- **验证**：pass=33 fail=0

## [19:37] - 画面缺陷量化与修复

- **文件**：`tmp/Sample.cs`、`tmp/regen_look.py`、`scripts/ui/hud*.gd`、`tmp/BuildWorld.gd`
- **决策**：用 System.Drawing 采样命名区域平均亮度做客观判据，不靠主观描述
- **验证**：whole 亮度 6 → 76；墙 13 → 107；地面 7 → 78

## [19:43] - viewmodel 四版迭代

- **文件**：`tmp/regen_viewmodel.py`、`assets/sprites/weapon_*_hud.png`
- **决策**：放弃对角线主轴，改竖直构图（枪口朝画布中上方）；用 (u,v) 局部坐标斜矩形填充保证厚度
- **验证**：截帧目视确认为竖直手枪 + 手套 + 手腕；`MUZZLE_ANCHOR` 同步改为 (404,139)

## [19:47] - HUD 拆分（300 行红线）

- **文件**：`scripts/ui/hud_widgets.gd`（256 行，新建）、`scripts/ui/hud.gd`（398 → 196 行）
- **决策**：读数部件与动画归 HudWidgets，状态文字与 EventBus 接线归 Hud
- **验证**：`--headless --import` 后截帧四张全部正常

## [20:00] - 缺陷修复：zombie.gd 超行数

- **文件**：`scripts/enemies/zombie_base.gd`（94 行，新建）、`scripts/enemies/zombie.gd`（341 → 240 行）
- **决策**：池化生命周期与自省接口抽基类，AI 状态机留子类；外部契约零变更
- **验证**：探针仍 pass=33 fail=0，截帧正常

## [20:03] - 缺陷修复：启动报 no main scene defined

- **文件**：`tmp/BuildWorld.gd:342`、`project.godot`
- **决策**：`ProjectSettings.set_setting` 键名必须写全 `application/run/main_scene`；并清理误落在 `[run]` 段的残留键
- **验证**：`--headless --quit-after 300` 与带窗口 `--quit-after 400` 均无 SCRIPT ERROR

## [20:06] - 30 秒实战 soak

- **文件**：`tmp/Soak.gd`、`tmp/soak_runner.tscn`（新建）
- **决策**：每帧自动瞄准最近活跃丧尸并开火，空仓自动换弹，模拟真实战斗压力
- **验证**：frames=1817 avg_dt=16.786ms fps=59.6 worst=146.4ms；wave=0 phase=3 kills=5 alive=3 shots=1797 hp=100；RESULT PASS

## [20:08] - 项目记忆落盘

- **文件**：`.ai-memory/project_memory.md`、`.ai-memory/20261124/topics.md`、`.ai-memory/20261124/daily.md`
- **决策**：单文件入口 + 当日分层，覆盖身份/架构/节点契约/缺陷回归清单/素材管线/验证链/实测基线/已知限制/踩坑速查/术语表
- **验证**：文件已写入

## [13:00] - 场景材质像素化（27 张）

- **文件**：`tmp/MatPixel.py`（新建）、`assets/materials/*.png`、备份 `tmp/mat_orig/`
- **决策**：`Image.BOX` 降采样到 1/3 → 中位切分量化 12 色 → `NEAREST` 回放原尺寸，保持文件尺寸与 `.import` 不变
- **验证**：9579 → 317 色（3.3%）；A/B 证明不引入新接缝（`ExitDoor` 边缘差 124.4→25.3）、最大亮度普遍降低、white% 同口径逐位不变

## [13:10] - 后处理调色板 24 → 12 + 量化损失补偿

- **文件**：`shaders/pixelzombie_postprocess.gdshader`、四章 `with_post`
- **决策**：`palette_levels 12.0` / `dither_strength 0.18` / lift 各加 `0.0208` 增量；**不能用 brightness 补偿**（乘法会把近 1.0 像素推成纯白）
- **验证**：ch01 `0.707/0.176`、ch02 `0.666/0.177`、ch03 `0.653/0.194`、ch04 `0.508/0.117`，与像素化前基线逐项吻合

## [13:20] - 全量回归 + vsync 假回归

- **文件**：`tmp/soak_runner.tscn`
- **决策**：soak 必须 `--disable-vsync --max-fps 0`，否则撞 60Hz 上限得 59fps
- **验证**：probe 34 / advance 14 / chapter_flow 79 / save 13 全过；soak 683.5fps PASS

## [15:36] - viewmodel 透视根因修复（第 12 轮定稿）

- **文件**：`tmp/VmRebuild.py`（新建）、`tmp/VmFrames3.py`（新建）、`assets/sprites/viewmodel/*.png`（20 帧）、`scripts/ui/viewmodel.gd`
- **决策**：**几何直接沿用参考帧，只换材质配色**。根因是「AI 侧视剖面旋转 70 度」永远得不到顶面透视 —— 参考帧枪身高宽比 2.23 是强透视压缩，判据是「有没有顶面透视」而不是角度数值
- **验证**：手枪 146x150 / 霰弹枪 259x150；`shot_runner` 4 张实机截帧枪在中轴、枪管指屏幕深处、套筒顶面与青色识别线可见、前臂从底边出画

## [15:44] - 桌面端重导 + 打包版取证

- **文件**：`build/echo-streets.exe`（121561672 B）
- **决策**：`--write-movie "D:/mygame/tmp/movie/f.png" --fixed-fps 8 --quit-after 20` 是唯一可靠的导出版本取证方式（`PrintWindow` 全黑、`CopyFromScreen` 会被 DSH GUI 覆盖）
- **验证**：20 帧全出，`f00000012.png` 目视 ch01 大堂 + HUD + 新 viewmodel 正常

## [15:51] - 项目记忆更新

- **文件**：`.ai-memory/project_memory.md`（431 → 456 行）、`20261124/topics.md`、`20261124/daily.md`
- **决策**：第 1 节阶段/产物更新；第 6 节新增「场景材质像素化」「后处理像素化」两段 + viewmodel 12 轮全史 + 魔搭 API 不可用结论；第 8 节基线换新并标注 `white%` 口径变更；第 10 节补 18 条踩坑
- **验证**：文件已写入
