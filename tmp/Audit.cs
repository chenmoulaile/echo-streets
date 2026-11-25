using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;

public class Audit
{
    static byte[] Pixels(string path, out int w, out int h, out int stride)
    {
        using (var bmp = new Bitmap(path))
        {
            w = bmp.Width; h = bmp.Height;
            var rect = new Rectangle(0, 0, w, h);
            var data = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            stride = Math.Abs(data.Stride);
            var buf = new byte[stride * h];
            Marshal.Copy(data.Scan0, buf, 0, buf.Length);
            bmp.UnlockBits(data);
            return buf;
        }
    }

    // 全图统计：平均亮度 / 对比度(亮度标准差) / 纯白削顶比 / 纯黑压死比 / 饱和度
    public static string Stats(string path)
    {
        int w, h, stride;
        var px = Pixels(path, out w, out h, out stride);
        double sum = 0.0, sum2 = 0.0, sat = 0.0;
        int white = 0, black = 0, n = w * h;
        for (int y = 0; y < h; y++)
        {
            int row = y * stride;
            for (int x = 0; x < w; x++)
            {
                int i = row + x * 4;
                int b = px[i], g = px[i + 1], r = px[i + 2];
                double lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
                sum += lum; sum2 += lum * lum;
                int mx = Math.Max(r, Math.Max(g, b));
                int mn = Math.Min(r, Math.Min(g, b));
                sat += mx == 0 ? 0.0 : (double)(mx - mn) / mx;
                if (r >= 250 && g >= 250 && b >= 250) white++;
                if (r <= 6 && g <= 6 && b <= 6) black++;
            }
        }
        double mean = sum / n;
        double sd = Math.Sqrt(Math.Max(sum2 / n - mean * mean, 0.0));
        return string.Format("lum={0:F3} sd={1:F3} white={2:F2}% black={3:F2}% sat={4:F3}",
            mean, sd, 100.0 * white / n, 100.0 * black / n, sat / n);
    }

    // 九宫格分区统计：定位"哪里过曝/哪里死黑"
    public static string Grid(string path)
    {
        int w, h, stride;
        var px = Pixels(path, out w, out h, out stride);
        var sb = new StringBuilder();
        sb.AppendLine("path=" + path + " " + w + "x" + h);
        for (int gy = 0; gy < 3; gy++)
        {
            for (int gx = 0; gx < 3; gx++)
            {
                int x0 = w * gx / 3, x1 = w * (gx + 1) / 3;
                int y0 = h * gy / 3, y1 = h * (gy + 1) / 3;
                double sum = 0.0; int cnt = 0, white = 0;
                for (int y = y0; y < y1; y++)
                {
                    int row = y * stride;
                    for (int x = x0; x < x1; x++)
                    {
                        int i = row + x * 4;
                        int b = px[i], g = px[i + 1], r = px[i + 2];
                        sum += (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
                        cnt++;
                        if (r >= 250 && g >= 250 && b >= 250) white++;
                    }
                }
                sb.AppendFormat("  [{0},{1}] lum={2:F3} white={3:F1}%\n",
                    gy, gx, sum / cnt, 100.0 * white / cnt);
            }
        }
        return sb.ToString();
    }

    // 逐行亮度剖面：找"某一条横向带异常"（如天花板偏灰、走道过曝）
    public static string Rows(string path, int step)
    {
        int w, h, stride;
        var px = Pixels(path, out w, out h, out stride);
        var sb = new StringBuilder();
        sb.AppendLine("rows=" + h + " step=" + step);
        for (int y = 0; y < h; y += step)
        {
            int row = y * stride;
            double sum = 0.0; int white = 0;
            for (int x = 0; x < w; x++)
            {
                int i = row + x * 4;
                int b = px[i], g = px[i + 1], r = px[i + 2];
                sum += (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
                if (r >= 250 && g >= 250 && b >= 250) white++;
            }
            sb.AppendFormat("  y={0,3} lum={1:F3} white={2:F1}%\n", y, sum / w, 100.0 * white / w);
        }
        return sb.ToString();
    }
}
