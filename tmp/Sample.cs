using System;
using System.Drawing;

// Samples mean RGB over named rectangular regions of a PNG so visual fixes are
// driven by measured luminance instead of guesses.
public class Sample
{
    public static string Run(string path)
    {
        using (var bmp = new Bitmap(path))
        {
            var sb = new System.Text.StringBuilder();
            sb.Append("image ").Append(bmp.Width).Append("x").Append(bmp.Height).Append("\n");
            Region(sb, bmp, "wall_left", 20, 110, 90, 60);
            Region(sb, bmp, "wall_right", 390, 110, 70, 60);
            Region(sb, bmp, "floor_center", 200, 215, 80, 30);
            Region(sb, bmp, "ceiling", 200, 40, 80, 30);
            Region(sb, bmp, "viewmodel", 316, 140, 160, 120);
            Region(sb, bmp, "whole", 0, 0, bmp.Width, bmp.Height);
            return sb.ToString();
        }
    }

    private static void Region(System.Text.StringBuilder sb, Bitmap bmp, string name, int x0, int y0, int w, int h)
    {
        long r = 0, g = 0, b = 0, n = 0;
        int maxLum = 0;
        for (int y = y0; y < y0 + h && y < bmp.Height; y++)
        {
            for (int x = x0; x < x0 + w && x < bmp.Width; x++)
            {
                Color c = bmp.GetPixel(x, y);
                r += c.R; g += c.G; b += c.B; n++;
                int lum = (c.R * 30 + c.G * 59 + c.B * 11) / 100;
                if (lum > maxLum) maxLum = lum;
            }
        }
        if (n == 0) { sb.Append(name).Append(": empty\n"); return; }
        double ar = (double)r / n, ag = (double)g / n, ab = (double)b / n;
        int avgLum = (int)((ar * 0.30 + ag * 0.59 + ab * 0.11));
        sb.Append(string.Format("{0,-14} mean=({1,5:F1},{2,5:F1},{3,5:F1}) lum={4,3} peak={5,3}\n",
            name, ar, ag, ab, avgLum, maxLum));
    }
}
