using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

// 把单帧纸片丧尸合成 5 行 x 6 列 的动画图集（每格 128x96）。
// 用图集而不是逐帧换贴图：Sprite3D 的 hframes/vframes 让 UV 直接落在格子里，
// 着色器的 albedo_texture 只绑一次，逐帧零重绑。
// 行约定（与 zombie_sprite.gd 的 ROW_* 常量一一对应）：
//   0 idle(4) 1 walk(6) 2 attack(3) 3 hurt(2) 4 death(5)
public class ZombieAtlas
{
    public const int CW = 128;      // 单格宽（死亡帧横躺需要 128）
    public const int CH = 96;       // 单格高
    public const int COLS = 6;
    public const int ROWS = 5;

    struct Part { public int X0, Y0, X1, Y1; public Part(int x0, int y0, int x1, int y1) { X0 = x0; Y0 = y0; X1 = x1; Y1 = y1; } }

    // 部位切分：坐标基于 96x96 源图（alpha 列剖面实测）
    static readonly Part LEG_L = new Part(35, 56, 49, 95);
    static readonly Part LEG_R = new Part(48, 56, 64, 95);
    static readonly Part TORSO = new Part(24, 25, 72, 58);
    static readonly Part ARM_L = new Part(10, 26, 36, 50);
    static readonly Part ARM_R = new Part(60, 26, 86, 50);
    static readonly Part HEAD  = new Part(26, 0, 70, 28);

    const int SRC = 96;             // 源图画布边长
    const int PAD = (CW - SRC) / 2; // 源图在格内的水平居中偏移 = 16

    static int[] Load(string path, out int w, out int h)
    {
        using (var bmp = new Bitmap(path))
        {
            w = bmp.Width; h = bmp.Height;
            var px = new int[w * h];
            var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            var row = new int[w];
            for (int y = 0; y < h; y++)
            {
                Marshal.Copy(IntPtr.Add(data.Scan0, y * data.Stride), row, 0, w);
                Array.Copy(row, 0, px, y * w, w);
            }
            bmp.UnlockBits(data);
            return px;
        }
    }

    // 在 CW x CH 的格子里画一个部位。dx/dy 相对源图坐标。
    static void Blit(int[] cell, int[] src, Part p, int dx, int dy, float squash = 1.0f)
    {
        int hgt = p.Y1 - p.Y0 + 1;
        for (int sy = p.Y0; sy <= p.Y1; sy++)
        {
            int rel = sy - p.Y0;
            int ty = p.Y0 + dy + (int)Math.Round(rel * squash);
            if (ty < 0 || ty >= CH) continue;
            for (int sx = p.X0; sx <= p.X1; sx++)
            {
                int tx = sx + dx + PAD;
                if (tx < 0 || tx >= CW) continue;
                int c = src[sy * SRC + sx];
                if ((c >> 24 & 0xFF) < 40) continue;
                cell[ty * CW + tx] = c;
            }
        }
    }

    // 绕顶端枢轴摆动（腿/臂）：位移随离枢轴距离线性增长，髋部不动、末端摆幅最大。
    static void ShearBlit(int[] cell, int[] src, Part p, float swingPx, int lift, float compress)
    {
        int hgt = p.Y1 - p.Y0 + 1;
        if (hgt <= 0) return;
        for (int sy = p.Y0; sy <= p.Y1; sy++)
        {
            int rel = sy - p.Y0;
            float t = (float)rel / hgt;
            int ty = p.Y0 - lift + (int)Math.Round(rel * compress);
            if (ty < 0 || ty >= CH) continue;
            int dx = (int)Math.Round(swingPx * t);
            for (int sx = p.X0; sx <= p.X1; sx++)
            {
                int tx = sx + dx + PAD;
                if (tx < 0 || tx >= CW) continue;
                int c = src[sy * SRC + sx];
                if ((c >> 24 & 0xFF) < 40) continue;
                cell[ty * CW + tx] = c;
            }
        }
    }

    // 死亡：绕脚底 (64,96) 旋转整帧，格内坐标已是 128 宽，无需 PAD
    static int[] RotateCell(int[] src, double angle)
    {
        var cell = new int[CW * CH];
        double pivotX = 64.0, pivotY = 96.0;
        double cos = Math.Cos(angle), sin = Math.Sin(angle);
        for (int y = 0; y < CH; y++)
        {
            for (int x = 0; x < CW; x++)
            {
                double rx = x - pivotX, ry = y - pivotY;
                double sx = pivotX + rx * cos + ry * sin - PAD;
                double sy = pivotY - rx * sin + ry * cos;
                int ix = (int)Math.Round(sx), iy = (int)Math.Round(sy);
                if (ix < 0 || ix >= SRC || iy < 0 || iy >= SRC) continue;
                int c = src[iy * SRC + ix];
                if ((c >> 24 & 0xFF) < 40) continue;
                cell[y * CW + x] = c;
            }
        }
        return cell;
    }

    // ── 各状态单帧生成 ─────────────────────────────────────────────
    static int[] IdleFrame(int[] src, double phase)
    {
        var cell = new int[CW * CH];
        int bob = (int)Math.Round(1.0 * Math.Sin(phase * Math.PI * 2.0));
        Blit(cell, src, LEG_L, 0, 0);
        Blit(cell, src, LEG_R, 0, 0);
        Blit(cell, src, TORSO, 0, bob);
        Blit(cell, src, ARM_L, 0, bob + 1);
        Blit(cell, src, ARM_R, 0, bob + 1);
        Blit(cell, src, HEAD, 0, bob * 2);
        return cell;
    }

    // 步态两相：摆动腿离地屈膝前摆，支撑腿伸直后拖。纯正弦在对称相位上取值
    // 相等会让相邻帧长得一样，必须用两相区分去程与回程。
    static int[] WalkFrame(int[] src, int index, int frames)
    {
        var cell = new int[CW * CH];
        double cycle = (double)index / frames;
        int bob = (int)Math.Round(-2.0 * Math.Cos(4.0 * Math.PI * cycle));

        for (int leg = 0; leg < 2; leg++)
        {
            double phase = (cycle + (leg == 0 ? 0.0 : 0.5)) % 1.0;
            Part p = leg == 0 ? LEG_L : LEG_R;
            float swing; int lift; float compress;
            if (phase < 0.5)
            {
                double u = phase / 0.5;
                swing = (float)(-6.0 + 12.0 * u);
                lift = (int)Math.Round(5.0 * Math.Sin(u * Math.PI));
                compress = 1.0f - lift * 0.016f;
            }
            else
            {
                double u = (phase - 0.5) / 0.5;
                swing = (float)(6.0 - 12.0 * u);
                lift = 0;
                compress = 1.0f;
            }
            ShearBlit(cell, src, p, swing, lift, compress);
        }

        double armPhase = (cycle + 0.5) % 1.0;
        float armSwing = (float)(-3.0 + 6.0 * armPhase);
        Blit(cell, src, TORSO, 0, bob);
        ShearBlit(cell, src, ARM_L, armSwing, 0, 1.0f);
        ShearBlit(cell, src, ARM_R, -armSwing, 0, 1.0f);
        Blit(cell, src, HEAD, 0, bob * 2);
        return cell;
    }

    static int[] AttackFrame(int[] src, int index)
    {
        var cell = new int[CW * CH];
        int reach = index == 1 ? 6 : (index == 2 ? 3 : 0);
        int lean = index == 1 ? 3 : 0;
        Blit(cell, src, LEG_L, 0, 0);
        Blit(cell, src, LEG_R, 0, 0);
        Blit(cell, src, TORSO, 0, lean);
        Blit(cell, src, ARM_L, -reach, 2 + lean);
        Blit(cell, src, ARM_R, reach, 2 + lean);
        Blit(cell, src, HEAD, 0, lean * 2 + 1);
        return cell;
    }

    static int[] HurtFrame(int[] src, int index)
    {
        var cell = new int[CW * CH];
        int back = index == 0 ? -4 : -1;
        Blit(cell, src, LEG_L, 0, 0);
        Blit(cell, src, LEG_R, 0, 0);
        Blit(cell, src, TORSO, back, 1);
        Blit(cell, src, ARM_L, back - 3, 0);
        Blit(cell, src, ARM_R, back + 3, 0);
        Blit(cell, src, HEAD, back, 3);
        return cell;
    }

    static readonly double[] DEATH_ANGLES = { 0.0, 0.40, 0.85, 1.25, 1.50 };

    public static string Build(string srcPath, string outPath)
    {
        int w, h;
        int[] src = Load(srcPath, out w, out h);
        if (w != SRC || h != SRC)
            return "SKIP " + Path.GetFileName(srcPath) + " (canvas " + w + "x" + h + ", expected 96x96)";

        int aw = CW * COLS, ah = CH * ROWS;
        var atlas = new int[aw * ah];

        Action<int[], int, int> place = (cell, row, col) =>
        {
            for (int y = 0; y < CH; y++)
                for (int x = 0; x < CW; x++)
                {
                    int c = cell[y * CW + x];
                    if ((c >> 24 & 0xFF) == 0) continue;
                    atlas[(row * CH + y) * aw + col * CW + x] = c;
                }
        };

        for (int i = 0; i < 4; i++) place(IdleFrame(src, (double)i / 4.0), 0, i);
        for (int i = 0; i < 6; i++) place(WalkFrame(src, i, 6), 1, i);
        for (int i = 0; i < 3; i++) place(AttackFrame(src, i), 2, i);
        for (int i = 0; i < 2; i++) place(HurtFrame(src, i), 3, i);
        for (int i = 0; i < DEATH_ANGLES.Length; i++) place(RotateCell(src, DEATH_ANGLES[i]), 4, i);

        Directory.CreateDirectory(Path.GetDirectoryName(outPath));
        using (var bmp = new Bitmap(aw, ah, PixelFormat.Format32bppArgb))
        {
            var data = bmp.LockBits(new Rectangle(0, 0, aw, ah), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            var row = new int[aw];
            for (int y = 0; y < ah; y++)
            {
                Array.Copy(atlas, y * aw, row, 0, aw);
                Marshal.Copy(row, 0, IntPtr.Add(data.Scan0, y * data.Stride), aw);
            }
            bmp.UnlockBits(data);
            bmp.Save(outPath, ImageFormat.Png);
        }
        return "OK " + Path.GetFileName(outPath) + " " + aw + "x" + ah + " (" + COLS + "x" + ROWS + " cells of " + CW + "x" + CH + ")";
    }

    // 批量：把 assets/sprites 下所有 96x96 丧尸图各出一张图集
    public static string BuildAll(string spriteDir, string outDir)
    {
        Directory.CreateDirectory(outDir);
        var sb = new System.Text.StringBuilder();
        foreach (string f in Directory.GetFiles(spriteDir, "zombie_*.png"))
        {
            string name = Path.GetFileNameWithoutExtension(f);
            if (name.EndsWith("_atlas")) continue;
            string outPath = Path.Combine(outDir, name + "_atlas.png");
            string r = Build(f, outPath);
            sb.AppendLine(r);
        }
        return sb.ToString().Trim();
    }

    // ── 逐帧导出（引擎实际使用的方式）────────────────────────────────
    // 不用图集：Sprite3D 开 hframes/vframes 后 region 与自定义着色器的 UV 语义冲突，
    // 着色器头注释已明确「图集里切帧会把帧横向拉伸」。逐帧独立贴图让 UV 恒为 0..1，
    // 每帧只需重绑一次 albedo_texture，零区域换算、零猜测。
    public static string BuildFrames(string srcPath, string outDir, string prefix)
    {
        int w, h;
        int[] src = Load(srcPath, out w, out h);
        if (w != SRC || h != SRC)
            return "SKIP " + Path.GetFileName(srcPath) + " (canvas " + w + "x" + h + ", expected 96x96)";

        Directory.CreateDirectory(outDir);
        var sb = new System.Text.StringBuilder();
        int n = 0;

        for (int i = 0; i < 4; i++) { SaveCell(Path.Combine(outDir, prefix + "_idle_" + i + ".png"), IdleFrame(src, (double)i / 4.0)); n++; }
        for (int i = 0; i < 6; i++) { SaveCell(Path.Combine(outDir, prefix + "_walk_" + i + ".png"), WalkFrame(src, i, 6)); n++; }
        for (int i = 0; i < 3; i++) { SaveCell(Path.Combine(outDir, prefix + "_attack_" + i + ".png"), AttackFrame(src, i)); n++; }
        for (int i = 0; i < 2; i++) { SaveCell(Path.Combine(outDir, prefix + "_hurt_" + i + ".png"), HurtFrame(src, i)); n++; }
        for (int i = 0; i < DEATH_ANGLES.Length; i++) { SaveCell(Path.Combine(outDir, prefix + "_death_" + i + ".png"), RotateCell(src, DEATH_ANGLES[i])); n++; }

        return "OK " + prefix + " " + n + " frames -> " + Path.GetFileName(outDir);
    }

    static void SaveCell(string path, int[] cell)
    {
        using (var bmp = new Bitmap(CW, CH, PixelFormat.Format32bppArgb))
        {
            var data = bmp.LockBits(new Rectangle(0, 0, CW, CH), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            var row = new int[CW];
            for (int y = 0; y < CH; y++)
            {
                Array.Copy(cell, y * CW, row, 0, CW);
                Marshal.Copy(row, 0, IntPtr.Add(data.Scan0, y * data.Stride), CW);
            }
            bmp.UnlockBits(data);
            bmp.Save(path, ImageFormat.Png);
        }
    }

    public static string BuildFramesAll(string spriteDir, string outDir)
    {
        Directory.CreateDirectory(outDir);
        var sb = new System.Text.StringBuilder();
        foreach (string f in Directory.GetFiles(spriteDir, "zombie_*.png"))
        {
            string name = Path.GetFileNameWithoutExtension(f);
            if (name.EndsWith("_atlas")) continue;
            sb.AppendLine(BuildFrames(f, outDir, name));
        }
        return sb.ToString().Trim();
    }
}
