# echo-streets · 需人工生图清单

> 本文件只是提示词。生图由你执行。所有路径是绝对路径，直接复制。
> 总基调：现实硬核 + 纯黑主色。禁发光条、彩色识别带、镀铬反光、木纹雕花。
> **BA 的定位（PDF 第二章第五节）**：蔚蓝档案是**可在设置中开关的拓展模块，默认关闭，关闭后 BA 资源不加载**。所以 BA 只能当**配色/画风参考**用，不能当**角色身份来源** —— viewmodel 的手臂属于本体，必须原创，不能带任何 BA 语言（尤其不能是「白衬衫 + 深藏青校服」那套日式学生制服）。

---

## 1. viewmodel 手枪

**只需生成 1 张**：`D:\mygame\assets\sprites\viewmodel\vm_pistol_idle.png`（146x150）
其余 9 帧（dry / fire1-3 / reload1-4 / draw）由 `D:\mygame\tmp\VmFrames3.py` 派生。

**参考图**（构图以 BOOMDoA 为准 — `tmp\fp_png\` 就是 `D:\BOOMDoA 1.10` 解包出来的 FirstPerson 帧）
- 构图：`D:\mygame\tmp\fp_png\Handgun__HandgunIdle.png`（253x266）
- 配色：`D:\Bluearchive\repo\resources\ui\local\uis-01_common-04_weapon-_mxload\Weapon_Icon_CH0263.png`
- 手臂：**不给参考图，按下面「持枪手」段从剧情推断**（BA 半身像是日式学生制服，与本体冲突，不能当手臂参考）

**出图**：1920x1920，纯洋红 `#FF00FF` 背景。

**提示词**
```
像素风第一人称持枪视角（FPS viewmodel），1920x1920，纯洋红 #FF00FF 背景。

构图：一支手枪位于画面中轴偏右，枪管指向画面深处（朝屏幕里），因此看到套筒顶面、照门与枪口端面，枪口在远端因透视变小。整枪在画面上的高宽比约 2.2:1（纵向长、横向窄）。前臂从画面右下角出画，白色衬衫袖口横切画面底部。不要画成侧面剖面图（侧视高宽比约 1:1，能看到整条套筒侧面，是错的）。

面积配比：枪身占不透明面积 55~65%，手占 25~30%，袖子袖口不超过 15%。枪是主体，手只是握持的附属。

枪械：Glock 17 风格现代聚合物套筒座手枪。套筒与枪管哑光黑磷化钢，套筒座哑光黑聚合物，握把细密菱形防滑纹，方形扳机护圈，黑色准星与方形照门，无外置击锤。枪身只有中性黑到深灰的明度梯度： #010102 #0F1115 #1F2229 #2B2F38 #373C47 #3F4552 #585E6A，冷通道比红通道高 8~19（磷化钢的冷调）。枪身上不允许出现任何彩色像素。

持枪手（原创，按剧情推断）：主角是灾变当晚在商业楼里被卷入的普通人，非军警，所以手上没有制式装备，只有日常穿着。一只裸露的右手，无手套，手背朝上，四指从右侧包住握把前缘，拇指压在套筒座左侧。肤色 #C99B79（暖褐，不是粉色，避免日式动画感），暗部 #96694E，高光 #E0B79A，指关节与虎口有轻微污渍 #8A7462。手腕处卷起的袖口是厚实的深灰工装/衬衫袖——不是白衬衫，白衬衫是 BA 学生制服语言。袖口本色 #6B6157（灰褐），暗部 #4A423B，高光 #857A6E；从袖口向外是深灰针织或粗棉袖筒，两档 #4A423B #3A342F，从画面右下角出画。手腕上可以有一块朴素的黑色电子表带 #1F2229。不要画手套、护腕、战术背心、制服徽章、校服领。

画风：粗黑描边（描边宽约成图 15~20px）、大面积平涂、单层硬边阴影、无渐变、无高光反射、无抗锯齿、无景深模糊、限定 12 色。
```

**负面词**
```
彩色条纹, 青色识别条, 识别色带, 发光条, 霓虹, LED, 全息瞄具, 蓝色发光件, 科幻, 赛博朋克, 未来武器, 能量武器, 无功能装饰块, greeble, 镀铬高光, 镜面反光, 橙色枪口帽, 木纹, 雕花, 贴纸, 徽章, 玩具枪, 塑料感, 过饱和, 渐变, 抗锯齿, 景深模糊, 侧面剖面, 斜视, 第二只手, 弹壳, 火光, 文字水印
```

---

## 2. viewmodel 霰弹枪

**只需生成 1 张**：`D:\mygame\assets\sprites\viewmodel\vm_shotgun_idle.png`（259x150）
其余 9 帧（fire1-5 / reload1-2 / draw / altfire）同脚本派生。

**参考图**（构图以 BOOMDoA 为准 — `tmp\fp_png\` 就是 `D:\BOOMDoA 1.10` 解包出来的 FirstPerson 帧）
- 构图：`D:\mygame\tmp\fp_png\Shotgun__ShotgunIdle.png`（464x275）
- 配色：`D:\Bluearchive\repo\resources\ui\local\uis-01_common-04_weapon-_mxload\Weapon_Icon_26002.png`
- 手臂：同第 1 节（按剧情推断，不用 BA 学生制服）
**出图**：1920x1920，纯洋红 `#FF00FF` 背景。

**提示词**：整段复制第 1 节，只换下面两段，其余不动。

换「枪械」句为：
```
枪械：Remington 870 风格泵动霰弹枪。长枪管在上、弹仓管在下，两根平行黑管；中间是可前后滑动的黑色聚合物泵柄护木；机匣方正带抛壳口；后部黑色聚合物枪托带橡胶托底板；顶部细窄瞄准肋条与一颗铜色小珠准星。全枪哑光黑磷化，明度梯度同上，没有木件、没有雕花、没有贴纸。
```

换「持枪手」段为：
```
双手（原创）：右手握枪托后的握把（画面右下），左手托住泵柄护木（画面中央偏左），两只都是裸露的手，肤色与袖口规格同第 1 节；左前臂从画面左侧出画，右前臂从右下角出画，两只前臂都不占画面宽度超过 1/6，袖口只露手腕那一圈卷边。
```

**负面词**：同第 1 节。

---

## 3. HUD 武器图标（5 张，各 160x120）

**落地路径**
- `D:\mygame\assets\sprites\weapon_pistol_hud.png`（重画）
- `D:\mygame\assets\sprites\weapon_shotgun_hud.png`（重画）
- `D:\mygame\assets\sprites\weapon_icon_smg.png`（新增）
- `D:\mygame\assets\sprites\weapon_icon_rifle.png`（新增）
- `D:\mygame\assets\sprites\weapon_icon_launcher.png`（新增）

**参考图**
- `D:\Bluearchive\repo\resources\ui\local\uis-01_common-04_weapon-_mxload\Weapon_Icon_CH0263.png`（主参考）
- `D:\Bluearchive\repo\resources\ui\local\uis-01_common-04_weapon-_mxload\Weapon_Icon_13002.png`（灰阶梯度）
- `D:\Bluearchive\repo\resources\ui\local\uis-01_common-04_weapon-_mxload\Weapon_Icon_10020.png`（手枪）
- `D:\Bluearchive\repo\resources\ui\local\uis-01_common-04_weapon-_mxload\Weapon_Icon_26002.png`（霰弹枪）

**出图**：1920x1920 方形，纯洋红 `#FF00FF` 背景（管线自动缩到 160x120）。

**提示词（通用骨架，只换最后的主体句）**
```
像素风武器图标，严格正侧视，方形画幅，纯洋红 #FF00FF 背景。{主体}。

全枪哑光黑，只有中性黑到深灰的七档明度： #010102 #0F1115 #1F2229 #2B2F38 #373C47 #3F4552 #585E6A，冷通道比红通道高 8~19。只有棱边有 1px 磨损露白（磷化层磨穿），这是全图唯一的高光。

粗像素块、清晰硬边、无渐变、无抗锯齿、限定 12 色。枪身水平居中占满画布宽度 85%，不画手、不画弹壳、不画火光、不画文字。
```

**主体五句（各用一次）**
```
1. Glock 17 风格现代聚合物套筒座手枪，短套筒、方形扳机护圈、黑色准星与照门、无外置击锤、直形弹匣底板与握把齐平
2. Remington 870 风格泵动霰弹枪，上枪管下弹仓管两根平行黑管、中间黑色聚合物泵柄护木、黑色聚合物枪托、顶部瞄准肋条与铜色小珠准星
3. HK MP5A3 冲锋枪，圆柱形机匣、细长裸露枪管、枪管下方黑色聚合物前握把、可伸缩金属枪托收到最短、直形弹匣
4. M4A1 卡宾枪，平顶机匣加皮卡汀尼导轨、30 发弯弹匣、三角形护木、可调伸缩枪托，导轨上装一个 ACOG 四倍镜（镜筒黑、镜片深墨绿无反光）
5. M32A1 转轮式榴弹发射器，六发转轮弹巢、粗短膛口、顶部折叠机械瞄具、下挂手枪握把、折叠枪托
```

**负面词**：同第 1 节。

---

## 4. 其余待生图

### 4.1 拖曳者立绘
- 落地：`D:\mygame\assets\sprites\zombie_dragger.png`（96x96，透明底）
- 参考：`D:\mygame\assets\sprites\zombie_fodder.png`
```
像素风格丧尸立绘，正面朝向，全身，96x96 游戏精灵图。一个只剩上半身的丧尸，拖着残破躯干用双手在地上爬行，腹腔拖出暗红色残骸（不要血淋淋的写实细节，用深红褐色块表现），头部歪斜、下颌脱臼，皮肤灰绿带尸斑。粗像素块、清晰硬边、无渐变、无抗锯齿、限定 16 色复古调色板、90 年代 DOS 游戏美术质感。纯洋红 #FF00FF 背景，角色脚底贴画布底边。
```

### 4.2 章节 BOSS 立绘
- 落地：`D:\mygame\assets\sprites\boss_echo.png`（192x192，透明底）
- 参考：`D:\mygame\assets\sprites\zombie_charger.png`（体型）、`D:\mygame\assets\sprites\zombie_bomber.png`（装备）
```
像素风格 BOSS 立绘，正面朝向，全身，192x192 游戏精灵图。一个 2.5 米高的巨型丧尸保安，穿着破裂的深藏青安保制服与战术背心，右臂是裸露的肌肉与外露的金属骨骼，左手拖着一根断裂的灯柱当武器，头部戴着碎裂的防暴头盔、面罩后透出青色荧光眼。粗像素块、清晰硬边、无渐变、无抗锯齿、限定 24 色复古调色板、90 年代 DOS 游戏美术质感。纯洋红 #FF00FF 背景，脚底贴画布底边。
```
- 注：青色荧光眼属生物体异常，不受纯黑约束。

### 4.3 局内词条图标（8 个，各 32x32）
- 落地：`D:\mygame\assets\sprites\perk_bullet.png` / `perk_fist.png` / `perk_heart.png` / `perk_boots.png` / `perk_mag.png` / `perk_eye.png` / `perk_skull.png` / `perk_coin.png`
- 参考：无
```
像素风格技能图标，32x32，游戏 UI 图标。{SUBJECT}，居中构图，粗像素块、清晰硬边、无渐变、无抗锯齿、限定 8 色高对比调色板、90 年代 DOS 游戏 UI 质感。纯洋红 #FF00FF 背景。
```
- `{SUBJECT}`：`一颗发青光的子弹` / `一只握紧的拳头带冲击波` / `一个心脏带十字` / `一双跑鞋带速度线` / `一个弹匣带加号` / `一只眼睛带准星` / `一个骷髅头带闪电` / `一枚金币带双箭头`

### 4.4 章节过场插图（4 张，各 480x270）
- 落地：`D:\mygame\assets\textures\chapter_card_01.png` / `chapter_card_02.png` / `chapter_card_03.png` / `chapter_card_04.png`
- 参考（照实际构图，否则对不上）：
  `D:\mygame\tmp\shots\chapter\ch01_00_player.png`
  `D:\mygame\tmp\shots\chapter\ch02_00_player.png`
  `D:\mygame\tmp\shots\chapter\ch03_00_player.png`
  `D:\mygame\tmp\shots\chapter\ch04_00_player.png`
```
像素风格游戏过场插图，480x270，宽幅。一座现代办公楼大堂的纵深视角：白石地面带深灰导视带、两排方形柱带深灰柱础、吊顶分缝格栅加双排矩形灯槽、左墙是整面落地幕墙映着橙红落日、右墙有蓝色售货机、远端是前台与绿色导视牌。画面右下角伸出一只裸手握着一把纯黑手枪（手腕是深灰工装袖，不是白衬衫），枪管指向画面深处（第一人称持枪视角）。粗像素块、清晰硬边、无渐变、无抗锯齿、限定 24 色调色板、90 年代 DOS 游戏美术质感。不要文字、不要 UI、不要水印。
```
- 场景句替换：ch02「开放式办公楼层：木地板带铺装缝、成排工位与显示器、玻璃会议室、浅黄墙面、天花格栅灯」／ch03「商场中庭：冷蓝瓷砖地面、二层环廊带玻璃栏板、两侧橱窗灯箱、扶梯、挑高五米的吊顶筒灯」／ch04「天台停机坪：水泥地面带伸缩缝、成排倾斜太阳能板、空调机组、栏杆、地平线是三层错落的城市天际线与落日」

---

## 5. 通用规格

1. 背景纯洋红 `#FF00FF`（抠图脚本 `D:\mygame\tmp\AiPrep.py` 只认这个色相）。
2. 统一按 1920 出图，管线自己降采样；不要直接要 96x96。
3. 色板写数字（8/12/16/24），比写「复古调色板」可控。
4. 角色类脚底贴画布底边。
5. viewmodel 必须枪管指向画面深处 —— 看得到套筒顶面与枪口端面、高宽比约 2.2:1 才算对；侧面剖面无论怎么转都不对。
6. **手臂是本体原创，不带 BA 语言** —— BA 是默认关闭的拓展模块（PDF 第二章第五节），手臂不能是日式学生制服那套（白衬衫翻边 + 深藏青校服袖）。主角定位是灾变当晚被卷入的普通人，穿日常工装。

---

## 6. 生完之后

```powershell
py -3 D:\mygame\tmp\AiPrep.py <母图.png> D:\mygame\tmp\vm_src.png
py -3 D:\mygame\tmp\AiPixel.py pistol  D:\mygame\tmp\vm_src.png D:\mygame\assets\sprites\viewmodel
py -3 D:\mygame\tmp\AiPixel.py shotgun D:\mygame\tmp\vm_src.png D:\mygame\assets\sprites\viewmodel
py -3 D:\mygame\tmp\VmFrames3.py
& 'D:\DevTools\Godot\Godot_v4.7.2-stable_win64_console.exe' --path D:\mygame --headless --import
```

`D:\mygame\tmp\AiPixel.py` 的 `CROP` / `OUT` 按旧底板调的，新母图要重设窗口。新帧尺寸变了要同步改 `D:\mygame\scripts\ui\viewmodel.gd` 的 `PISTOL` / `SHOTGUN` 的 `size` / `pos` / `muzzle`（`pos.y = 270 - 贴图高`）。
