//+------------------------------------------------------------------+
//|                                                  ALX_mtf_adx.mq4 |
//+------------------------------------------------------------------+
#property copyright   "Alexander Fradiani"
#property description "multi timeframe ADX trigger"
#property strict

#property indicator_chart_window
#property indicator_buffers 6
#property indicator_color1 Yellow
#property indicator_color2 Yellow
#property indicator_color3 Aqua
#property indicator_color4 Aqua
#property indicator_color5 Red
#property indicator_color6 Red

#define DI_MIN_DISTANCE 3

#define UP 1
#define DOWN -1
#define NONE 0

#define SIGNAL_STRONGUP 2
#define SIGNAL_STRONGDOWN -2 
#define SIGNAL_WEAKUP 1
#define SIGNAL_WEAKDOWN -1 
#define SIGNAL_STOP 0

//--- buffers
double strongUp[];
double strongDown[];
double weakUp[];
double weakDown[];
double stopped[];
double summary[];

int trendState;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init(void) {
    IndicatorBuffers(6);
    IndicatorDigits(Digits);
    
    //arrows for long-term trending ADX
    SetIndexStyle(0, DRAW_ARROW, 3, 5);
    SetIndexArrow(0, 241);
    SetIndexBuffer(0, strongUp);
    SetIndexLabel(0, "STRONG BUY SIGNAL");
    SetIndexEmptyValue(0, 0.0);
    
    SetIndexStyle(1, DRAW_ARROW, 3, 5);
    SetIndexArrow(1, 242);
    SetIndexBuffer(1, strongDown);
    SetIndexLabel(1, "STRONG SELL SIGNAL");
    SetIndexEmptyValue(1, 0.0);
    
    //arrows for long-term weak ADX (below 25)
    SetIndexStyle(2, DRAW_ARROW, 3, 5);
    SetIndexArrow(2, 241);
    SetIndexBuffer(2, weakUp);
    SetIndexLabel(2, "WEAK BUY SIGNAL");
    SetIndexEmptyValue(2, 0.0);
    
    SetIndexStyle(3, DRAW_ARROW, 3, 5);
    SetIndexArrow(3, 242);
    SetIndexBuffer(3, weakDown);
    SetIndexLabel(3, "WEAK SELL SIGNAL");
    SetIndexEmptyValue(3, 0.0);
    
    SetIndexStyle(4, DRAW_ARROW, 3, 5);
    SetIndexArrow(4, 251);
    SetIndexBuffer(4, stopped);
    SetIndexLabel(4, "WAIT SIGNAL");
    SetIndexEmptyValue(4, 0.0);
    
    SetIndexStyle(5, DRAW_NONE, 3, 5);
    SetIndexBuffer(5, summary);
    SetIndexLabel(5, "INDICATOR VALUE");
    
    trendState = NONE;
    
    //--- initialization done
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| MTF MAs                                                          |
//+------------------------------------------------------------------+
int start() {
    int i,                           // Bar index
        Counted_bars;                // Number of counted bars
        
//--------------------------------------------------------------------
    Counted_bars = IndicatorCounted();     // Number of counted bars
    int bars = Bars;
    if(bars > 14400)
        bars = 14400;
        
    i = bars - Counted_bars - 1;           // Index of the first uncounted
    while(i >= 0) {                      // Loop for uncounted bars
        strongUp[i] = 0.0;
        strongDown[i] = 0.0;
        weakUp[i] = 0.0;
        weakDown[i] = 0.0;
        stopped[i] = 0.0;
        
        //set offset position to align m15 and h1 bars
        int hourShift = 0;
        int fifteenShift = 0;
        while(Time[i] < iTime(NULL, PERIOD_H1 , hourShift))
            hourShift++;
        while(Time[i] < iTime(NULL, PERIOD_M15 , fifteenShift))
            fifteenShift++;
        
        double adxHour_main = iADX(NULL, PERIOD_H1, 14, PRICE_CLOSE, MODE_MAIN, hourShift);
        double adxfifteen_minusDi = iADX(NULL, PERIOD_M15, 56, PRICE_CLOSE, MODE_MINUSDI, fifteenShift);
        double adxfifteen_plusDi = iADX(NULL, PERIOD_M15, 56, PRICE_CLOSE, MODE_PLUSDI, fifteenShift);
        
        if(adxHour_main > 25) {
            if(MathAbs(adxfifteen_plusDi - adxfifteen_minusDi) < DI_MIN_DISTANCE && trendState != NONE) {
                trendState = NONE;
                stopped[i] = iOpen(NULL, 0, i);
                summary[i] = SIGNAL_STOP;
            }
            
            if(MathAbs(adxfifteen_plusDi - adxfifteen_minusDi) >= DI_MIN_DISTANCE && trendState == NONE) {
                if(adxfifteen_plusDi > adxfifteen_minusDi) {
                    trendState = UP;
                    strongUp[i] = iOpen(NULL, PERIOD_M1, i);
                    summary[i] = SIGNAL_STRONGUP;
                }
                else {
                    trendState = DOWN;
                    strongDown[i] = iOpen(NULL, PERIOD_M1, i);
                    summary[i] = SIGNAL_STRONGDOWN;
                }
            }
        }
        else {
            if(MathAbs(adxfifteen_plusDi - adxfifteen_minusDi) < DI_MIN_DISTANCE && trendState != NONE) {
                trendState = NONE;
                stopped[i] = iOpen(NULL, PERIOD_M1, i);
                summary[i] = SIGNAL_STOP;
            }
            
            if(MathAbs(adxfifteen_plusDi - adxfifteen_minusDi) >= DI_MIN_DISTANCE && trendState == NONE) {
                if(adxfifteen_plusDi > adxfifteen_minusDi) {
                    trendState = UP;
                    weakUp[i] = iOpen(NULL, PERIOD_M1, i);
                    summary[i] = SIGNAL_WEAKUP;
                }
                else {
                    trendState = DOWN;
                    weakDown[i] = iOpen(NULL, PERIOD_M1, i);
                    summary[i] = SIGNAL_WEAKDOWN;
                }
            }
        }   
        
        i--;                          // Calculating index of the next bar
    }
    
//--------------------------------------------------------------------
    return(0);                          // Exit the special funct. start()
}
