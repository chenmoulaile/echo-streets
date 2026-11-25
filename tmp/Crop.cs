// Crop a region of a PNG and scale it up with nearest-neighbour, so pixel-level
// artifacts (colour casts, halos, wrong palette) are visible to the eye.
// Pure ASCII on purpose: Chinese comments inside a PowerShell here-string get
// mangled into the wrong codepage and break compilation.
using System;
using System.Drawing;
using System.Drawing.Drawing2D;

public class Crop
{
    public static string Run(string input, string output, int x, int y, int w, int h, int scale)
    {
        using (var src = new Bitmap(input))
        {
            int cw = Math.Min(w, src.Width - x);
            int ch = Math.Min(h, src.Height - y);
            using (var dst = new Bitmap(cw * scale, ch * scale))
            using (var g = Graphics.FromImage(dst))
            {
                g.InterpolationMode = InterpolationMode.NearestNeighbor;
                g.PixelOffsetMode = PixelOffsetMode.Half;
                g.DrawImage(src, new Rectangle(0, 0, cw * scale, ch * scale),
                    new Rectangle(x, y, cw, ch), GraphicsUnit.Pixel);
                dst.Save(output, System.Drawing.Imaging.ImageFormat.Png);
            }
            return string.Format("cropped {0} [{1},{2} {3}x{4}] -> {5} ({6}x{7})",
                input, x, y, cw, ch, output, cw * scale, ch * scale);
        }
    }

    // Average colour of a region, printed as hex + RGB triple.
    public static string Avg(string input, int x, int y, int w, int h)
    {
        using (var src = new Bitmap(input))
        {
            long r = 0, gg = 0, b = 0, n = 0;
            for (int yy = y; yy < Math.Min(y + h, src.Height); yy++)
            {
                for (int xx = x; xx < Math.Min(x + w, src.Width); xx++)
                {
                    Color c = src.GetPixel(xx, yy);
                    r += c.R; gg += c.G; b += c.B; n++;
                }
            }
            if (n == 0) return "empty region";
            int ar = (int)(r / n), ag = (int)(gg / n), ab = (int)(b / n);
            return string.Format("avg rgb({0},{1},{2}) #{3:X2}{4:X2}{5:X2}", ar, ag, ab, ar, ag, ab);
        }
    }
}
