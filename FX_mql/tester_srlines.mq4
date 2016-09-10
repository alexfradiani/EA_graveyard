//+------------------------------------------------------------------+
//|                                                           tester |
//+------------------------------------------------------------------+

#property copyright "ALEXANDER FRADIANI"
#property version   "1.00"
#property strict

#define BORDER_OFFSET 17

int currentDay;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
    
    currentDay = NULL;
    
//---
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
   
//---
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    int t = TimeDay(TimeCurrent());
    if(currentDay != t) {
        //clear previous lines
        ObjectsDeleteAll(0, OBJ_HLINE);
        ObjectsDeleteAll(0, OBJ_VLINE);
                
        //vertical lines to separate day
        ObjectCreate("day separator 1", OBJ_VLINE, 0, Time[0], 0);
        ObjectCreate("day separator 2", OBJ_VLINE, 0, iTime(Symbol(), PERIOD_D1, 1), 0);
        
        //draw high and low of previous day
        double point = MarketInfo(Symbol(), MODE_POINT);
        double high = iHigh(Symbol(), PERIOD_D1, 1) + BORDER_OFFSET * point;
        double low = iLow(Symbol(), PERIOD_D1, 1) - BORDER_OFFSET * point;
        
        ObjectCreate("high", OBJ_HLINE, 0, Time[0], high);
        ObjectSetInteger(0, "high", OBJPROP_COLOR, clrWhite);
        
        ObjectCreate("low", OBJ_HLINE, 0, Time[0], low);
        ObjectSetInteger(0, "low", OBJPROP_COLOR, clrWhite);
        
        //draw middle price line
        double middle = low + (high - low) / 2;
        ObjectCreate("middle", OBJ_HLINE, 0, Time[0], middle);
        ObjectSetInteger(0, "middle", OBJPROP_COLOR, clrYellow);
        ObjectSetInteger(0, "middle", OBJPROP_STYLE, STYLE_DASH);
        
        //draw trending reversal points
        double srline = middle + (high - middle) / 2;
        string name = "trending reversal line up";
        ObjectCreate(name, OBJ_HLINE, 0, Time[0], srline);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
        
        name = "trending reversal line down";
        srline = middle - (high - middle) / 2;
        ObjectCreate(name, OBJ_HLINE, 0, Time[0], srline);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
        
        currentDay = t;
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+