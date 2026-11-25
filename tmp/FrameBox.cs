using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

/// 精确统计每一帧的不透明包围盒（按 __ 精确切分状态/方向，避免前缀串帧），
/// 并给出每个状态的统一裁剪窗口。
public class FrameBox
{
    public struct Box { public int X0, Y0, X1, Y1; public bool Empty; }

    public static string Scan(string dir, string prefix, string[] states, string[] dirs)
    {
        var sb = new StringBuilder();
        int gx0 = int.MaxValue, gy0 = int.MaxValue, gx1 = -1, gy1 = -1;

        foreach (var st in states)
        {
            foreach (var d in dirs)
            {
                string head = prefix + "__" + st + "__" + d + "__";
                var files = new List<string>();
                foreach (var f in Directory.GetFiles(dir, "*.png"))
                {
                    string n = Path.GetFileName(f);
                    if (n.StartsWith(head, StringComparison.Ordinal)) files.Add(f);
                }
                if (files.Count == 0) continue;
                files.Sort(StringComparer.Ordinal);

                int ux0 = int.MaxValue, uy0 = int.MaxValue, ux1 = -1, uy1 = -1;
                var parts = new List<string>();
                foreach (var f in files)
                {
                    Box b = One(f);
                    if (b.Empty) { parts.Add("EMPTY"); continue; }
                    parts.Add(string.Format("{0},{1}-{2},{3}", b.X0, b.Y0, b.X1, b.Y1));
                    if (b.X0 < ux0) ux0 = b.X0;
                    if (b.Y0 < uy0) uy0 = b.Y0;
                    if (b.X1 > ux1) ux1 = b.X1;
                    if (b.Y1 > uy1) uy1 = b.Y1;
                }
                if (ux1 < 0) continue;
                if (ux0 < gx0) gx0 = ux0;
                if (uy0 < gy0) gy0 = uy0;
                if (ux1 > gx1) gx1 = ux1;
                if (uy1 > gy1) gy1 = uy1;
                sb.AppendFormat("{0}/{1} n={2} union=({3},{4})-({5},{6}) {7}x{8}\n",
                    st, d, files.Count, ux0, uy0, ux1, uy1, ux1 - ux0, uy1 - uy0);
                sb.Append("    frames: " + string.Join(" ", parts) + "\n");
            }
        }
        sb.AppendFormat("GLOBAL ({0},{1})-({2},{3}) {4}x{5}\n", gx0, gy0, gx1, gy1, gx1 - gx0, gy1 - gy0);
        return sb.ToString();
    }

    public static Box One(string path)
    {
        using (var bmp = new Bitmap(path))
        {
            int w = bmp.Width, h = bmp.Height;
            var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            int stride = Math.Abs(data.Stride);
            byte[] buf = new byte[stride * h];
            try { Marshal.Copy(data.Scan0, buf, 0, buf.Length); }
            finally { bmp.UnlockBits(data); }

            int x0 = int.MaxValue, y0 = int.MaxValue, x1 = -1, y1 = -1;
            for (int y = 0; y < h; y++)
            {
                int row = y * stride;
                for (int x = 0; x < w; x++)
                {
                    if (buf[row + x * 4 + 3] > 96)
                    {
                        if (x < x0) x0 = x;
                        if (x > x1) x1 = x;
                        if (y < y0) y0 = y;
                        if (y > y1) y1 = y;
                    }
                }
            }
            if (x1 < 0) return new Box { Empty = true };
            return new Box { X0 = x0, Y0 = y0, X1 = x1 + 1, Y1 = y1 + 1 };
        }
    }
}
