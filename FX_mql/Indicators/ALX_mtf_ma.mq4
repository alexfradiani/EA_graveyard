//+------------------------------------------------------------------+
//|                                                   ALX_mtf_ma.mq4 |
//+------------------------------------------------------------------+
#property copyright   "Alexander Fradiani"
#property description "h1 and m1 moving averages"
#property strict

#property indicator_chart_window
#property indicator_buffers 8
#property indicator_color1 Red
#property indicator_color2 Magenta
#property indicator_color3 Aqua
#property indicator_color4 Red
#property indicator_color5 Magenta
#property indicator_color6 Aqua

#property indicator_color7 LawnGreen
#property indicator_color8 Red

#define UP 1
#define NONE 0
#define DOWN -1

//--- indicator parameters
//input int    longTFperiod = 20;

//--- buffers
double h1_5EMA[];
double h1_34EMA[];
double h1_200SMA[];
double m1_5EMA[];
double m1_34EMA[];
double m1_200SMA[];

double upArrows[];
double downArrows[];

int priceSide = NONE;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init(void) {
    IndicatorBuffers(8);
    IndicatorDigits(Digits);
    
    //--- H1 5EMA
    SetIndexStyle(0, DRAW_LINE, EMPTY, 3);
    SetIndexBuffer(0, h1_5EMA);
    SetIndexLabel(0, "H1 5EMA");
    
    //--- H1 34EMA
    SetIndexStyle(1, DRAW_LINE, EMPTY, 3);
    SetIndexBuffer(1, h1_34EMA);
    SetIndexLabel(1, "H1 34EMA");
    
    //--- H1 200SMA
    SetIndexStyle(2, DRAW_LINE, EMPTY, 3);
    SetIndexBuffer(2, h1_200SMA);
    SetIndexLabel(2, "H1 200SMA");
    
    //--- M1 5EMA
    SetIndexStyle(3, DRAW_LINE, EMPTY, 1);
    SetIndexBuffer(3, m1_5EMA);
    SetIndexLabel(3, "M1 5EMA");
    
    //--- M1 34EMA
    SetIndexStyle(4, DRAW_LINE, EMPTY, 1);
    SetIndexBuffer(4, m1_34EMA);
    SetIndexLabel(4, "M1 34EMA");
    
    //--- M1 200SMA
    SetIndexStyle(5, DRAW_LINE, EMPTY, 1);
    SetIndexBuffer(5, m1_200SMA);
    SetIndexLabel(5, "M1 200SMA");
    
    // up signals
    SetIndexStyle(6, DRAW_ARROW, 3, 5);
    SetIndexArrow(6, 241);
    SetIndexBuffer(6, upArrows);
    SetIndexLabel(6, "BUY SIGNAL");
    
    SetIndexEmptyValue(6, 0.0);
    
    //down signals
    SetIndexStyle(7, DRAW_ARROW, 3, 5);
    SetIndexArrow(7, 242);
    SetIndexBuffer(7, downArrows);
    SetIndexLabel(7, "SELL SIGNAL");
    
    SetIndexEmptyValue(7, 0.0);
    
    //--- initialization done
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| MTF MAs                                                          |
//+------------------------------------------------------------------+
int start() {
    //---
    //if(rates_total<=InpBandsPeriod || InpBandsPeriod<=0)
    //  return(0);
    
    //--- counting from 0 to rates_total
    //ArraySetAsSeries(h1_5EMA, false);
    //ArraySetAsSeries(h1_34EMA, false);
    //ArraySetAsSeries(h1_200SMA, false);
    //ArraySetAsSeries(m1_5EMA, false);
    //ArraySetAsSeries(m1_34EMA, false);
    //ArraySetAsSeries(m1_200SMA, false);
    
    int    i,shift, counted_bars=IndicatorCounted(),limit;
          
    limit = Bars-counted_bars;
    if(counted_bars == 0)
        limit--;
   
    for(shift=limit;shift>=0 && !IsStopped();shift--) {
        double _h1_ema5 = iMA(NULL, PERIOD_H1, 5, 0, MODE_EMA, PRICE_CLOSE, NormalizeDouble(shift/60, 0));
        double _h1_ema34 = iMA(NULL, PERIOD_H1, 34, 0, MODE_EMA, PRICE_CLOSE, NormalizeDouble(shift/60, 0));
        double _h1_sma200 = iMA(NULL, PERIOD_H1, 200, 0, MODE_SMA, PRICE_CLOSE, NormalizeDouble(shift/60, 0));
        //double _h1_ema5 = iMA(NULL, PERIOD_M1, 300, 0, MODE_EMA, PRICE_CLOSE, shift);
        //double _h1_ema34 = iMA(NULL, PERIOD_M1, 2040, 0, MODE_EMA, PRICE_CLOSE, shift);
        //double _h1_sma200 = iMA(NULL, PERIOD_M1, 12000, 0, MODE_SMA, PRICE_CLOSE, shift);
        
        double _m1_ema5 = iMA(NULL, PERIOD_M1, 5, 0, MODE_EMA, PRICE_CLOSE, shift);
        double _m1_ema34 = iMA(NULL, PERIOD_M1, 34, 0, MODE_EMA, PRICE_CLOSE, shift);
        double _m1_sma200 = iMA(NULL, PERIOD_M1, 200, 0, MODE_SMA, PRICE_CLOSE, shift);
        
        h1_5EMA[shift] = _h1_ema5;
        h1_34EMA[shift] = _h1_ema34;
        h1_200SMA[shift] = _h1_sma200;
        
        m1_5EMA[shift] = _m1_ema5;
        m1_34EMA[shift] = _m1_ema34;
        m1_200SMA[shift] = _m1_sma200;
        
        //draw buy or sell signal if applies
        upArrows[shift] = 0.0;
        downArrows[shift] = 0.0;
        if(_m1_ema5 < _m1_ema34) {
            if(priceSide == UP && _m1_ema5 > _h1_ema5)
                downArrows[shift] = iOpen(NULL, PERIOD_M1, shift);
        
            priceSide = DOWN;    
        }
        else if(_m1_ema5 > _m1_ema34) {
            if(priceSide == DOWN && _m1_ema5 < _h1_ema5)
                upArrows[shift] = iOpen(NULL, PERIOD_M1, shift);
            
            priceSide = UP;
        }
    }
   
    return(0);
}
