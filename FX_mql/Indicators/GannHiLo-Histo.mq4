//+------------------------------------------------------------------+
//   GannHiLo-Histo
//+------------------------------------------------------------------+
// Indicator properties
#property copyright ""
#property link      ""

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_color1 RoyalBlue
#property indicator_color2 Crimson
#property indicator_color3 Black
#property indicator_width1  4
#property indicator_width2  4
#property indicator_width3  4
#property indicator_maximum 1
#property indicator_minimum 0

// indicator parameters
extern int period=10;

// indicator buffers
double up_buffer[];
double dn_buffer[];
double ghl_buffer[];

//+------------------------------------------------------------------+
int init() {
  IndicatorBuffers(3); 
  SetIndexStyle(0,DRAW_HISTOGRAM);
  SetIndexBuffer(0,up_buffer);
  SetIndexLabel(0,NULL);
  SetIndexStyle(1,DRAW_HISTOGRAM);
  SetIndexBuffer(1,dn_buffer);
  SetIndexLabel(1,NULL);
  SetIndexStyle(2,DRAW_NONE);
  SetIndexBuffer(2,ghl_buffer);
  SetIndexLabel(2,NULL);
  IndicatorShortName("Gann HiLo");
  return(0);
}

//+------------------------------------------------------------------+
int deinit() {
   return (0);
}


//+------------------------------------------------------------------+
int start() {
  int limit, counted_bars, i;
  double period_high, period_low, period_mid, cur_level, prev_level, prev_value;
  
  counted_bars=IndicatorCounted();
  if(counted_bars < 0) return (-1); 
  if(counted_bars>0) counted_bars--;
  limit=MathMax(Bars-counted_bars,period);
  limit=Bars-counted_bars;
  
  //for (i=0; i<limit; i++) {
  for (i=limit; i>=0; i--) {
    ghl_buffer[i]=ghl_buffer[i+1];
    
    if (Close[i]==0)
      ghl_buffer[i]=EMPTY_VALUE;
    else if(Close[i]>iMA(Symbol(),0,period,0,MODE_SMA,PRICE_HIGH,i+1))
      ghl_buffer[i]=1;
    else if(Close[i]<iMA(Symbol(),0,period,0,MODE_SMA,PRICE_LOW,i+1))
      ghl_buffer[i]=-1;
    
    
    up_buffer[i] = EMPTY_VALUE;
    dn_buffer[i] = EMPTY_VALUE;
    
    if (ghl_buffer[i]==1) {
      up_buffer[i] = 1;
      dn_buffer[i] = 0;
    }
    else if (ghl_buffer[i]==-1){
      dn_buffer[i] = 1;
      up_buffer[i] = 0;
    }
    
  }
  return(0);
}
//+------------------------------------------------------------------+



