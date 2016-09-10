//+------------------------------------------------------------------+
//|                                                eWaves_reader.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict


datetime lastTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
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
void OnTick()
  {
    if(lastTime != Time[0]) {
        lastTime = Time[0];
        
        Print("Last 10 oscillator: ");
        for(int i = 0; i < 10; i++) {
            double osc = iAO(NULL, 0, i);
            Print("bar ", i, ": ", osc);
        }     
    }
    
    RefreshRates();
	
	return;
  }
//+------------------------------------------------------------------+
