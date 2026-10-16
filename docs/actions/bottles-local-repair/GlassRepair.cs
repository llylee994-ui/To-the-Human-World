using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;

public static class GlassRepair
{
    public static PointF[] Path(string text) {
        string[] items=text.Split(new[]{' '},StringSplitOptions.RemoveEmptyEntries);
        PointF[] p=new PointF[items.Length];
        for(int i=0;i<p.Length;i++) { string[] a=items[i].Split(',');p[i]=new PointF(float.Parse(a[0],CultureInfo.InvariantCulture),float.Parse(a[1],CultureInfo.InvariantCulture)); }
        return p;
    }
    static double Clamp(double x,double lo=0,double hi=1) { return Math.Max(lo,Math.Min(hi,x)); }
    static double Distance(double x,double y,PointF[] p) {
        bool inside=false; double d=1e9;
        for(int i=0,j=p.Length-1;i<p.Length;j=i++) {
            double ax=p[j].X,ay=p[j].Y,dx=p[i].X-ax,dy=p[i].Y-ay;
            if((ay>y)!=(p[i].Y>y) && x<dx*(y-ay)/dy+ax)inside=!inside;
            double t=Clamp(((x-ax)*dx+(y-ay)*dy)/(dx*dx+dy*dy));
            d=Math.Min(d,Math.Sqrt(Math.Pow(x-ax-t*dx,2)+Math.Pow(y-ay-t*dy,2)));
        }
        return inside?d:-d;
    }
    static double Selection(double x,double y,PointF[] p) { return Clamp((Distance(x,y,p)+.2)/.8); }
    static double Ellipse(double x,double y,double cx,double cy,double rx,double ry,double angle) {
        double r=angle*Math.PI/180,dx=x-cx,dy=y-cy;
        double u=(dx*Math.Cos(r)+dy*Math.Sin(r))/rx,v=(-dx*Math.Sin(r)+dy*Math.Cos(r))/ry;
        return Clamp(((1-Math.Sqrt(u*u+v*v))*Math.Min(rx,ry)+.2)/.8);
    }
    static PointF[] dateCork=Path("49,26 51,24.5 55,23.7 68,23.7 78,24.7 81.1,26.5 80,32 78.5,39 77.8,45 77.8,56.5 73,59.8 63,60.7 53,58.7 52.2,47 51.3,39.7 50,33");
    static PointF[] moneyCork=Path("122,32 126,30.7 140,30.7 150,32.3 153,34 151,43 149.2,47.5 150,60.7 148,65.8 139,67.7 129,66.2 124.6,63 124.8,51 123,42");
    static PointF[] glyphD=Path("43.1,91.5 46.2,91 51,92.2 54.8,96 56.9,101.9 56.1,109 54,112.8 49.1,116 44.7,116 42,113.2 42.5,109.8 43.1,108.9 43.3,98.5 41.7,96.3 41.2,93.3");
    static PointF[] holeD=Path("47.3,96.4 49.7,97.1 51.2,100.4 51.5,105.7 49.6,109.4 46.9,110.7");
    static PointF[] glyphA=Path("55.6,115.4 56.5,110.8 58.4,104.1 59.6,100.5 60.8,95.5 63.1,94 65.2,94.8 66.4,98.7 67.4,103.5 69.2,110.2 70.9,113.1 71.1,115.6 67.5,115.8 65.2,110.9 62,110.8 60.3,115.1 57.6,116.5");
    static PointF[] holeA=Path("62.6,101 64.1,104.1 64.2,106.9 61.5,107.2");
    static PointF[] glyphY=Path("71.2,94.5 73.3,94 75.1,95.5 77.7,100.5 78.8,101.2 81.1,96.8 84,93 86.2,93.8 85.3,98 82.8,102.7 81.5,106 80.9,108.3 81.1,113.4 79.8,116.4 76.8,116.4 74.9,114.8 75.2,111.1 76.2,107.1 73.5,101.7 70.6,97");
    static PointF[] dateHighlight=Path("48,65 52,67 48,75 43,85 40,100 38.5,114 35.8,114 36.7,94 39,84 43.2,74");
    static PointF[] moneyHighlight=Path("119.5,73 124,74 120,82 115,91 112,102 111,121 106.8,121 107,100 110,89 114.4,81");

    public static double Protection(double x,double y,bool date) {
        double p=Selection(x,y,date?dateCork:moneyCork);
        if(date) {
            p=Math.Max(p,Math.Min(Selection(x,y,glyphD),1-Selection(x,y,holeD)));
            p=Math.Max(p,Math.Min(Selection(x,y,glyphA),1-Selection(x,y,holeA)));
            p=Math.Max(p,Selection(x,y,glyphY));
            p=Math.Max(p,Ellipse(x,y,47.4,193,8.7,4.7,-20));
            p=Math.Max(p,Ellipse(x,y,62,194.8,10,6,0));
            p=Math.Max(p,Ellipse(x,y,61.8,185,6.5,5.5,-38));
            p=Math.Max(p,Ellipse(x,y,54.4,188,4.5,3,-10));
            p=Math.Max(p,Ellipse(x,y,72,187.7,5,3.8,0));
            p=Math.Max(p,Ellipse(x,y,79.4,194,8.5,6,-8));
            p=Math.Max(p,Ellipse(x,y,88,191.1,2.7,3.4,0));
            p=Math.Max(p,Ellipse(x,y,40.6,198,2.6,2.2,0));
        } else {
            p=Math.Max(p,Ellipse(x,y,123.5,180.5,17.4,10.5,-46));
            p=Math.Max(p,Ellipse(x,y,146.5,192.5,15.6,11.4,48));
            p=Math.Max(p,Ellipse(x,y,111.3,198.4,3,2.2,0));
            p=Math.Max(p,Ellipse(x,y,121.8,202.4,7.8,4.8,-15));
            p=Math.Max(p,Ellipse(x,y,135.7,207.3,9.1,6,-9));
            p=Math.Max(p,Ellipse(x,y,151.6,207,5.2,3.5,0));
            p=Math.Max(p,Ellipse(x,y,160.7,202,2.4,2.5,0));
        }
        return p;
    }
    static double Luma(Color c) { return .2126*c.R+.7152*c.G+.0722*c.B; }
    static double[] Blur(Bitmap src,int x,int y,int rx,int ry) {
        double[] a=new double[3]; double sum=0;
        for(int j=-ry;j<=ry;j++) for(int i=-rx;i<=rx;i++) {
            double w=Math.Exp(-.5*(i*i/(double)Math.Max(1,rx*rx/3)+j*j/(double)Math.Max(1,ry*ry/3)));
            Color c=src.GetPixel(Math.Max(0,Math.Min(src.Width-1,x+i)),Math.Max(0,Math.Min(src.Height-1,y+j)));
            a[0]+=w*c.R;a[1]+=w*c.G;a[2]+=w*c.B;sum+=w;
        }
        for(int k=0;k<3;k++)a[k]/=sum;
        return a;
    }
    static Color Mix(Color a,Color b,double weight) {
        if(weight>=.999999)return b;
        double aa=a.A/255.0*(1-weight),ba=b.A/255.0*weight,total=aa+ba;
        if(total<=0)return Color.FromArgb(0,0,0,0);
        return Color.FromArgb((int)Math.Round(total*255),(int)Math.Round((a.R*aa+b.R*ba)/total),(int)Math.Round((a.G*aa+b.G*ba)/total),(int)Math.Round((a.B*aa+b.B*ba)/total));
    }
    public static Bitmap Repair(Bitmap original,Bitmap source,int sourceX,int sourceY,string bodyText,string shadowText,bool date) {
        PointF[] body=Path(bodyText),shadow=Path(shadowText);
        Bitmap output=new Bitmap(original.Width,original.Height,PixelFormat.Format32bppArgb);
        double bottom=date?206.3:218.5;
        for(int y=0;y<output.Height;y++) for(int x=0;x<output.Width;x++) {
            Color old=original.GetPixel(x,y);
            if(old.A==0) {output.SetPixel(x,y,Color.Transparent);continue;}
            int gx=sourceX+x,gy=sourceY+y;
            double px=gx-1180+.5,py=gy-345+.5;
            double d=Distance(px,py,body),shape=Clamp(d+.5);
            Color repaired;
            if(shape>0) {
                // Glass: retain outline positions and source reflection strips;
                // contaminated core becomes a faint, nonzero transmission field.
                double edge=Math.Exp(-Math.Max(0,d-.65)/2.1);
                double lowY=date?70:77;
                double left=date?35.3:106.2,right=date?95.1:165.3;
                double u=Clamp((px-left)/(right-left));
                double sideWindow=Math.Max(Math.Exp(-Math.Pow((u-.08)/.10,2)),.60*Math.Exp(-Math.Pow((u-.94)/.07,2)));
                if(py<lowY)sideWindow*=.35;
                double[] color=Blur(source,gx,gy,1,5);
                double luminance=.2126*color[0]+.7152*color[1]+.0722*color[2];
                double reflection=Clamp((luminance-95)/160,0,.7)*sideWindow;
                double alpha=.065+.63*edge+reflection*.26;
                double blend=Clamp(edge*.96+reflection*.8);
                double[] tint={103,117,109};
                double rr=tint[0]*(1-blend)+color[0]*blend;
                double gg=tint[1]*(1-blend)+color[1]*blend;
                double bb=tint[2]*(1-blend)+color[2]*blend;
                // Opaque rim detail is confined to the existing 2px glass silhouette.
                if(d<1.8) { rr=old.R;gg=old.G;bb=old.B; }
                // Keep the ORIGINAL warm shoulder highlight, not an invented ring.
                double highlight=Selection(px,py,date?dateHighlight:moneyHighlight);
                double highlightStrength=highlight*Clamp((Luma(old)-125)/105);
                if(highlightStrength>0) {
                    rr=rr*(1-highlightStrength)+old.R*highlightStrength;
                    gg=gg*(1-highlightStrength)+old.G*highlightStrength;
                    bb=bb*(1-highlightStrength)+old.B*highlightStrength;
                    alpha=Math.Max(alpha,highlightStrength*.85);
                }
                if(py>bottom-5.5) {alpha=.80;rr=old.R;gg=old.G;bb=old.B;}
                repaired=Color.FromArgb((int)Math.Round(255*Clamp(alpha)*shape),(int)Math.Round(Clamp(rr,0,255)),(int)Math.Round(Clamp(gg,0,255)),(int)Math.Round(Clamp(bb,0,255)));
            } else {
                // Recover only the existing shadow's darkening; remove tabletop RGB.
                double existing=Clamp(Distance(px,py,shadow)/2.0);
                double[] s=Blur(source,gx,gy,3,2);
                int left=(date?1206:1278),right=(date?1281:1353);
                double background=(Luma(source.GetPixel(left,gy))+Luma(source.GetPixel(right,gy)))*.5;
                double darkening=Clamp((background-(.2126*s[0]+.7152*s[1]+.0722*s[2]))/Math.Max(40,background),0,.32);
                double contactOnly=Math.Exp(-Math.Pow(Math.Max(0,py-bottom)/2.2,2));
                repaired=Color.FromArgb((int)Math.Round(255*existing*darkening*contactOnly*.70),43,38,31);
            }
            double p=Protection(px,py,date);
            repaired=Mix(repaired,old,p);
            if(repaired.A>old.A)repaired=Color.FromArgb(old.A,repaired.R,repaired.G,repaired.B);
            output.SetPixel(x,y,repaired);
        }
        return output;
    }
    public static Bitmap ProtectedMask(Bitmap asset,int sourceX,int sourceY,bool date) {
        Bitmap result=new Bitmap(asset.Width,asset.Height,PixelFormat.Format32bppArgb);
        for(int y=0;y<asset.Height;y++)for(int x=0;x<asset.Width;x++) {
            int v=asset.GetPixel(x,y).A==0?0:(int)Math.Round(255*Protection(sourceX+x-1180+.5,sourceY+y-345+.5,date));
            result.SetPixel(x,y,Color.FromArgb(255,v,v,v));
        }
        return result;
    }
    public static long[] Inspect(Bitmap original,Bitmap output,int sourceX,int sourceY,bool date) {
        long core=0,coreDiff=0,changed=0,expanded=0,zero=0,partial=0,opaque=0,border=0;
        for(int y=0;y<output.Height;y++)for(int x=0;x<output.Width;x++) {
            Color a=original.GetPixel(x,y),b=output.GetPixel(x,y);
            double p=Protection(sourceX+x-1180+.5,sourceY+y-345+.5,date);
            if(p>=.999999 && a.A>0) {core++;if(a.ToArgb()!=b.ToArgb())coreDiff++;}
            if(a.A>0 && a.ToArgb()!=b.ToArgb())changed++;
            if(a.A==0 && b.A>0)expanded++;
            if(b.A==0)zero++;else if(b.A==255)opaque++;else partial++;
            if(b.A>0 && (x==0||y==0||x==output.Width-1||y==output.Height-1))border++;
        }
        return new[]{core,coreDiff,changed,expanded,zero,partial,opaque,border};
    }
    public static double[] Alpha(Bitmap b,Rectangle probe) {
        int min=255,max=0,left=b.Width,top=b.Height,right=-1,bottom=-1;double sum=0;
        for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++) {
            int a=b.GetPixel(x,y).A;
            if(a>0){left=Math.Min(left,x);top=Math.Min(top,y);right=Math.Max(right,x);bottom=Math.Max(bottom,y);}
            if(probe.Contains(x,y)){min=Math.Min(min,a);max=Math.Max(max,a);sum+=a;}
        }
        return new[]{(double)min,max,sum/(probe.Width*probe.Height),left,top,right+1,bottom+1};
    }
    public static long[] SceneDiff(Bitmap a,Bitmap b,Rectangle one,Rectangle two) {
        long changed=0,outside=0;
        for(int y=0;y<a.Height;y++)for(int x=0;x<a.Width;x++)if(a.GetPixel(x,y).ToArgb()!=b.GetPixel(x,y).ToArgb()) {
            changed++;if(!one.Contains(x,y)&&!two.Contains(x,y))outside++;
        }
        return new[]{changed,outside};
    }
}
