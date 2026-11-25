# 20261124 · topics

- **项目**：echo-streets（像素丧尸 FPS，Godot 4.7.2 Compatibility）
- **阶段**：Phase 2 四章 demo 闭环 + Windows 桌面端已导出（`build\echo-streets.exe`）
- **活跃任务**：无（四章 + 材质像素化 + viewmodel 均验收通过）
- **上次会话**：2026-11-25
- **主线目标**：按 PDF 开发像素丧尸 FPS；Phase 2 = 四章 demo（4 章 × 5 波 + 章节推进），画风统一为**伪 3D 像素风格**
- **本日产出**：
  - 四章建成并接入主场景（ECHO LOBBY / OFFICE FLOOR / MALL ATRIUM / ROOFTOP DECK）
  - 27 张场景材质像素化（`tmp/MatPixel.py --scale 3 --colors 12`）
  - 后处理 `palette_levels 24 → 12` + `dither_strength 0.18` + lift 增量补偿
  - viewmodel 12 轮迭代定稿（参考帧几何 + 只换材质配色）
  - 桌面端导出 + `--write-movie` 取证链路打通
- **下一步候选**：
  - 特感专属技能（自爆 AoE / 尖啸召唤 / 冲锋突进）
  - 血特效着色器接线
  - 肉鸽词条系统
  - 音频层（`assets/audio` 未建）
  - 人工手感校准（移速 / 后坐 / kick）
