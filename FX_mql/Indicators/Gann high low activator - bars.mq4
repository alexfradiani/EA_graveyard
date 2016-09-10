//+------------------------------------------------------------------+
//|                                      Gann high low activator.mq5 |
//|                                                           mladen |
//+------------------------------------------------------------------+
#property copyright "mladen"
#property link      "mladenfx@gmail.com"

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   1
#property indicator_label1  "Gann high low"
//#property indicator_type1   DRAW_COLOR_HISTOGRAM2
#property indicator_color1  DeepSkyBlue,PaleVioletRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//
//
//
//
//

input int LookBack = 10;

//
//
//
//
//

double gannBufferUp[];
double gannBufferDn[];
double colorBuffer[];
double trend[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//
//
//
//
//

int OnInit()
{
   SetIndexBuffer(0,gannBufferUp, INDICATOR_DATA);
   SetIndexBuffer(1,gannBufferDn, INDICATOR_DATA);
   SetIndexBuffer(2,colorBuffer,INDICATOR_COLOR_INDEX); 
      IndicatorSetString(INDICATOR_SHORTNAME,"Gann high low activator("+string(LookBack)+")");
   return(0);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//
//
//
//
//

int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime &Time[],
                const double &Open[],
                const double &High[],
                const double &Low[],
                const double &Close[],
                const long &TickVolume[],
                const long &Volume[],
                const int &Spread[])
{                
   if (ArraySize(trend)!=rates_total) ArrayResize(trend,rates_total);
   
   //
   //
   //
   //
   //
   
   for (int i=(int)MathMax(prev_calculated-1,0); i<rates_total; i++)
   {
      double high = iSma(High,LookBack,i-1);
      double low  = iSma(Low ,LookBack,i-1);
      
         gannBufferUp[i] = High[i];
         gannBufferDn[i] = Low[i];
         if (i > 0)           trend[i] = trend[i-1];
         if (Close[i] > high) trend[i] =  1;
         if (Close[i] < low)  trend[i] = -1;
         if (trend[i] == 1) colorBuffer[i]=0;
         if (trend[i] ==-1) colorBuffer[i]=1;
   }
   return(rates_total);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//
//
//
//
//

double iSma(const double& array[], int length, int i)
{
   double avg = 0; for (int k=0; k<length && (i-k)>=0; k++) avg += array[i-k];
   return(avg/length);
}