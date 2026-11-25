using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

// 从单帧 96x96 纸片丧尸合成多帧动画。
// 不重画美术：把原图按身体部位切片后逐帧重排，保住手绘像素风格。
public class ZombieAnim
{
    const int W = 96;
    const int H = 96;

    struct Part { public int X0, Y0, X1, Y1; public Part(int x0, int y0, int x1, int y1) { X0 = x0; Y0 = y0; X1 = x1; Y1 = y1; } }

    // 部位切分（含 1px 重叠，避免重排后出现缝）
    // 腿的枢轴在髋部 y=56，脚底到 y=95；腿左右以 x=49 分界（见 alpha 列剖面）
    static readonly Part LEG_L = new Part(35, 56, 49, 95);
    static readonly Part LEG_R = new Part(48, 56, 64, 95);
    static readonly Part TORSO = new Part(24, 25, 72, 58);
    static readonly Part ARM_L = new Part(10, 26, 36, 50);
    static readonly Part ARM_R = new Part(60, 26, 86, 50);
    static readonly Part HEAD  = new Part(26, 0, 70, 28);

    static int[] Load(string path)
    {
        using (var bmp = new Bitmap(path))
        {
            int w = bmp.Width, h = bmp.Height;
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

    static void Save(string path, int[] px)
    {
        using (var bmp = new Bitmap(W, H, PixelFormat.Format32bppArgb))
        {
            var data = bmp.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            var row = new int[W];
            for (int y = 0; y < H; y++)
            {
                Array.Copy(px, y * W, row, 0, W);
                Marshal.Copy(row, 0, IntPtr.Add(data.Scan0, y * data.Stride), W);
            }
            bmp.UnlockBits(data);
            bmp.Save(path, ImageFormat.Png);
        }
    }

    // 把 src 的一个部位按 (dx,dy) 贴到 dst 上；squash 把部位底部压扁（模拟屈膝/倒下）
    static void Blit(int[] dst, int[] src, Part p, int dx, int dy, float squash = 1.0f)
    {
        int hgt = p.Y1 - p.Y0 + 1;
        for (int sy = p.Y0; sy <= p.Y1; sy++)
        {
            int rel = sy - p.Y0;
            int ty = p.Y0 + dy + (int)Math.Round(rel * squash);
            if (ty < 0 || ty >= H) continue;
            for (int sx = p.X0; sx <= p.X1; sx++)
            {
                int tx = sx + dx;
                if (tx < 0 || tx >= W) continue;
                int c = src[sy * W + sx];
                if ((c >> 24 & 0xFF) < 40) continue;   // 透明不覆盖
                dst[ty * W + tx] = c;
            }
        }
    }

    // 绕顶端枢轴摆动的部位（腿/臂）：位移随离枢轴的距离线性增长，
    // 髋部不动、脚端摆幅最大。整体平移会在髋部撕出缺口，剪切才是正确的枢轴旋转近似。
    // lift>0 时从底部压缩（抬脚/屈膝），compress 是压缩比例。
    static void ShearBlit(int[] dst, int[] src, Part p, float swingPx, int lift, float compress)
    {
        int hgt = p.Y1 - p.Y0 + 1;
        if (hgt <= 0) return;
        for (int sy = p.Y0; sy <= p.Y1; sy++)
        {
            int rel = sy - p.Y0;
            float t = (float)rel / hgt;
            int ty = p.Y0 - lift + (int)Math.Round(rel * compress);
            if (ty < 0 || ty >= H) continue;
            int dx = (int)Math.Round(swingPx * t);
            for (int sx = p.X0; sx <= p.X1; sx++)
            {
                int tx = sx + dx;
                if (tx < 0 || tx >= W) continue;
                int c = src[sy * W + sx];
                if ((c >> 24 & 0xFF) < 40) continue;
                dst[ty * W + tx] = c;
            }
        }
    }

    // 绕脚底枢轴旋转整帧（死亡倒地）。angle 单位弧度，正值向画面右侧倒。
    static int[] RotatePivot(int[] src, double angle)
    {
        var dst = new int[W * H];
        double pivotX = 48.0, pivotY = 96.0;
        double cos = Math.Cos(angle), sin = Math.Sin(angle);
        for (int y = 0; y < H; y++)
        {
            for (int x = 0; x < W; x++)
            {
                double rx = x - pivotX, ry = y - pivotY;
                // 逆向映射：目标像素反算源坐标
                double sx = pivotX + rx * cos + ry * sin;
                double sy = pivotY - rx * sin + ry * cos;
                int ix = (int)Math.Round(sx), iy = (int)Math.Round(sy);
                if (ix < 0 || ix >= W || iy < 0 || iy >= H) continue;
                int c = src[iy * W + ix];
                if ((c >> 24 & 0xFF) < 40) continue;
                dst[y * W + x] = c;
            }
        }
        return dst;
    }

    // ── 行走：步态相位驱动（swing 摆动相 / stance 支撑相）────────────────
    // 纯正弦不行：sin 在对称相位上取值相等，第 1 帧与第 2 帧会长得一模一样。
    // 真实步行分两相 —— 摆动腿离地屈膝前摆，支撑腿伸直后拖，两相形态不同，
    // 所以每一帧都可区分。左腿相位 0，右腿相位 0.5。
    public static string Walk(string srcPath, string outDir, string prefix, int frames)
    {
        int[] src = Load(srcPath);
        var log = new System.Text.StringBuilder();
        for (int i = 0; i < frames; i++)
        {
            double cycle = (double)i / frames;
            var dst = new int[W * H];

            // 躯干起伏：每个步态周期上下两次（每次支撑腿过渡时最低）
            int bob = (int)Math.Round(-2.0 * Math.Cos(4.0 * Math.PI * cycle));

            // 左腿相位 = cycle，右腿相位 = cycle + 0.5
            for (int leg = 0; leg < 2; leg++)
            {
                double phase = (cycle + (leg == 0 ? 0.0 : 0.5)) % 1.0;
                Part p = leg == 0 ? LEG_L : LEG_R;
                float swing; int lift; float compress;
                if (phase < 0.5)
                {
                    // 摆动相：从后(-4)摆到前(+4)，中途抬得最高
                    double u = phase / 0.5;
                    swing = (float)(-4.0 + 8.0 * u);
                    lift = (int)Math.Round(4.0 * Math.Sin(u * Math.PI));
                    compress = 1.0f - lift * 0.015f;
                }
                else
                {
                    // 支撑相：脚着地，从前(+4)拖回后(-4)
                    double u = (phase - 0.5) / 0.5;
                    swing = (float)(4.0 - 8.0 * u);
                    lift = 0;
                    compress = 1.0f;
                }
                ShearBlit(dst, src, p, swing, lift, compress);
            }

            // 手臂与腿反相摆动（左手配右腿）
            double armPhase = (cycle + 0.5) % 1.0;
            float armSwing = (float)(-2.0 + 4.0 * armPhase);
            Blit(dst, src, TORSO, 0, bob);
            ShearBlit(dst, src, ARM_L, armSwing, 0, 1.0f);
            ShearBlit(dst, src, ARM_R, -armSwing, 0, 1.0f);
            Blit(dst, src, HEAD, 0, bob * 2);

            Save(Path.Combine(outDir, prefix + "_walk_" + i + ".png"), dst);
            log.Append(prefix).Append("_walk_").Append(i).Append(' ');
        }
        return log.ToString().Trim();
    }

    // ── 攻击：双臂前伸下抓 + 躯干前倾 ────────────────────────────────
    public static string Attack(string srcPath, string outDir, string prefix)
    {
        int[] src = Load(srcPath);
        var log = new System.Text.StringBuilder();
        int frames = 3;
        for (int i = 0; i < frames; i++)
        {
            var dst = new int[W * H];
            int reach = i == 1 ? 4 : (i == 2 ? 2 : 0);      // 第 1 帧最远
            int lean = i == 1 ? 2 : 0;
            Blit(dst, src, LEG_L, 0, 0);
            Blit(dst, src, LEG_R, 0, 0);
            Blit(dst, src, TORSO, 0, lean);
            Blit(dst, src, ARM_L, -reach, 2 + lean);
            Blit(dst, src, ARM_R, reach, 2 + lean);
            Blit(dst, src, HEAD, 0, lean * 2 + 1);
            Save(Path.Combine(outDir, prefix + "_attack_" + i + ".png"), dst);
            log.Append(prefix).Append("_attack_").Append(i).Append(' ');
        }
        return log.ToString().Trim();
    }

    // ── 受击：整体后仰 1 帧 + 抖动 ──────────────────────────────────
    public static string Hurt(string srcPath, string outDir, string prefix)
    {
        int[] src = Load(srcPath);
        var log = new System.Text.StringBuilder();
        for (int i = 0; i < 2; i++)
        {
            var dst = new int[W * H];
            int back = i == 0 ? -3 : -1;
            Blit(dst, src, LEG_L, 0, 0);
            Blit(dst, src, LEG_R, 0, 0);
            Blit(dst, src, TORSO, back, 1);
            Blit(dst, src, ARM_L, back - 2, 0);
            Blit(dst, src, ARM_R, back + 2, 0);
            Blit(dst, src, HEAD, back, 3);
            Save(Path.Combine(outDir, prefix + "_hurt_" + i + ".png"), dst);
            log.Append(prefix).Append("_hurt_").Append(i).Append(' ');
        }
        return log.ToString().Trim();
    }

    // ── 死亡：绕脚底逐渐倒地 ────────────────────────────────────────
    // 画布加宽到 128x96：躺下的身体横跨 ~96px，96 宽的画布会把头和脚裁掉。
    // pivot 放在 (64,96)（加宽后画布底部中点），保证整段倒地过程都在画面内。
    public static string Death(string srcPath, string outDir, string prefix)
    {
        int[] src = Load(srcPath);
        var log = new System.Text.StringBuilder();
        double[] angles = { 0.0, 0.40, 0.85, 1.25, 1.50 };
        for (int i = 0; i < angles.Length; i++)
        {
            var dst = RotatePivotWide(src, angles[i]);
            SaveWide(Path.Combine(outDir, prefix + "_death_" + i + ".png"), dst);
            log.Append(prefix).Append("_death_").Append(i).Append(' ');
        }
        return log.ToString().Trim();
    }

    const int DW = 128;

    static int[] RotatePivotWide(int[] src, double angle)
    {
        var dst = new int[DW * H];
        double pivotX = 64.0, pivotY = 96.0;
        double cos = Math.Cos(angle), sin = Math.Sin(angle);
        for (int y = 0; y < H; y++)
        {
            for (int x = 0; x < DW; x++)
            {
                double rx = x - pivotX, ry = y - pivotY;
                double sx = pivotX + rx * cos + ry * sin;
                double sy = pivotY - rx * sin + ry * cos;
                int ix = (int)Math.Round(sx), iy = (int)Math.Round(sy);
                if (ix < 0 || ix >= W || iy < 0 || iy >= H) continue;
                int c = src[iy * W + ix];
                if ((c >> 24 & 0xFF) < 40) continue;
                dst[y * DW + x] = c;
            }
        }
        return dst;
    }

    static void SaveWide(string path, int[] px)
    {
        using (var bmp = new Bitmap(DW, H, PixelFormat.Format32bppArgb))
        {
            var data = bmp.LockBits(new Rectangle(0, 0, DW, H), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            var row = new int[DW];
            for (int y = 0; y < H; y++)
            {
                Array.Copy(px, y * DW, row, 0, DW);
                Marshal.Copy(row, 0, IntPtr.Add(data.Scan0, y * data.Stride), DW);
            }
            bmp.UnlockBits(data);
            bmp.Save(path, ImageFormat.Png);
        }
    }

    public static string Build(string srcPath, string outDir)
    {
        Directory.CreateDirectory(outDir);
        string name = Path.GetFileNameWithoutExtension(srcPath);   // zombie_fodder
        var sb = new System.Text.StringBuilder();
        sb.AppendLine(Walk(srcPath, outDir, name, 6));
        sb.AppendLine(Attack(srcPath, outDir, name));
        sb.AppendLine(Hurt(srcPath, outDir, name));
        sb.AppendLine(Death(srcPath, outDir, name));
        return sb.ToString();
    }
}
