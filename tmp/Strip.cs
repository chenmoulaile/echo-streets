using System;using System.Drawing;using System.Drawing.Imaging;using System.IO;
public class Strip {
  // 把一组 PNG 横向拼成一条胶片，每格放大 scale 倍，便于目视判断动画连贯性
  public static string Run(string[] files,string outPath,int scale){
    int n=files.Length; if(n==0) return "empty";
    using(var first=new Bitmap(files[0])){
      int w=first.Width,h=first.Height;
      using(var dst=new Bitmap(w*scale*n,h*scale,PixelFormat.Format32bppArgb)){
        using(var g=Graphics.FromImage(dst)){
          g.Clear(Color.FromArgb(255,24,26,32));
          g.InterpolationMode=System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor;
          g.PixelOffsetMode=System.Drawing.Drawing2D.PixelOffsetMode.Half;
          for(int i=0;i<n;i++){
            using(var b=new Bitmap(files[i])){ g.DrawImage(b,new Rectangle(i*w*scale,0,w*scale,h*scale)); }
            g.DrawLine(Pens.DimGray,i*w*scale,0,i*w*scale,h*scale);
          }
        }
        dst.Save(outPath,ImageFormat.Png);
      }
      return "strip "+outPath+" "+(w*scale*n)+"x"+(h*scale);
    }
  }
}
