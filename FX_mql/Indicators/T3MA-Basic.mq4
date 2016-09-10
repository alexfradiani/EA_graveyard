//+---------------------------------------------------------------------------+
//| T3.mq4
//| MojoFX                                                           
//| http://groups.yahoo.com/group/MetaTrader_Experts_and_Indicators/
//| mods 2012:
//|  - Turned e1 to e6 into arrays to save calculated data for the next tick
//|  - Added maxbars parameter. Use to reduce startup time.
//+---------------------------------------------------------------------------+
#property copyright "MojoFX - Conversion only"
#property link      "http://groups.yahoo.com/group/MetaTrader_Experts_and_Indicators/"

#property indicator_chart_window
#property indicator_buffers 7
#property indicator_color1 Gold

extern int T3_period = 8;
extern double T3_b = 0.618;
extern int T3_maxbars = 500;  // 0=All bars in chart.

double t3[];
double e1[];
double e2[];
double e3[];
double e4[];
double e5[];
double e6[];

double c1,c2,c3,c4;
double n,w1,w2,b2,b3;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
//---- indicators setting
    SetIndexStyle(0,DRAW_LINE,STYLE_SOLID,1);
    SetIndexBuffer(0,t3);
    SetIndexLabel(0,"T3 "+T3_period);
    SetIndexStyle(1,DRAW_NONE);
    SetIndexBuffer(1,e1);
    SetIndexEmptyValue(1,0);
    SetIndexStyle(2,DRAW_NONE);
    SetIndexBuffer(2,e2);
    SetIndexEmptyValue(2,0);
    SetIndexStyle(3,DRAW_NONE);
    SetIndexBuffer(3,e3);
    SetIndexEmptyValue(3,0);
    SetIndexStyle(4,DRAW_NONE);
    SetIndexBuffer(4,e4);
    SetIndexEmptyValue(4,0);
    SetIndexStyle(5,DRAW_NONE);
    SetIndexBuffer(5,e5);
    SetIndexEmptyValue(5,0);
    SetIndexStyle(6,DRAW_NONE);
    SetIndexBuffer(6,e6);
    SetIndexEmptyValue(6,0);
    
    IndicatorDigits(MarketInfo(Symbol(),MODE_DIGITS));
    IndicatorShortName("T3MA("+T3_period+")");

//---- variable reset

    //e1=0; e2=0; e3=0; e4=0; e5=0; e6=0;
    c1=0; c2=0; c3=0; c4=0; 
    n=0; 
    w1=0; w2=0; 
    b2=0; b3=0;

    b2=T3_b*T3_b;
    b3=b2*T3_b;
    c1=-b3;
    c2=(3*(b2+b3));
    c3=-3*(2*b2+T3_b+b3);
    c4=(1+3*T3_b+b3+3*b2);
    n=T3_period;

    if (n<1) n=1;
    n = 1 + 0.5*(n-1);
    w1 = 2 / (n + 1);
    w2 = 1 - w1;
 
    return(0);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
  {
   int limit;
   int counted_bars=IndicatorCounted();
//---- check for possible errors
   if(counted_bars<0) return(-1);
//---- last counted bar will be recounted
   if(counted_bars>0) counted_bars--;
   limit=Bars-counted_bars;
   
   if (T3_maxbars>T3_period)
     limit=MathMin(limit,T3_maxbars);
   
//---- indicator calculation
    for(int i=limit; i>=0; i--)
    {
        e1[i] = w1*Close[i] + w2*e1[i+1];
        e2[i] = w1*e1[i] + w2*e2[i+1];
        e3[i] = w1*e2[i] + w2*e3[i+1];
        e4[i] = w1*e3[i] + w2*e4[i+1];
        e5[i] = w1*e4[i] + w2*e5[i+1];
        e6[i] = w1*e5[i] + w2*e6[i+1];
    
        t3[i]=c1*e6[i] + c2*e5[i] + c3*e4[i] + c4*e3[i];
    }   
//----
   return(0);
  }
//+------------------------------------------------------------------+