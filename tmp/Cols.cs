using System;using System.Drawing;using System.Drawing.Imaging;using System.Runtime.InteropServices;
public class Cols {
  public static string Profile(string path,int y0,int y1){
    using(var bmp=new Bitmap(path)){
      int w=bmp.Width,h=bmp.Height;var sb=new System.Text.StringBuilder();
      var data=bmp.LockBits(new Rectangle(0,0,w,h),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
      var row=new int[w];
      for(int y=y0;y<=y1;y++){
        Marshal.Copy(IntPtr.Add(data.Scan0,y*data.Stride),row,0,w);
        sb.Append("y="+y+" : ");
        for(int x=0;x<w;x++){ int a=(row[x]>>24)&0xFF; sb.Append(a>40?"#":"."); }
        sb.Append('\n');
      }
      bmp.UnlockBits(data);return sb.ToString();
    }
  }
}
