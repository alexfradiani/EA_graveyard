//+------------------------------------------------------------------+
//|                                                       tester.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

datetime lastTime;
int order = -1;

int timePivot = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
    lastTime = Time[0];
//---
    return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    /*string pair = Symbol();
    double m5_st, m15_st, m30_st;
    if(Time[0] != lastTime) {
        timePivot++;
        
        m5_st = iStochastic(pair, PERIOD_M5, 14, 1, 1, MODE_SMA, 0, MODE_MAIN, 1);
 
        if(timePivot >= 6) {
            m30_st = iStochastic(pair, PERIOD_M30, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
            Print("new M30: ", m30_st);
            
            m15_st = iStochastic(pair, PERIOD_M15, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
            Print("new M15: ", m15_st);
            
            timePivot = 0;
        }
        else if(timePivot == 3) {
            m15_st = iStochastic(pair, PERIOD_M15, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
            Print("new M15: ", m15_st);
        }
        
        lastTime = Time[0];
    }*/
    
    string symbols[7];
    symbols[0] = "EURUSD";
    symbols[1] = "USDJPY";
    symbols[2] = "AUDUSD";
    symbols[3] = "GBPUSD";
    symbols[4] = "USDCHF";
    symbols[5] = "EURCHF";
    symbols[6] = "USDCAD";
    
    if(Time[0] != lastTime) {
        for(int i = 0; i < ArraySize(symbols); i++) {
            if(crossing(symbols[i]))
                Alert("CRUCE: ", symbols[i], ". momento: ", Time[0]);
        }
        lastTime = Time[0];
    }
    
    
    /*if(Time[0] != lastTime) {
        if(order != -1) {
            if(OrdersTotal() == 0)
                order = -1;
        }
        else {
            double stoploss = Bid - 30*Point;
            double takeprofit = Ask + 15*Point;
            
            order = OrderSend(
        		Symbol(), //symbol
        		OP_BUY, //operation
        		0.1, //volume
        		Ask, //price
        		3, //slippage???
        		NormalizeDouble(stoploss, Digits), //Stop loss
        		NormalizeDouble(takeprofit, Digits) //Take profit
        	);
        }      
    }*/
}
//+------------------------------------------------------------------+

bool crossing(string symbol) {
    //cruces de 4, 18, 40 exponencial
    double ema4 = iMA(symbol, 0, 4, 0, MODE_EMA, PRICE_CLOSE, 0);
    double ema18 = iMA(symbol, 0, 18, 0, MODE_EMA, PRICE_CLOSE, 0);
    double ema40 = iMA(symbol, 0, 40, 0, MODE_EMA, PRICE_CLOSE, 0);
    
    if(MathAbs(ema4 - ema18) <= 2*Point)
        if(MathAbs(ema18 - ema40) <= 2*Point)
            return TRUE;
            
    return FALSE;
}