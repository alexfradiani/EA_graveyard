//------------------------------------------------------------------
#property copyright "www.forex-tsd.com"
#property link      "www.forex-tsd.com"
//------------------------------------------------------------------
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_color1 LimeGreen
#property indicator_color2 PaleVioletRed
#property indicator_color3 LimeGreen
#property indicator_color4 PaleVioletRed
#property indicator_color5 PaleVioletRed
#property indicator_width1 2
#property indicator_width2 2
#property indicator_width3 2
#property indicator_width4 2
#property indicator_width5 2

//
//
//
//
//

extern int    NlmPeriod      = 25;
extern int    NlmPrice       = PRICE_CLOSE;
extern double PctFilter      = 0;
extern int    Shift          = 0;
extern bool   DrawColorLines = false;
extern bool   DrawColorBars  = true;
extern bool   alertsOn          = false;
extern bool   alertsOnCurrent   = true;
extern bool   alertsMessage     = true;
extern bool   alertsSound       = false;
extern bool   alertsEmail       = false;

//
//
//
//
//

double nlmHu[];
double nlmHd[];
double nlmDa[];
double nlmDb[];
double trend[];
double nlm[];

//------------------------------------------------------------------
//
//------------------------------------------------------------------
//
//
//
//
//

int init()
{
   int style = DRAW_NONE; if (DrawColorBars)  style = DRAW_HISTOGRAM;
   IndicatorBuffers(6);
   SetIndexBuffer(0,nlmHu); SetIndexStyle(0,style); 
   SetIndexBuffer(1,nlmHd); SetIndexStyle(1,style); 
   
       style = DRAW_NONE; if (DrawColorLines) style = DRAW_LINE;
   SetIndexBuffer(2,nlm);   SetIndexStyle(2,style); SetIndexShift(2,Shift);
   SetIndexBuffer(3,nlmDa); SetIndexStyle(3,style); SetIndexShift(3,Shift);
   SetIndexBuffer(4,nlmDb); SetIndexStyle(4,style); SetIndexShift(4,Shift);
   SetIndexBuffer(5,trend);
   return(0);
}
int deinit() { return(0); }

//------------------------------------------------------------------
//
//------------------------------------------------------------------
//
//
//
//
//

double work[][2];
#define _change 0
#define _achang 1
int start()
{
   int i,r,counted_bars=IndicatorCounted();
      if(counted_bars<0) return(-1);
      if(counted_bars>0) counted_bars--;
           int limit=MathMin(Bars-counted_bars,Bars-1);
           if (ArrayRange(work,0)!=Bars) ArrayResize(work,Bars);

   //
   //
   //
   //
   //

   if (trend[limit]==-1) CleanPoint(limit,nlmDa,nlmDb);
   for(i=limit, r=Bars-i-1; i>=0; i--,r++)
   {
      nlm[i]   = iNonLagMa(iMA(NULL,0,1,0,MODE_SMA,NlmPrice,i),NlmPeriod,i,0);
      nlmDa[i] = EMPTY_VALUE;
      nlmDb[i] = EMPTY_VALUE;
      trend[i] = trend[i+1];

         //
         //
         //
         //
         //
               
         if (PctFilter>0)
         {
            work[r][_change] = MathAbs(nlm[i]-nlm[i+1]);
            work[r][_achang] = work[r][_change];
            for (int k=1; k<NlmPeriod; k++) work[r][_achang] += work[r-k][_change];
                                            work[r][_achang] /= 1.0*NlmPeriod;
    
            double stddev = 0; for (k=0; k<NlmPeriod; k++) stddev += MathPow(work[r-k][_change]-work[r-k][_achang],2);
                   stddev = MathSqrt(stddev/NlmPeriod); 
            double filter = PctFilter * stddev;
            if( MathAbs(nlm[i]-nlm[i+1]) < filter ) nlm[i]=nlm[i+1];
         }

         //
         //
         //
         //
         //
               
         if (nlm[i]>nlm[i+1]) trend[i] =  1;
         if (nlm[i]<nlm[i+1]) trend[i] = -1;
         if (trend[i]>0) { nlmHu[i] = High[i];  nlmHd[i] = Low[i]; }
         else            { nlmHd[i] = High[i];  nlmHu[i] = Low[i]; }
         if (trend[i] == -1) PlotPoint(i,nlmDa,nlmDb,nlm);
   }
   manageAlerts();
   return(0);
}



//-------------------------------------------------------------------
//
//-------------------------------------------------------------------
//
//
//
//
//

#define Pi       3.14159265358979323846264338327950288
#define _length  0
#define _len     1
#define _weight  2

double  nlmvalues[1][3];
double  nlmprices[ ][1];
double  nlmalphas[ ][1];

//
//
//
//
//

double iNonLagMa(double price, double length, int r, int instanceNo=0)
{
   r = Bars-r-1;
   if (ArrayRange(nlmprices,0) != Bars)         ArrayResize(nlmprices,Bars);
   if (ArrayRange(nlmvalues,0) <  instanceNo+1) ArrayResize(nlmvalues,instanceNo+1);
                               nlmprices[r][instanceNo]=price;
   if (length<3 || r<3) return(nlmprices[r][instanceNo]);
   
   //
   //
   //
   //
   //
   
   if (nlmvalues[instanceNo][_length] != length  || ArraySize(nlmalphas)==0)
   {
      double Cycle = 4.0;
      double Coeff = 3.0*Pi;
      int    Phase = length-1;
      
         nlmvalues[instanceNo][_length] = length;
         nlmvalues[instanceNo][_len   ] = length*4 + Phase;  
         nlmvalues[instanceNo][_weight] = 0;

         if (ArrayRange(nlmalphas,0) < nlmvalues[instanceNo][_len]) ArrayResize(nlmalphas,nlmvalues[instanceNo][_len]);
         for (int k=0; k<nlmvalues[instanceNo][_len]; k++)
         {
            if (k<=Phase-1) 
                 double t = 1.0 * k/(Phase-1);
            else        t = 1.0 + (k-Phase+1)*(2.0*Cycle-1.0)/(Cycle*length-1.0); 
            double beta = MathCos(Pi*t);
            double g = 1.0/(Coeff*t+1); if (t <= 0.5 ) g = 1;
      
            nlmalphas[k][instanceNo]        = g * beta;
            nlmvalues[instanceNo][_weight] += nlmalphas[k][instanceNo];
         }
   }
   
   //
   //
   //
   //
   //
   
   if (nlmvalues[instanceNo][_weight]>0)
   {
      double sum = 0;
           for (k=0; k < nlmvalues[instanceNo][_len]; k++) sum += nlmalphas[k][instanceNo]*nlmprices[r-k][instanceNo];
           return( sum / nlmvalues[instanceNo][_weight]);
   }
   else return(0);           
}

//-------------------------------------------------------------------
//
//-------------------------------------------------------------------
//
//
//
//
//

void CleanPoint(int i,double& first[],double& second[])
{
   if ((second[i]  != EMPTY_VALUE) && (second[i+1] != EMPTY_VALUE))
        second[i+1] = EMPTY_VALUE;
   else
      if ((first[i] != EMPTY_VALUE) && (first[i+1] != EMPTY_VALUE) && (first[i+2] == EMPTY_VALUE))
          first[i+1] = EMPTY_VALUE;
}

//
//
//
//
//

void PlotPoint(int i,double& first[],double& second[],double& from[])
{
   if (first[i+1] == EMPTY_VALUE)
      {
         if (first[i+2] == EMPTY_VALUE) {
                first[i]   = from[i];
                first[i+1] = from[i+1];
                second[i]  = EMPTY_VALUE;
            }
         else {
                second[i]   =  from[i];
                second[i+1] =  from[i+1];
                first[i]    = EMPTY_VALUE;
            }
      }
   else
      {
         first[i]  = from[i];
         second[i] = EMPTY_VALUE;
      }
}

//-------------------------------------------------------------------
//                                                                  
//-------------------------------------------------------------------
//
//
//
//
//

void manageAlerts()
{
   if (alertsOn)
   {
      if (alertsOnCurrent)
           int whichBar = 0;
      else     whichBar = 1; 
      if (trend[whichBar]!=trend[whichBar+1])
      {
         if (trend[whichBar] ==  1) doAlert("up");
         if (trend[whichBar] == -1) doAlert("down");
      }         
   }
}

//
//
//
//
//

void doAlert(string doWhat)
{
   static string   previousAlert="nothing";
   string message;
   
   if (previousAlert != doWhat) {
       previousAlert  = doWhat;

       //
       //
       //
       //
       //

       message = Symbol()+" at "+TimeToStr(TimeLocal(),TIME_SECONDS)+" NonLag MA trend changed to "+doWhat;
          if (alertsMessage) Alert(message);
          if (alertsEmail)   SendMail(StringConcatenate(Symbol()," NonLag MA"),message);
          if (alertsSound)   PlaySound("alert2.wav");
   }
}