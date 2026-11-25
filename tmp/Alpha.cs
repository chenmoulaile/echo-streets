using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class Alpha
{
    public static string BBox(string path)
    {
        using (var bmp = new Bitmap(path))
        {
            int w = bmp.Width, h = bmp.Height;
            var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            byte[] buf = new byte[Math.Abs(data.Stride) * h];
            try { Marshal.Copy(data.Scan0, buf, 0, buf.Length); }
            finally { bmp.UnlockBits(data); }

            int stride = Math.Abs(data.Stride);
            int minX = w, minY = h, maxX = -1, maxY = -1;
            long opaque = 0;
            for (int y = 0; y < h; y++)
            {
                int row = y * stride;
                for (int x = 0; x < w; x++)
                {
                    int a = buf[row + x * 4 + 3];
                    if (a > 8)
                    {
                        opaque++;
                        if (x < minX) minX = x;
                        if (x > maxX) maxX = x;
                        if (y < minY) minY = y;
                        if (y > maxY) maxY = y;
                    }
                }
            }
            if (maxX < 0) return System.IO.Path.GetFileName(path) + ": fully transparent";
            return string.Format("{0}: {1}x{2} bbox=({3},{4})-({5},{6}) {7}x{8} opaque={9} ({10:F1}%)",
                System.IO.Path.GetFileName(path), w, h, minX, minY, maxX, maxY,
                maxX - minX + 1, maxY - minY + 1, opaque, 100.0 * opaque / ((long)w * h));
        }
    }

    /// 把透明边缘裁掉，输出到 dst。pad 为四周保留的透明像素。
    public static string Trim(string src, string dst, int pad)
    {
        using (var bmp = new Bitmap(src))
        {
            int w = bmp.Width, h = bmp.Height;
            var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            byte[] buf = new byte[Math.Abs(data.Stride) * h];
            try { Marshal.Copy(data.Scan0, buf, 0, buf.Length); }
            finally { bmp.UnlockBits(data); }
            int stride = Math.Abs(data.Stride);

            int minX = w, minY = h, maxX = -1, maxY = -1;
            for (int y = 0; y < h; y++)
            {
                int row = y * stride;
                for (int x = 0; x < w; x++)
                {
                    if (buf[row + x * 4 + 3] > 8)
                    {
                        if (x < minX) minX = x;
                        if (x > maxX) maxX = x;
                        if (y < minY) minY = y;
                        if (y > maxY) maxY = y;
                    }
                }
            }
            if (maxX < 0) return "EMPTY " + src;

            int x0 = Math.Max(0, minX - pad), y0 = Math.Max(0, minY - pad);
            int x1 = Math.Min(w - 1, maxX + pad), y1 = Math.Min(h - 1, maxY + pad);
            int cw = x1 - x0 + 1, ch = y1 - y0 + 1;

            using (var outBmp = new Bitmap(cw, ch, PixelFormat.Format32bppArgb))
            {
                var od = outBmp.LockBits(new Rectangle(0, 0, cw, ch), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                byte[] obuf = new byte[Math.Abs(od.Stride) * ch];
                int ostride = Math.Abs(od.Stride);
                try
                {
                    for (int y = 0; y < ch; y++)
                    {
                        Array.Copy(buf, (y0 + y) * stride + x0 * 4, obuf, y * ostride, cw * 4);
                    }
                    Marshal.Copy(obuf, 0, od.Scan0, obuf.Length);
                }
                finally { outBmp.UnlockBits(od); }
                outBmp.Save(dst, ImageFormat.Png);
            }
            return string.Format("{0} -> {1} {2}x{3}", System.IO.Path.GetFileName(src), System.IO.Path.GetFileName(dst), cw, ch);
        }
    }
}
