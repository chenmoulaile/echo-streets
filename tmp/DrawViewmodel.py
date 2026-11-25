# 程序化生成第一人称武器 viewmodel（手枪 / 短管泵动霰弹枪）+ 默认学生手臂。
#
# 为什么不复用参考项目的帧：那套是「星野（Hoshino）」的配枪与她的手套，本作主角是
# 默认学生形象。故从零构造：自研紧凑型手枪（青识别条 + 倒角套筒 + 后倾握把）、
# 短管泵动霰弹枪；手臂为「白衬衫袖口 → 深藏青外套袖 → 战术手套」。
#
# ── 两套坐标系（本文件的核心技巧）─────────────────────────────────────────
#   1) 「枪械局部系」画枪与手：+x 沿枪膛指向枪口，+y 竖直向上（套筒顶面）。
#      整幅绕握把轴心逆时针旋 PHI=96°，于是局部 +x → 屏幕左上（枪口朝上偏左）、
#      局部 +y → 屏幕左（套筒顶面朝左）、握把与手落在右下。
#   2) 「屏幕系」画前臂与袖口：前臂在第一人称里是被透视压缩的，用旋转后的
#      平面刚性形状画会读成一根扁棍（已验证）。所以前臂从手腕锚点按屏幕方向
#      向右下锥形放样，直接出画。两层在同一次超采样里合成，边缘一致。
#
#   为什么必须先画侧视再旋转：纯 2D 直接画「枪管朝上」时，握把、套筒、护圈会
#   在屏幕上互相重叠，读成一坨（两版实测全废）。侧视是唯一自洽的构造视角。
#
# 渲染：4 倍超采样多边形填充 → NEAREST 下采样（边缘不产生灰边）→ alpha 膨胀
#   1px 深色描边（白石大堂这类高亮场景里枪身不糊）。
#
#   py -3 tmp/DrawViewmodel.py            # 生成 20 帧到 assets/sprites/viewmodel/
#   py -3 tmp/DrawViewmodel.py --side     # 只出未旋转侧视图，校验局部画法
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

SS = 4
PHI = math.radians(96.0)
PIVX, PIVY = 12.0, -30.0      # 旋转轴心（握把中部，局部系）
CX, CY = 104.0, 124.0         # 轴心在画布上的落点（1x）；CY 留 20px 上边距，
                              # 否则霰弹枪 fire1（枪口上跳 6°）会顶到画布上沿被切掉
CW, CH = 240, 240             # 逻辑画布

OUT = r"D:\mygame\assets\sprites\viewmodel"

# 固定裁剪窗口 (x0, y0, w, h) 与输出尺寸，均为 1x 逻辑像素。
#
# 为什么窗口写死而不用「所有帧 bbox 的并集」：拔枪帧（整幅下移 38）会把并集往下
# 拽出一大片空白，且前臂长度会直接决定纹理尺寸 —— 20 帧尺寸不一致，HUD 里枪会
# 忽大忽小。写死窗口后 20 帧同尺寸，前臂总在窗口右下角出画（由窗口负责切边）。
#
# 输出尺寸 = 窗口 × 2/3：480x270 的逻辑屏上，枪身占屏高约 40~48%。窗口宽高都取
# 3 的倍数，2/3 缩放是整数，NEAREST 下采样不产生半像素灰边。
PISTOL_CROP, PISTOL_OUT = (36, 36, 186, 204), (124, 136)
SHOTGUN_CROP, SHOTGUN_OUT = (24, 12, 210, 228), (140, 152)

C = {
    "top":        (130, 140, 158, 255),
    "top_hi":     (186, 196, 212, 255),
    "side":       (82, 92, 110, 255),
    "side_dk":    (54, 62, 78, 255),
    "edge":       (34, 40, 52, 255),
    "frame":      (66, 74, 92, 255),
    "acc":        (86, 206, 220, 255),
    "acc_hi":     (178, 250, 254, 255),
    "acc_dk":     (30, 102, 116, 255),
    "shirt":      (226, 232, 242, 255),
    "shirt_hi":   (252, 253, 255, 255),
    "shirt_dk":   (166, 176, 198, 255),
    "blazer":     (42, 54, 80, 255),
    "blazer_hi":  (64, 82, 116, 255),
    "blazer_dk":  (24, 30, 46, 255),
    "glove":      (54, 66, 92, 255),
    "glove_hi":   (88, 104, 138, 255),
    "glove_dk":   (30, 38, 56, 255),
    "glove_edge": (17, 21, 33, 255),
    # 「默认学生」的手是裸手 —— 蔚蓝档案的常规学生配置是白衬衫 + 深色外套，
    # 不戴战术手套。手套色仍保留，霰弹枪前手护木上的防滑掌垫会用到。
    "skin":       (226, 186, 156, 255),
    "skin_hi":    (248, 214, 190, 255),
    "skin_dk":    (190, 148, 118, 255),
    "skin_edge":  (132, 92, 70, 255),
    "bore":       (10, 12, 18, 255),
    "brass":      (216, 174, 86, 255),
    "brass_hi":   (248, 216, 134, 255),
    "wood":       (110, 76, 54, 255),
    "wood_hi":    (148, 108, 76, 255),
    "wood_dk":    (72, 48, 32, 255),
    "outline":    (13, 17, 25, 255),
}


class Sheet:
    """超采样画布：local 系（会旋转）与 screen 系（不旋转）共用一张图。"""

    def __init__(self, phi=PHI, dy=0.0):
        self.img = Image.new("RGBA", (CW * SS, CH * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        self.c, self.s = math.cos(phi), math.sin(phi)
        self.dy = dy

    # —— 局部系 ——
    def p(self, x, y):
        lx, ly = x - PIVX, y - PIVY
        rx = lx * self.c - ly * self.s
        ry = lx * self.s + ly * self.c
        return ((CX + rx) * SS, (CY - ry + self.dy) * SS)

    def sp(self, x, y):
        """局部点 → 未乘 SS 的屏幕点（给 screen 系放样用）。"""
        px, py = self.p(x, y)
        return (px / SS, py / SS)

    def poly(self, pts, col):
        if col is not None:
            self.d.polygon([self.p(x, y) for x, y in pts], fill=col)

    def rect(self, x0, y0, x1, y1, col):
        if col is not None:
            self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], col)

    def rrect(self, x0, y0, x1, y1, col, r=2.0):
        if col is None:
            return
        self.poly([(x0 + r, y0), (x1 - r, y0), (x1, y0 + r), (x1, y1 - r),
                   (x1 - r, y1), (x0 + r, y1), (x0, y1 - r), (x0, y0 + r)], col)

    # —— 屏幕系（不旋转，只叠 dy）——
    def gpoly(self, pts, col):
        if col is None:
            return
        self.d.polygon([(x * SS, (y + self.dy) * SS) for x, y in pts], fill=col)

    def band(self, org, dirv, t0, t1, hw0, hw1, col):
        """沿 dirv 从 org 放样一段梯形（屏幕系）。"""
        if col is None:
            return
        dx, dy = dirv
        px, py = -dy, dx                      # 法向
        ax, ay = org[0] + dx * t0, org[1] + dy * t0
        bx, by = org[0] + dx * t1, org[1] + dy * t1
        self.gpoly([(ax + px * hw0, ay + py * hw0), (bx + px * hw1, by + py * hw1),
                    (bx - px * hw1, by - py * hw1), (ax - px * hw0, ay - py * hw0)], col)


# ── 前臂（屏幕系）：从手腕锚点锥形放样到画面右下角外 ────────────────────────

def forearm(sh: Sheet, wrist_local, dirv, hw_wrist, hw_end, reach=170.0):
    """前臂：屏幕系锥形放样。
    三条铁律（每条都踩过一次）：
      1) **方向必须朝屏幕下方**，不能沿用枪轴方向。枪轴旋转后指向左上，前臂若顺着
         枪轴往右下延，整幅会连成一条贯穿画面的斜带 —— 读成一块木板，不是一条手臂。
         真人持枪：枪口朝上、手腕在握把处折叠、前臂自画面下缘升起。
      2) 宽度控制在枪身厚度的 1.2~1.5 倍。hw 到 17 就已经比套筒（17）还宽，读成柱子。
      3) reach 必须让前臂末端越过裁剪窗口下缘 —— 由窗口切边。末端停在画面里会看到
         一条生硬的横切面。"""
    org = sh.sp(*wrist_local)
    d = math.hypot(*dirv)
    dirv = (dirv[0] / d, dirv[1] / d)
    px, py = -dirv[1], dirv[0]

    def pt(t, h):
        return (org[0] + dirv[0] * t + px * h, org[1] + dirv[1] * t + py * h)

    sh.gpoly([pt(12, hw_wrist + 2), pt(reach, hw_end), pt(reach, -hw_end),
              pt(12, -(hw_wrist + 2))], C["blazer"])
    sh.gpoly([pt(12, hw_wrist + 2), pt(12, 1.5), pt(reach, -2.0),
              pt(reach, hw_end * 0.34)], C["blazer_hi"])
    sh.gpoly([pt(12, -(hw_wrist - 0.5)), pt(12, -hw_wrist - 2), pt(reach, -hw_end),
              pt(reach, -(hw_end - 2.0))], C["blazer_dk"])
    # 白衬衫袖口：手套与外套之间露出的一小圈，窄（只 7 单位长）才像翻边
    sh.gpoly([pt(2, hw_wrist + 0.5), pt(9, hw_wrist + 2.5),
              pt(9, -hw_wrist - 2.5), pt(2, -hw_wrist - 0.5)], C["shirt"])
    sh.gpoly([pt(2, hw_wrist + 0.5), pt(8, hw_wrist + 2.5),
              pt(8, 1.2), pt(2, 0.6)], C["shirt_hi"])
    sh.gpoly([pt(8, hw_wrist + 2.0), pt(10, hw_wrist + 3.4),
              pt(10, -hw_wrist - 3.4), pt(8, -hw_wrist - 2.0)], C["shirt_dk"])


# ── 手枪（局部系：膛线 y 0..17，膛口 x=96）────────────────────────────────

def pistol(sh: Sheet, slide_back=0.0, mag_drop=0.0, brass=False):
    b = slide_back
    # 套筒
    sh.rect(22 - b, 0, 96 - b, 17, C["side"])
    sh.rect(22 - b, 12.5, 96 - b, 17, C["top"])
    sh.rect(22 - b, 15.6, 96 - b, 17, C["top_hi"])
    sh.rect(22 - b, 0, 96 - b, 2.0, C["edge"])
    sh.rect(92 - b, 5, 96 - b, 17, C["side_dk"])
    sh.rect(93.4 - b, 5.6, 96 - b, 14.6, C["bore"])
    sh.rect(56 - b, 8.4, 76 - b, 15.2, C["edge"])
    sh.rect(56 - b, 8.4, 76 - b, 9.8, C["side_dk"])
    for i in range(8):                                   # 防滑纹
        x = 26 + i * 2.6 - b
        sh.rect(x, 3.0, x + 1.1, 14.2, C["edge"])
    sh.rect(22 - b, 4.6, 29 - b, 10.4, C["acc"])         # 青色识别条
    sh.rect(22 - b, 8.0, 29 - b, 10.4, C["acc_hi"])
    sh.rect(92 - b, 17, 95.6 - b, 22.4, C["top"])        # 准星
    sh.rect(92 - b, 20.8, 95.6 - b, 22.4, C["top_hi"])
    sh.rect(26 - b, 17, 29.6 - b, 22.4, C["top"])        # 照门
    sh.rect(38 - b, 17, 41.6 - b, 22.4, C["top"])
    # 机匣 / 导轨
    sh.rrect(22, -9, 36, 0, C["frame"], 2.0)
    sh.rect(22, -2.0, 36, 0, C["edge"])
    sh.rect(48, -6, 86, 0, C["side_dk"])
    sh.rect(51, -6, 55, 0, C["bore"])
    sh.rect(63, -6, 67, 0, C["bore"])
    # 扳机护圈（在握把之前）+ 扳机
    sh.rrect(30, -30, 58, -4, C["frame"], 7.0)
    sh.rrect(36, -24, 52, -8.5, (0, 0, 0, 0), 5.0)
    sh.rect(39, -24, 42.6, -8.5, C["edge"])
    # 握把（自机匣后部向 -x/-y 后倾）
    sh.poly([(22, -8), (44, -8), (30, -54), (6, -54)], C["side_dk"])
    sh.poly([(38, -8), (44, -8), (30, -54), (24, -54)], C["edge"])
    for gy in range(-50, -12, 4):
        sh.rect(8 + (gy + 54) * 0.42, gy, 26 + (gy + 54) * 0.42, gy + 1.4, C["edge"])
    sh.rrect(2, -58, 32, -53, C["edge"], 2.0)            # 弹匣底板
    sh.rect(6, -58, 28, -56.4, C["acc_dk"])
    if mag_drop > 2.0:                                   # 换弹：弹匣脱落
        y0 = -60 - mag_drop
        sh.poly([(8, y0 - 30), (30, y0 - 30), (34, y0), (12, y0)], C["side"])
        sh.poly([(8, y0 - 30), (17, y0 - 30), (19, y0), (12, y0)], C["top"])
        sh.rect(10, y0 - 26, 30, y0 - 23.4, C["edge"])
        sh.rect(11, y0 - 12, 31, y0 - 9.4, C["edge"])
        sh.rect(9, y0 - 33, 31, y0 - 30, C["brass"])
    if brass:                                            # 抛壳
        sh.poly([(70, 20), (79, 28), (70, 36), (61, 28)], C["brass"])
        sh.rect(66, 25, 74, 27.6, C["brass_hi"])

    # 手（局部系）—— 裸手握枪：手背盖住握把后侧，四指贴着「前握把面」弯曲。
    # 握把前缘是直线 (44,-8)→(30,-54)，斜率 0.3043；手指锚在这条线上，只露 5 单位
    # 指背 —— 正拳握持时手指大部分被握把本身挡住（画成整根手指会读成香肠）。
    sh.rrect(0, -50, 30, -6, C["skin"], 6.0)             # 手背
    sh.rrect(0, -50, 13, -6, C["skin_hi"], 6.0)
    sh.rect(0, -12, 30, -6, C["skin_dk"])
    for y0 in (-44.0, -34.0, -24.0, -14.0):
        xf = 44.0 + (y0 + 8.0) * 0.3043
        sh.rrect(xf - 12.0, y0, xf + 4.6, y0 + 8.4, C["skin"], 3.6)
        sh.rrect(xf - 12.0, y0, xf - 3.0, y0 + 3.2, C["skin_hi"], 2.8)
        sh.rect(xf - 12.0, y0 + 6.6, xf + 4.6, y0 + 8.4, C["skin_edge"])
    sh.rrect(16, -20, 40, -8, C["skin_dk"], 5.0)         # 拇指压机匣
    sh.rrect(22, -19, 40, -11, C["skin"], 4.5)
    # 前臂朝画面下方近垂直出画：真人持枪时前臂与枪轴夹角远大于 90°，
    # 顺着枪轴或 45° 斜下延都会连成一条贯穿画面的斜带（读成木板）。近垂直
    # 才能读成「手腕在握把处折叠、小臂从画面下缘升起」。
    forearm(sh, (14.0, -48.0), (0.30, 0.95), 10.0, 12.5, reach=150.0)


# ── 霰弹枪（局部系：枪管 y 16..28，膛口 x=112）─────────────────────────────

def shotgun(sh: Sheet, pump=0.0, brass=False):
    p = pump
    sh.rect(0, 16, 112, 28, C["side"])                   # 枪管
    sh.rect(0, 24.4, 112, 28, C["top"])
    sh.rect(0, 26.4, 112, 28, C["top_hi"])
    sh.rect(106, 16, 112, 28, C["side_dk"])
    sh.rect(108.4, 17.6, 112, 26.4, C["bore"])
    sh.rect(0, 6, 100, 14, C["side"])                    # 弹仓管
    sh.rect(0, 11.6, 100, 14, C["top"])
    sh.rect(99, 6, 100, 14, C["edge"])
    sh.rrect(44 + p, 2, 96 + p, 16, C["wood"], 2.6)      # 泵柄护木
    sh.rect(44 + p, 12.4, 96 + p, 16, C["wood_hi"])
    sh.rect(44 + p, 2, 96 + p, 3.6, C["wood_dk"])
    for i in range(7):
        x = 48 + i * 6.8 + p
        sh.rect(x, 4.4, x + 2.2, 11.6, C["wood_dk"])
        sh.rect(x + 2.2, 4.4, x + 3.0, 11.6, C["wood_hi"])
    sh.rrect(0, -8, 44, 30, C["frame"], 2.4)             # 机匣
    sh.rect(0, 26, 44, 30, C["top"])
    sh.rect(0, 28.4, 44, 30, C["top_hi"])
    sh.rect(30, 22, 44, 30, C["side_dk"])
    sh.rect(14, 23, 28, 30, C["bore"])
    sh.rect(0, 9, 6, 23, C["acc"])
    sh.rect(0, 18.4, 6, 23, C["acc_hi"])
    sh.rrect(-18, -4, 3, 26, C["frame"], 6.0)            # 护圈 + 扳机
    sh.rrect(-13.5, 1.5, -2, 20.5, (0, 0, 0, 0), 4.5)
    sh.rect(-9, 1.5, -5.5, 15, C["edge"])
    sh.poly([(0, -8), (12, -8), (-2, -58), (-24, -58)], C["wood"])   # 枪托
    sh.poly([(0, -8), (5, -8), (-8, -58), (-24, -58)], C["wood_hi"])
    sh.poly([(8, -8), (12, -8), (-2, -58), (-10, -58)], C["wood_dk"])
    sh.rect(-26, -62, 0, -57, C["wood_dk"])              # 托底板
    if brass:
        sh.poly([(26, 30), (35, 38), (26, 46), (17, 38)], C["brass"])
        sh.rect(22, 35, 30, 37.6, C["brass_hi"])

    # 后手（握把）+ 主前臂（先画，前手压在上面）
    sh.rrect(-14, -58, 16, -50, C["skin_dk"], 4.0)       # 掌根
    sh.rrect(-18, -54, 14, -8, C["skin"], 6.0)           # 手背
    sh.rrect(-18, -54, -4, -8, C["skin_hi"], 6.0)
    for y0 in (-46.0, -36.0, -26.0, -16.0):
        sh.rrect(6.0, y0, 24.0, y0 + 8.4, C["skin"], 3.6)
        sh.rrect(6.0, y0, 15.0, y0 + 3.2, C["skin_hi"], 2.8)
        sh.rect(6.0, y0 + 6.6, 24.0, y0 + 8.4, C["skin_edge"])
    sh.rrect(-8, -20, 18, -8, C["skin_dk"], 5.0)         # 拇指
    sh.rrect(-2, -19, 18, -11, C["skin"], 4.5)
    forearm(sh, (-14.0, -50.0), (0.30, 0.95), 10.0, 12.5, reach=150.0)

    # 前手托护木：护木被整只手包住，只画露出的手背与两道指缝。
    # 不要在这里画「露出的指节」——护木上沿紧贴枪管，指节画上去会变成贴
    # 在枪管上的四颗肉色胶囊（实测读成枪管上粘了香肠）。
    sh.rrect(48 + p, -8, 92 + p, 16, C["glove"], 4.8)
    sh.rrect(48 + p, 2, 92 + p, 16, C["glove_hi"], 4.2)
    sh.rect(48 + p, -8, 92 + p, -3.4, C["glove_edge"])
    for i in range(3):
        x = 54 + i * 11 + p
        sh.rect(x, -8, x + 2.2, 9, C["glove_edge"])
    forearm(sh, (70.0 + p, 2.0), (-0.12, 0.99), 9.0, 11.0, reach=120.0)


# ── 帧装配 ──────────────────────────────────────────────────────────────

def outlined(img):
    """alpha 膨胀一圈垫在下方当 1px 深色描边（4x 下 MaxFilter(9)=4px=1px@1x）。"""
    a = img.getchannel("A").point(lambda v: 255 if v > 24 else 0)
    edge = Image.new("RGBA", img.size, (0, 0, 0, 0))
    edge.paste(Image.new("RGBA", img.size, C["outline"]), (0, 0), a.filter(ImageFilter.MaxFilter(9)))
    return Image.alpha_composite(edge, img)


def emit(frames, prefix, muzzle_local, crop, out_size):
    """crop = (x0, y0, w, h)：固定裁剪窗口。
    不用所有帧的 bbox 并集 —— 那样拔枪帧（整幅下移）会把窗口往下拽出一大片空白，
    且前臂长度会直接决定纹理尺寸。固定窗口让 20 帧尺寸一致、前臂总在窗口右缘出画。"""
    keys = sorted(frames)
    x0, y0, w, h = crop
    ow, oh = out_size
    mx, my = frames[prefix + "_idle"].p(*muzzle_local)
    mx, my = (mx - x0 * SS) / SS * ow / w, (my - y0 * SS) / SS * oh / h
    print("[%s] %dx%d  muzzle=(%.1f, %.1f)" % (prefix, ow, oh, mx, my))
    for k in keys:
        im = outlined(frames[k].img)
        out = im.crop((x0 * SS, y0 * SS, (x0 + w) * SS, (y0 + h) * SS))
        out = out.resize((ow, oh), Image.NEAREST)
        path = os.path.join(OUT, k + ".png")
        out.save(path)
        print("  %-24s %5dB" % (k + ".png", os.path.getsize(path)))


def sheet(dy=0.0, flip=0.0):
    """flip>0 = 枪口上跳：整幅再偏一点并把画布下移，配合后坐位移。"""
    return Sheet(phi=PHI - math.radians(flip), dy=-flip * 1.2)


def build_pistol():
    f = {}
    sh = sheet()
    pistol(sh)
    f["vm_pistol_idle"] = sh
    sh = sheet()
    pistol(sh, slide_back=15.0)                      # 空仓：套筒停在后位
    f["vm_pistol_dry"] = sh
    for i, (back, flip) in enumerate([(15.0, 5.0), (7.0, 2.2), (0.0, 0.0)]):
        sh = sheet(flip=flip)
        pistol(sh, slide_back=back, brass=(i == 0))
        f["vm_pistol_fire%d" % (i + 1)] = sh
    for i, (drop, back) in enumerate([(16.0, 15.0), (0.0, 15.0),
                                      (0.0, 15.0), (0.0, 0.0)]):
        sh = sheet()
        pistol(sh, slide_back=back, mag_drop=drop)
        f["vm_pistol_reload%d" % (i + 1)] = sh
    sh = sheet(dy=38.0)                              # 拔枪：整帧自下方升起
    pistol(sh)
    f["vm_pistol_draw"] = sh
    return f


def build_shotgun():
    f = {}
    sh = sheet()
    shotgun(sh)
    f["vm_shotgun_idle"] = sh
    for i, flip in enumerate([6.0, 4.6, 3.0, 1.4, 0.0]):
        sh = sheet(flip=flip)
        shotgun(sh, brass=(i == 0))
        f["vm_shotgun_fire%d" % (i + 1)] = sh
    for i, (p, flip) in enumerate([(-18.0, 2.4), (0.0, 0.0)]):
        sh = sheet(flip=flip)
        shotgun(sh, pump=p)
        f["vm_shotgun_reload%d" % (i + 1)] = sh
    sh = sheet(dy=38.0)
    shotgun(sh)
    f["vm_shotgun_draw"] = sh
    sh = sheet()
    shotgun(sh)
    f["vm_shotgun_altfire"] = sh
    return f


def side_only():
    for name, fn in (("pistol_side", pistol), ("shotgun_side", shotgun)):
        sh = Sheet(phi=0.0)
        fn(sh)
        img = outlined(sh.img)
        bb = img.getchannel("A").getbbox()
        img.crop(bb).resize(((bb[2] - bb[0]) // SS, (bb[3] - bb[1]) // SS),
                            Image.NEAREST).save(os.path.join(r"D:\mygame\tmp", name + ".png"))
        print("[%s] saved" % name)


def probe():
    """打印每帧 alpha 包围盒（1x 坐标），用来定 crop 窗口。"""
    for prefix, frames in (("vm_pistol", build_pistol()), ("vm_shotgun", build_shotgun())):
        for k in sorted(frames):
            bb = outlined(frames[k].img).getchannel("A").getbbox()
            print("[%s] %-18s bbox x %5.1f..%5.1f  y %5.1f..%5.1f" % (
                prefix, k, bb[0] / SS, bb[2] / SS, bb[1] / SS, bb[3] / SS))


def main():
    if "--side" in sys.argv:
        side_only()
        return
    if "--probe" in sys.argv:
        probe()
        return
    emit(build_pistol(), "vm_pistol", (96.0, 11.0), PISTOL_CROP, PISTOL_OUT)
    emit(build_shotgun(), "vm_shotgun", (112.0, 24.0), SHOTGUN_CROP, SHOTGUN_OUT)


if __name__ == "__main__":
    main()
