using System;using System.Drawing;using System.Drawing.Imaging;using System.Runtime.InteropServices;
public class Diff {
  static int[] Load(string p,out int w,out int h){
    using(var b=new Bitmap(p)){ w=b.Width;h=b.Height;var px=new int[w*h];
      var d=b.LockBits(new Rectangle(0,0,w,h),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
      var row=new int[w];
      for(int y=0;y<h;y++){ Marshal.Copy(IntPtr.Add(d.Scan0,y*d.Stride),row,0,w); Array.Copy(row,0,px,y*w,w);} 
      b.UnlockBits(d); return px; } }
  // 统计 a 与 b 在指定区域的不透明掩码差异像素数
  public static string Region(string a,string b,int x0,int y0,int x1,int y1){
    int w,h;var pa=Load(a,out w,out h);var pb=Load(b,out w,out h);
    int diff=0,tot=0;
    for(int y=y0;y<=y1;y++)for(int x=x0;x<=x1;x++){
      int ia=(pa[y*w+x]>>24&0xFF)>40?1:0; int ib=(pb[y*w+x]>>24&0xFF)>40?1:0;
      if(ia!=ib) diff++; if(ia>0||ib>0) tot++;
    }
    return "diff="+diff+" union="+tot+" ratio="+(tot==0?0.0:100.0*diff/tot).ToString("F1")+"%";
  }
}
