using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;

public static class PixelMasks
{
    public static PointF[] Points(string data, float offsetX, float offsetY)
    {
        string[] items = data.Split(new[]{' '}, StringSplitOptions.RemoveEmptyEntries);
        PointF[] result = new PointF[items.Length];
        for(int i=0;i<items.Length;i++) {
            string[] xy=items[i].Split(',');
            result[i]=new PointF(float.Parse(xy[0],CultureInfo.InvariantCulture)+offsetX,float.Parse(xy[1],CultureInfo.InvariantCulture)+offsetY);
        }
        return result;
    }
    static double SignedDistance(double x, double y, PointF[] p)
    {
        bool inside=false;
        double distance=double.MaxValue;
        for(int i=0,j=p.Length-1;i<p.Length;j=i++) {
            double ax=p[j].X, ay=p[j].Y, bx=p[i].X, by=p[i].Y;
            if((ay>y)!=(by>y) && x<(bx-ax)*(y-ay)/(by-ay)+ax) inside=!inside;
            double dx=bx-ax,dy=by-ay;
            double t=Math.Max(0,Math.Min(1,((x-ax)*dx+(y-ay)*dy)/(dx*dx+dy*dy)));
            double ex=x-(ax+t*dx),ey=y-(ay+t*dy);
            distance=Math.Min(distance,Math.Sqrt(ex*ex+ey*ey));
        }
        return inside?distance:-distance;
    }
    public static Bitmap Extract(Bitmap source, Rectangle region, PointF[] body, PointF[] shadow)
    {
        Bitmap result=new Bitmap(region.Width,region.Height,PixelFormat.Format32bppArgb);
        for(int y=0;y<region.Height;y++) for(int x=0;x<region.Width;x++) {
            double px=region.X+x+.5,py=region.Y+y+.5;
            double shape=Math.Max(0,Math.Min(1,SignedDistance(px,py,body)+.5));
            // Selection feather on EXISTING source shadow. No shadow RGB is synthesized.
            double shadowSelection=Math.Max(0,Math.Min(1,SignedDistance(px,py,shadow)/2.0));
            int a=(int)Math.Round(255*Math.Max(shape,shadowSelection));
            Color original=source.GetPixel(region.X+x,region.Y+y);
            result.SetPixel(x,y,Color.FromArgb(a,original.R,original.G,original.B));
        }
        return result;
    }
    public static int[] Bounds(Bitmap bitmap)
    {
        int l=bitmap.Width,t=bitmap.Height,r=-1,b=-1;
        for(int y=0;y<bitmap.Height;y++) for(int x=0;x<bitmap.Width;x++) if(bitmap.GetPixel(x,y).A>0) {
            l=Math.Min(l,x);t=Math.Min(t,y);r=Math.Max(r,x);b=Math.Max(b,y);
        }
        return new[]{l,t,r+1,b+1};
    }
    public static long[] Check(Bitmap bitmap, Bitmap source, int sourceX, int sourceY)
    {
        long zero=0,partial=0,opaque=0,changed=0,border=0;
        for(int y=0;y<bitmap.Height;y++) for(int x=0;x<bitmap.Width;x++) {
            Color c=bitmap.GetPixel(x,y);
            if(c.A==0) zero++; else {
                if(c.A==255) opaque++;else partial++;
                Color s=source.GetPixel(sourceX+x,sourceY+y);
                if(s.R!=c.R || s.G!=c.G || s.B!=c.B) changed++;
                if(x==0||y==0||x==bitmap.Width-1||y==bitmap.Height-1) border++;
            }
        }
        return new[]{zero,partial,opaque,changed,border};
    }
    public static Bitmap AlphaImage(Bitmap bitmap)
    {
        Bitmap result=new Bitmap(bitmap.Width,bitmap.Height,PixelFormat.Format32bppArgb);
        for(int y=0;y<bitmap.Height;y++) for(int x=0;x<bitmap.Width;x++) {
            byte a=bitmap.GetPixel(x,y).A;
            result.SetPixel(x,y,Color.FromArgb(255,a,a,a));
        }
        return result;
    }
}
