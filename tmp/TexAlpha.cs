using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class TexAlpha
{
    // 返回 alpha 通道分布：mean / p10 / p50 / p90 / max / 全不透明像素占比
    public static string Hist(string path)
    {
        using (var bmp = new Bitmap(path))
        {
            int w = bmp.Width, h = bmp.Height;
            var rect = new Rectangle(0, 0, w, h);
            var data = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            int stride = data.Stride;
            var buf = new byte[stride * h];
            Marshal.Copy(data.Scan0, buf, 0, buf.Length);
            bmp.UnlockBits(data);

            long sum = 0, opaque = 0, total = 0;
            int max = 0;
            var hist = new int[256];
            for (int y = 0; y < h; y++)
            {
                int row = y * stride;
                for (int x = 0; x < w; x++)
                {
                    byte a = buf[row + x * 4 + 3];
                    hist[a]++;
                    sum += a;
                    if (a >= 250) opaque++;
                    if (a > max) max = a;
                    total++;
                }
            }
            int p10 = Pct(hist, total, 0.10);
            int p50 = Pct(hist, total, 0.50);
            int p90 = Pct(hist, total, 0.90);
            return string.Format("mean={0:F1} p10={1} p50={2} p90={3} max={4} opaque={5:F1}%",
                (double)sum / total, p10, p50, p90, max, 100.0 * opaque / total);
        }
    }

    static int Pct(int[] hist, long total, double q)
    {
        long target = (long)(total * q);
        long acc = 0;
        for (int i = 0; i < 256; i++)
        {
            acc += hist[i];
            if (acc >= target) return i;
        }
        return 255;
    }
}
