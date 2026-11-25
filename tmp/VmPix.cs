using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

/// 把高分辨率 FPS viewmodel 插画降采样成像素图。
/// 所有帧使用同一个固定裁剪窗口，保证开火帧的火光不会把枪身挤到别的位置。
public class VmPix
{
    public struct Win
    {
        public int X, Y, W, H;
        public Win(int x, int y, int w, int h) { X = x; Y = y; W = w; H = h; }
    }

    static int[] _palette;

    /// src -> dst，按 win 裁剪后 step 倍面积平均降采样，再用全局调色板量化。
    public static string Convert(string src, string dst, Win win, int step, int k, bool buildPalette)
    {
        using (var bmp = new Bitmap(src))
        {
            int w = bmp.Width, h = bmp.Height;
            var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            byte[] buf = new byte[Math.Abs(data.Stride) * h];
            int stride = Math.Abs(data.Stride);
            try { Marshal.Copy(data.Scan0, buf, 0, buf.Length); }
            finally { bmp.UnlockBits(data); }

            int ow = win.W / step;
            int oh = win.H / step;
            var outPix = new int[ow * oh];
            var outA = new byte[ow * oh];

            // 面积平均：只累加不透明的源像素，避免透明边缘把颜色拉向黑
            var samples = new List<int>();
            for (int oy = 0; oy < oh; oy++)
            {
                for (int ox = 0; ox < ow; ox++)
                {
                    long sr = 0, sg = 0, sb = 0, cnt = 0;
                    int opaque = 0;
                    for (int sy = 0; sy < step; sy++)
                    {
                        int py = win.Y + oy * step + sy;
                        if (py < 0 || py >= h) continue;
                        int row = py * stride;
                        for (int sx = 0; sx < step; sx++)
                        {
                            int px = win.X + ox * step + sx;
                            if (px < 0 || px >= w) continue;
                            int i = row + px * 4;
                            if (buf[i + 3] > 96)
                            {
                                sb += buf[i];
                                sg += buf[i + 1];
                                sr += buf[i + 2];
                                cnt++;
                                opaque++;
                            }
                        }
                    }
                    int idx = oy * ow + ox;
                    if (cnt == 0) { outA[idx] = 0; continue; }
                    int r = (int)(sr / cnt), g = (int)(sg / cnt), b = (int)(sb / cnt);
                    outPix[idx] = (r << 16) | (g << 8) | b;
                    // 二值化：覆盖超过一半面积才算实心，像素画不留半透明毛边
                    outA[idx] = (byte)(opaque * 2 >= step * step ? 255 : 0);
                    if (outA[idx] == 255) samples.Add(outPix[idx]);
                }
            }

            if (buildPalette || _palette == null)
                _palette = KMeans(samples, k, 12);

            for (int i = 0; i < outPix.Length; i++)
            {
                if (outA[i] == 0) continue;
                outPix[i] = Nearest(outPix[i]);
            }

            using (var outBmp = new Bitmap(ow, oh, PixelFormat.Format32bppArgb))
            {
                var od = outBmp.LockBits(new Rectangle(0, 0, ow, oh), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                byte[] obuf = new byte[Math.Abs(od.Stride) * oh];
                int ostride = Math.Abs(od.Stride);
                for (int y = 0; y < oh; y++)
                {
                    for (int x = 0; x < ow; x++)
                    {
                        int i = y * ow + x;
                        int o = y * ostride + x * 4;
                        int c = outPix[i];
                        obuf[o] = (byte)(c & 0xFF);
                        obuf[o + 1] = (byte)((c >> 8) & 0xFF);
                        obuf[o + 2] = (byte)((c >> 16) & 0xFF);
                        obuf[o + 3] = outA[i];
                    }
                }
                try { Marshal.Copy(obuf, 0, od.Scan0, obuf.Length); }
                finally { outBmp.UnlockBits(od); }
                outBmp.Save(dst, ImageFormat.Png);
            }

            return string.Format("{0} -> {1} {2}x{3} palette={4}",
                System.IO.Path.GetFileName(src), System.IO.Path.GetFileName(dst), ow, oh, _palette.Length);
        }
    }

    static int[] KMeans(List<int> px, int k, int iters)
    {
        if (px.Count == 0) return new int[] { 0 };
        if (px.Count <= k) return px.ToArray();
        var rnd = new Random(20261124);
        var cent = new int[k];
        for (int i = 0; i < k; i++) cent[i] = px[rnd.Next(px.Count)];

        var assign = new int[px.Count];
        for (int it = 0; it < iters; it++)
        {
            for (int i = 0; i < px.Count; i++)
            {
                int best = 0, bestD = int.MaxValue;
                for (int c = 0; c < k; c++)
                {
                    int d = Dist(px[i], cent[c]);
                    if (d < bestD) { bestD = d; best = c; }
                }
                assign[i] = best;
            }
            var sr = new long[k]; var sg = new long[k]; var sb = new long[k]; var n = new long[k];
            for (int i = 0; i < px.Count; i++)
            {
                int c = assign[i];
                sr[c] += (px[i] >> 16) & 0xFF;
                sg[c] += (px[i] >> 8) & 0xFF;
                sb[c] += px[i] & 0xFF;
                n[c]++;
            }
            for (int c = 0; c < k; c++)
            {
                if (n[c] == 0) continue;
                cent[c] = ((int)(sr[c] / n[c]) << 16) | ((int)(sg[c] / n[c]) << 8) | (int)(sb[c] / n[c]);
            }
        }
        return cent;
    }

    static int Dist(int a, int b)
    {
        int dr = ((a >> 16) & 0xFF) - ((b >> 16) & 0xFF);
        int dg = ((a >> 8) & 0xFF) - ((b >> 8) & 0xFF);
        int db = (a & 0xFF) - (b & 0xFF);
        return dr * dr + dg * dg + db * db;
    }

    static int Nearest(int c)
    {
        int best = _palette[0], bestD = int.MaxValue;
        for (int i = 0; i < _palette.Length; i++)
        {
            int d = Dist(c, _palette[i]);
            if (d < bestD) { bestD = d; best = _palette[i]; }
        }
        return best;
    }
}
