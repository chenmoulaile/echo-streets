// AI concept art -> hard-edged pixel sprite converter.
// Pipeline: chroma-key magenta -> mask watermark corner -> square bbox (feet aligned)
//           -> area-average downsample -> global k-means palette -> binary alpha.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class PxConv
{
    // Magenta background test: high R, low G, mid-high B, clearly separated from G.
    static bool IsMagenta(int r, int g, int b)
    {
        return r > 140 && g < 125 && b > 100 && (r - g) > 80 && (b - g) > 45;
    }

    struct Img { public int W; public int H; public float[] RGBA; }

    static Img Load(string path, bool maskWatermark)
    {
        using (var src = new Bitmap(path))
        using (var bmp = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb))
        {
            using (var g = Graphics.FromImage(bmp)) g.DrawImage(src, 0, 0, src.Width, src.Height);
            int w = bmp.Width;
            int h = bmp.Height;
            var rect = new Rectangle(0, 0, w, h);
            var data = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            var raw = new byte[w * h * 4];
            Marshal.Copy(data.Scan0, raw, 0, raw.Length);
            bmp.UnlockBits(data);

            var img = new Img();
            img.W = w;
            img.H = h;
            img.RGBA = new float[w * h * 4];
            for (int i = 0; i < w * h; i++)
            {
                int r = raw[i * 4 + 2];
                int gg = raw[i * 4 + 1];
                int b = raw[i * 4 + 0];
                int x = i % w;
                int y = i / w;
                bool bg = IsMagenta(r, gg, b);
                // The generator stamps its logo bottom-right; no character content reaches there.
                if (maskWatermark && x > (int)(w * 0.76) && y > (int)(h * 0.86)) bg = true;
                img.RGBA[i * 4 + 0] = r;
                img.RGBA[i * 4 + 1] = gg;
                img.RGBA[i * 4 + 2] = b;
                img.RGBA[i * 4 + 3] = bg ? 0f : 255f;
            }
            return img;
        }
    }

    static void BBox(Img img, out int minX, out int minY, out int maxX, out int maxY)
    {
        minX = img.W; minY = img.H; maxX = -1; maxY = -1;
        for (int y = 0; y < img.H; y++)
        {
            for (int x = 0; x < img.W; x++)
            {
                if (img.RGBA[(y * img.W + x) * 4 + 3] > 0f)
                {
                    if (x < minX) minX = x;
                    if (x > maxX) maxX = x;
                    if (y < minY) minY = y;
                    if (y > maxY) maxY = y;
                }
            }
        }
        if (maxX < 0) { minX = 0; minY = 0; maxX = img.W - 1; maxY = img.H - 1; }
    }

    // Area-average over foreground pixels only, so magenta fringe cannot bleed in.
    static float[] Downsample(Img img, int minX, int minY, int maxX, int maxY, int size)
    {
        int cw = maxX - minX + 1;
        int ch = maxY - minY + 1;
        var outBuf = new float[size * size * 4];
        for (int ty = 0; ty < size; ty++)
        {
            int sy0 = minY + (int)Math.Floor((double)ch * ty / size);
            int sy1 = minY + (int)Math.Ceiling((double)ch * (ty + 1) / size);
            if (sy1 <= sy0) sy1 = sy0 + 1;
            if (sy1 > maxY + 1) sy1 = maxY + 1;
            for (int tx = 0; tx < size; tx++)
            {
                int sx0 = minX + (int)Math.Floor((double)cw * tx / size);
                int sx1 = minX + (int)Math.Ceiling((double)cw * (tx + 1) / size);
                if (sx1 <= sx0) sx1 = sx0 + 1;
                if (sx1 > maxX + 1) sx1 = maxX + 1;
                double ar = 0, ag = 0, ab = 0;
                int n = 0;
                for (int sy = sy0; sy < sy1; sy++)
                {
                    for (int sx = sx0; sx < sx1; sx++)
                    {
                        int i = (sy * img.W + sx) * 4;
                        if (img.RGBA[i + 3] <= 0f) continue;
                        ar += img.RGBA[i];
                        ag += img.RGBA[i + 1];
                        ab += img.RGBA[i + 2];
                        n++;
                    }
                }
                int o = (ty * size + tx) * 4;
                if (n > 0)
                {
                    float rr = (float)(ar / n);
                    float gg2 = (float)(ag / n);
                    float bb = (float)(ab / n);
                    // Despill: the chroma key bleeds a magenta halo into silhouette
                    // edges. Any pixel whose R and B both sit above G is carrying
                    // key contamination, so pull them back toward G.
                    float excess = Math.Min(rr - gg2, bb - gg2);
                    if (excess > 0f)
                    {
                        rr -= excess * 0.85f;
                        bb -= excess * 0.85f;
                    }
                    outBuf[o] = rr;
                    outBuf[o + 1] = gg2;
                    outBuf[o + 2] = bb;
                }
                outBuf[o + 3] = n > 0 ? 255f : 0f;
            }
        }
        return outBuf;
    }

    static int[][] KMeans(List<int[]> pixels, int k, int iters)
    {
        var pal = new int[k][];
        var rnd = new Random(1337);
        for (int i = 0; i < k; i++) pal[i] = (int[])pixels[rnd.Next(pixels.Count)].Clone();
        var assign = new int[pixels.Count];
        for (int it = 0; it < iters; it++)
        {
            for (int p = 0; p < pixels.Count; p++)
            {
                long best = long.MaxValue;
                int bi = 0;
                for (int c = 0; c < k; c++)
                {
                    long dr = pixels[p][0] - pal[c][0];
                    long dg = pixels[p][1] - pal[c][1];
                    long db = pixels[p][2] - pal[c][2];
                    long d = dr * dr + dg * dg + db * db;
                    if (d < best) { best = d; bi = c; }
                }
                assign[p] = bi;
            }
            var sr = new long[k];
            var sg = new long[k];
            var sb = new long[k];
            var cnt = new int[k];
            for (int p = 0; p < pixels.Count; p++)
            {
                int c = assign[p];
                sr[c] += pixels[p][0];
                sg[c] += pixels[p][1];
                sb[c] += pixels[p][2];
                cnt[c]++;
            }
            for (int c = 0; c < k; c++)
            {
                if (cnt[c] > 0)
                {
                    pal[c] = new int[] { (int)(sr[c] / cnt[c]), (int)(sg[c] / cnt[c]), (int)(sb[c] / cnt[c]) };
                }
            }
        }
        return pal;
    }

    static int Nearest(int[][] pal, int r, int g, int b)
    {
        long best = long.MaxValue;
        int bi = 0;
        for (int c = 0; c < pal.Length; c++)
        {
            long dr = r - pal[c][0];
            long dg = g - pal[c][1];
            long db = b - pal[c][2];
            long d = dr * dr + dg * dg + db * db;
            if (d < best) { best = d; bi = c; }
        }
        return bi;
    }

    static void Save(int[][] pal, float[] buf, int size, string outPath)
    {
        using (var bmp = new Bitmap(size, size, PixelFormat.Format32bppArgb))
        {
            var rect = new Rectangle(0, 0, size, size);
            var data = bmp.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            var raw = new byte[size * size * 4];
            for (int i = 0; i < size * size; i++)
            {
                if (buf[i * 4 + 3] > 127f)
                {
                    int c = Nearest(pal, (int)buf[i * 4], (int)buf[i * 4 + 1], (int)buf[i * 4 + 2]);
                    raw[i * 4 + 0] = (byte)pal[c][2];
                    raw[i * 4 + 1] = (byte)pal[c][1];
                    raw[i * 4 + 2] = (byte)pal[c][0];
                    raw[i * 4 + 3] = 255;
                }
            }
            Marshal.Copy(raw, 0, data.Scan0, raw.Length);
            bmp.UnlockBits(data);
            bmp.Save(outPath, ImageFormat.Png);
        }
    }

    // Square crop centered on the content, feet pinned to the bottom edge so every
    // sprite in the set shares one ground line.
    public static string Run(string[] inputs, string[] outputs, int size, int k)
    {
        var bufs = new float[inputs.Length][];
        var pixels = new List<int[]>();
        for (int i = 0; i < inputs.Length; i++)
        {
            var img = Load(inputs[i], true);
            int minX, minY, maxX, maxY;
            BBox(img, out minX, out minY, out maxX, out maxY);
            int cw = maxX - minX + 1;
            int ch = maxY - minY + 1;
            int side = Math.Max(cw, ch);
            int cx = (minX + maxX) / 2;
            int x0 = cx - side / 2;
            int x1 = x0 + side - 1;
            int y1 = maxY;
            int y0 = y1 - side + 1;
            if (x0 < 0) { x1 -= x0; x0 = 0; }
            if (x1 > img.W - 1) { x0 -= (x1 - (img.W - 1)); x1 = img.W - 1; }
            if (y0 < 0) { y1 -= y0; y0 = 0; }
            bufs[i] = Downsample(img, x0, y0, x1, y1, size);
            for (int p = 0; p < size * size; p++)
            {
                if (bufs[i][p * 4 + 3] > 0f)
                {
                    pixels.Add(new int[] { (int)bufs[i][p * 4], (int)bufs[i][p * 4 + 1], (int)bufs[i][p * 4 + 2] });
                }
            }
        }
        var pal = KMeans(pixels, k, 10);
        var report = new System.Text.StringBuilder();
        for (int i = 0; i < inputs.Length; i++)
        {
            Save(pal, bufs[i], size, outputs[i]);
            report.Append(string.Format("wrote {0} {1}x{1}\n", outputs[i], size));
        }
        return report.ToString() + "palette=" + k + " sampled=" + pixels.Count;
    }
}
