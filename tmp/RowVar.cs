using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class RowVar
{
    // 行内亮度方差：sum2/n - mean^2。
    // 用途：判断等距柱状天空图的「地平线以下」是否有沿 x 的结构（街区/街道）。
    // 为什么不用「相邻行均值差」：楼群是水平错落的，同一行里不同 x 落在不同楼/街道上，
    //   但整行均值几乎不变，用行间差永远读成 0。
    public static string Scan(string path, int y0, int y1, int step)
    {
        using (var bmp = new Bitmap(path))
        {
            int w = bmp.Width;
            int h = bmp.Height;
            var rect = new Rectangle(0, 0, w, h);
            BitmapData bd = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            int stride = bd.Stride;
            byte[] buf = new byte[stride * h];
            Marshal.Copy(bd.Scan0, buf, 0, buf.Length);
            bmp.UnlockBits(bd);

            var sb = new System.Text.StringBuilder();
            double maxVar = 0.0;
            int maxY = y0;
            for (int y = y0; y <= y1 && y < h; y += step)
            {
                double sum = 0.0, sum2 = 0.0;
                int n = 0;
                for (int x = 0; x < w; x++)
                {
                    int o = y * stride + x * 4;
                    double l = (0.299 * buf[o + 2] + 0.587 * buf[o + 1] + 0.114 * buf[o]) / 255.0;
                    sum += l;
                    sum2 += l * l;
                    n++;
                }
                double mean = sum / n;
                double v = sum2 / n - mean * mean;
                if (v > maxVar) { maxVar = v; maxY = y; }
                sb.Append(string.Format("y={0} mean={1:F3} hvar={2:F5}\n", y, mean, v));
            }
            sb.Append(string.Format("MAX hvar={0:F5} at y={1}\n", maxVar, maxY));
            return sb.ToString();
        }
    }
}
