//+------------------------------------------------------------------+
//|                                                          SFP.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

//VARIABLES
extern int MinBarsBetween=10;
extern int MinBarsBefore=10;
extern int MaxBarsBetween=150;

string LineName="SwingFailure-";

datetime lastTime;
int counted_bars = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    //clean drawn objects
    int z = ObjectsTotal();
    for (int y=z;y>0;y--) {
        if(StringFind(ObjectName(y),LineName) >= 0)
            ObjectDelete(ObjectName(y));
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    if(lastTime != Time[0]) {
        lastTime = Time[0];
        
        analyzeBar();
        counted_bars = Bars;//IndicatorCounted();
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+

void analyzeBar() {
    int limit = 0;
    int score;
    
    
    //---- last counted bar will be recounted
    if(counted_bars>0) counted_bars--;
    limit=Bars-counted_bars;
    
    for(int i=limit; i>=0; i--) {
      if (LocalMax(i+1)) {
         int LastSwingHigh = GetLastSwingHigh(i+1);
         if (LastSwingHigh > 0)
            DrawSwingHigh(LastSwingHigh,i+1);
      }
      if (LocalMin(i+1)) {
         int LastSwingLow = GetLastSwingLow(i+1);
         if (LastSwingLow > 0)
            DrawSwingLow(LastSwingLow,i+1);
      }
    }
}

/**-------------------------------------------------------------------------------FUNCTIONS TAKEN FROM ORIGINAL INDICATOR
 *
 */

bool LocalMax(int bar) {

   return(iHighest(NULL,0,MODE_HIGH,MinBarsBetween+1,bar) == bar);

}

bool LocalMin(int bar) {

   return(iLowest(NULL,0,MODE_LOW,MinBarsBetween+1,bar) == bar);

}

int GetLastSwingHigh(int bar) {
   int hi = iHighest(NULL,0,MODE_HIGH,MinBarsBetween,bar);
   //Print("iHighest ", hi);
   double maxhigh = High[hi];
   for (int i=bar+MinBarsBetween;i<=bar+MaxBarsBetween && i < Bars;i++) {
      maxhigh = MathMax(maxhigh,High[i]);
      if (High[i] > Close[bar] && High[i] < High[bar] && LocalMax(i) && High[i] >= maxhigh)
         return(i);
      if (High[i] > High[bar])
         break;
   }
   return(-1);
}  

/*int _iHighest(string symb, int timef, int mode, int count, int _start) {
    double highest = High[_start];
    int highestIndex = _start;
    
    for(int i = _start; i <= _start + count; i++)
        if(High[i] > highest) {
            highestIndex = i;
            highest = High[i];
        }
    return highestIndex;     
}*/

int GetLastSwingLow(int bar) {

   double minlow = Low[iLowest(NULL,0,MODE_LOW,MinBarsBetween,bar)];
   for (int i=bar+MinBarsBetween;i<=bar+MaxBarsBetween & i < Bars;i++) {
      minlow = MathMin(minlow,Low[i]);
      if (Low[i] < Close[bar] && Low[i] > Low[bar] && LocalMin(i) && Low[i] <= minlow)
         return(i);
      if (Low[i] < Low[bar])
         break;
   }
   return(-1);
}  

/*int _iLowest(string symb, int timef, int mode, int count, int _start) {
    double lowest = Low[_start];
    int lowestIndex = _start;
    
    for(int i = _start; i <= _start + count; i++) {
        if(Low[i] < lowest) {
            lowestIndex = i;
            lowest = Low[i];
        }     
    }
    
    return lowestIndex;
}*/

void DrawSwingHigh (int p1, int p2) {

   ObjectCreate(LineName+Time[p1],OBJ_TREND,0,Time[p1],Close[p2],Time[p2],Close[p2]);
   ObjectSet(LineName+Time[p1],OBJPROP_COLOR,Magenta);
   ObjectSet(LineName+Time[p1],OBJPROP_STYLE,STYLE_SOLID);
   ObjectSet(LineName+Time[p1],OBJPROP_WIDTH,3);   
   ObjectSet(LineName+Time[p1],OBJPROP_RAY,false);
}
void DrawSwingLow (int p1, int p2) {
   ObjectCreate(LineName+"l"+Time[p1],OBJ_TREND,0,Time[p1],Close[p2],Time[p2],Close[p2]);
   ObjectSet(LineName+"l"+Time[p1],OBJPROP_COLOR,Magenta);
   ObjectSet(LineName+"l"+Time[p1],OBJPROP_STYLE,STYLE_SOLID);
   ObjectSet(LineName+"l"+Time[p1],OBJPROP_WIDTH,3);   
   ObjectSet(LineName+"l"+Time[p1],OBJPROP_RAY,false);
} 

/**-------------------------------------------------------------------------------*/