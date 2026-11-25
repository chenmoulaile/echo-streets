## 新手教程文案表（纯数据，无节点、无副作用）。
## class_name: Tutorial
## 挂载节点类型: 无（RefCounted，只提供 static 查表）
## 为什么单独一个文件: hud.gd 的提示通道与 tutorial_flow.gd 的推进逻辑都要读文案，
##   写两处必然漂移。文案一律 ASCII —— Godot 内置字体不含 CJK 字形，中文会渲染成方块。
## 与操控方案联动: AIM / SHOVE 两条的按键随 GameSettings.scheme 变，写死会教错人。
class_name Tutorial
extends RefCounted

## 单条提示停留时长（秒）。低于 2 秒读不完一行英文；高于 5 秒会压住准星下沿。
const HOLD_TIME := 3.6
## 两条提示之间的空档。连续弹出会读成同一句话被刷新，看不出是两条。
const GAP := 1.2

enum Step {
	MOVE = 0,
	FIRE = 1,
	RELOAD = 2,
	AIM = 3,
	SHOVE = 4,
	SWAP = 5,
	SETTINGS = 6,
	ROUTE = 7,
}

const TEXTS := {
	Step.MOVE: "WASD MOVE   SHIFT SPRINT   CTRL CROUCH",
	Step.FIRE: "LEFT MOUSE FIRE   WHEEL SWAP WEAPON",
	Step.RELOAD: "R RELOAD   MAG EMPTY = AUTO CLICK",
	Step.SWAP: "1 / 2 SWAP   SHOTGUN HITS HARD UP CLOSE",
	Step.SETTINGS: "O SETTINGS   ESC PAUSE",
	Step.ROUTE: "FOLLOW THE LIT ROUTE - WAVES COME TO YOU",
}

## 按当前操控方案返回文案。未知 step 返回空串，HUD 侧据此跳过，不显示空框。
static func text_for(step: int) -> String:
	if step == Step.AIM:
		if GameSettings.scheme == GameSettings.SCHEME_CLASSIC:
			return "RIGHT MOUSE AIM DOWN SIGHT   (TIGHTER SPREAD)"
		return "MIDDLE MOUSE AIM DOWN SIGHT   (TIGHTER SPREAD)"
	if step == Step.SHOVE:
		if GameSettings.scheme == GameSettings.SCHEME_CLASSIC:
			return "V SHOVE - PUSH ZOMBIES BACK, NO AMMO USED"
		return "RIGHT MOUSE SHOVE - PUSH ZOMBIES BACK, NO AMMO USED"
	return String(TEXTS.get(step, ""))
