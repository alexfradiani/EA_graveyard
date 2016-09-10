//+------------------------------------------------------------------+
//|                                                Intraday5min.mq4  |
//|                                               Alexander Fradiani |
//+------------------------------------------------------------------+
#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

extern string clientDesc = "Intraday 5 min (ForexFactory Golfer rules)";

extern double R_VOL = 0.1;  //Risk Volume. volume of trades
extern double S_L = 0.00016;  //pips STOP LOSS threshold
extern double T_P = 15;  //Take profits (in pips)
extern double SMA_ANGLE = 30; //50 SMA ANgle in degrees

datetime lastTime;

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
	return;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    if(lastTime != Time[0]) {
        lastTime = Time[0];
        
        //50 SMA with the right angle
        double curr50SMA = iCustom(NULL, 0, "SMAAngle", 50, 0.15, 2, 0);
        double degrees = curr50SMA*57.2957795;
        Print("50sMA angle ", degrees);
    }
    
    RefreshRates();
	
	return;
}

//+------------------------------------------------------------------+

/**
 *
 */
