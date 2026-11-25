## 章节注册表：demo 的 4 章按顺序登记在这里。
## 挂载节点类型: 无（extends RefCounted，全部 static）
## 存在理由: 关卡推进、构建器、审核探针都要按顺序遍历 4 章。
##   若各写一份列表，加一章就要改三处且必然漏改。
## 注意: 这里只登记"脚本路径"，不 preload —— 章节脚本很重（每章几百条原语），
##   运行时只加载当前章，避免启动就把四章几何全建进内存。
extends RefCounted

const CHAPTER_SCRIPTS: Array[String] = [
	"res://scripts/level/chapter_01_lobby.gd",
	"res://scripts/level/chapter_02_office.gd",
	"res://scripts/level/chapter_03_atrium.gd",
	"res://scripts/level/chapter_04_rooftop.gd",
]

static func count() -> int:
	return CHAPTER_SCRIPTS.size()

## 取第 index 章的脚本路径。越界时钳到最后一章（终章），
## 而不是返回空 —— 空路径会让关卡加载出空场景，比"卡在终章"更难排查。
static func script_path(index: int) -> String:
	if CHAPTER_SCRIPTS.is_empty():
		return ""
	return CHAPTER_SCRIPTS[clampi(index, 0, CHAPTER_SCRIPTS.size() - 1)]

## 取第 index 章的 ChapterData。构建失败时返回 null，调用方需判空。
static func load_chapter(index: int) -> ChapterData:
	var path: String = script_path(index)
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("Chapters: 章节脚本缺失 %s" % path)
		return null
	var script: GDScript = load(path) as GDScript
	if script == null:
		push_error("Chapters: 无法加载 %s" % path)
		return null
	var data: Variant = script.call("build")
	return data as ChapterData
