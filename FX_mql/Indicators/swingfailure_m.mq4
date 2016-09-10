#property  copyright "Copyright © 2012, George Heitman"

//---- indicator settings
#property  indicator_chart_window

extern int MinBarsBetween=10;
extern int MinBarsBefore=10;
extern int MaxBarsBetween=150;

string LineName="SwingFailure-";

//---- indicator buffers

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()  {

   return(0);
}

  
int deinit() {
   int z = ObjectsTotal();
   for (int y=z;y>0;y--) {
      if (StringFind(ObjectName(y),LineName) >= 0)
         ObjectDelete(ObjectName(y));
   }

}

bool LocalMax(int bar) {

   return(iHighest(NULL,0,MODE_HIGH,MinBarsBetween+1,bar) == bar);

}

bool LocalMin(int bar) {

   return(iLowest(NULL,0,MODE_LOW,MinBarsBetween+1,bar) == bar);

}

int GetLastSwingHigh(int bar) {

   double maxhigh = High[iHighest(NULL,0,MODE_HIGH,MinBarsBetween,bar+1)];
   for (int i=bar+MinBarsBetween;i<=bar+MaxBarsBetween;i++) {
      maxhigh = MathMax(maxhigh,High[i]);
      if (High[i] > Close[bar] && High[i] < High[bar] && LocalMax(i) && High[i] >= maxhigh)
         return(i);
      if (High[i] > High[bar])
         break;
   }
   return(-1);
}  

int GetLastSwingLow(int bar) {

   double minlow = Low[iLowest(NULL,0,MODE_LOW,MinBarsBetween,bar+1)];
   for (int i=bar+MinBarsBetween;i<=bar+MaxBarsBetween;i++) {
      minlow = MathMin(minlow,Low[i]);
      if (Low[i] < Close[bar] && Low[i] > Low[bar] && LocalMin(i) && Low[i] <= minlow)
         return(i);
      if (Low[i] < Low[bar])
         break;
   }
   return(-1);
}  


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

int start()  {
   int limit;
   int counted_bars=IndicatorCounted();
   int score;
   
   
//---- last counted bar will be recounted
   if(counted_bars>0) counted_bars--;
   limit=Bars-counted_bars+1;

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
   return(0);
  }
//+------------------------------------------------------------------+


