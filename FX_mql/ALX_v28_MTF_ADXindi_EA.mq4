//+------------------------------------------------------------------+
//|                                 ALX_v28_MTF_ADXindi_EA.mq4.mq4   |
//|                                             Alexander Fradiani   |
//+------------------------------------------------------------------+

/**
 * configuration for trend market state
 * RULES:
 *    - execute and stop orders according to custom mtf adx indicator.
 * EXIT:
 *    - stop signal from indicator.
 *    - risk STOP LOSS is touched.
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define SIGNAL_STRONGUP 2.0
#define SIGNAL_STRONGDOWN -2.0 
#define SIGNAL_WEAKUP 1.0
#define SIGNAL_WEAKDOWN -1.0 
#define SIGNAL_STOP -99.9

#define DI_MIN_DISTANCE 3.0

#define UP 1
#define DOWN -1
#define NONE 0

#define BASE_PIPS 500

extern double R_VOL = 0.1;  //Risk Volume. base volume of trades

double currentSignal = SIGNAL_STOP;
int trendState = 0;

struct order_t {     //DATA for orders
    int ticket;      
    double price;
    double sl;
    double tp;
    int op_type;
    double size;
};
order_t buyOrder;
order_t sellOrder;

datetime lastTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    lastTime = Time[0];
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) { /*...*/ }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() { 
    //------------------------------------------------------------------------- TRADE rules
    //double alxadx = iCustom(NULL, 0, "ALX_mtf_adx", 4, 0);
    
    if(Minute() == 1 || Minute() == 16 || Minute() == 31 || Minute() == 46) {
        double alxadx = renderAdxIndi();
    }
    
    /*if(alxadx == SIGNAL_STRONGUP || alxadx == SIGNAL_WEAKUP) {
        Print("buy signal at ", Time[0]);
    }
    
    if(alxadx == SIGNAL_STRONGDOWN || alxadx == SIGNAL_WEAKDOWN) {
        Print("sell signal at ", Time[0]);
    }
    
    if(alxadx == SIGNAL_STOP) {
        Print("stop signal at ", Time[0]);
    }*/
    
    //------------------------------------------------------------------------- EXIT rules
    /*if(buyOrder.ticket != -1) {
        if(Bid <= buyOrder.sl) {
            closeBuy();
        }
        
        if(newBar == TRUE) {
             if(ema9_1 >= ema81_1 && ema9_0 < ema81_0)
                closeBuy();
        }    
    }
    if(sellOrder.ticket != -1) {
        if(Ask >= sellOrder.sl) {
            closeSell();
        }
        
        if(newBar == TRUE) {
             if(ema9_1 <= ema81_1 && ema9_0 > ema81_0)
                closeSell();
        }
    }*/
    
    RefreshRates();
}
//+------------------------------------------------------------------+ 
 
double renderAdxIndi() {
    //set offset position to align m15 and h1 bars
    /*int hourShift = 0;
    int fifteenShift = 0;
    while(Time[i] < iTime(NULL, PERIOD_H1 , hourShift))
        hourShift++;
    while(Time[i] < iTime(NULL, PERIOD_M15 , fifteenShift))
        fifteenShift++;*/
    
    double adxHour_main = iADX(NULL, PERIOD_H1, 14, PRICE_CLOSE, MODE_MAIN, 0);
    double adxfifteen_minusDi = iADX(NULL, PERIOD_M15, 54, PRICE_CLOSE, MODE_MINUSDI, 1);
    double adxfifteen_plusDi = iADX(NULL, PERIOD_M15, 54, PRICE_CLOSE, MODE_PLUSDI, 1);
    
    Print("minus: ", adxfifteen_minusDi, " plus: ", adxfifteen_plusDi);
    
    /*if(adxHour_main > 25) {
        if(MathAbs(adxfifteen_plusDi - adxfifteen_minusDi) < DI_MIN_DISTANCE && trendState != NONE) {
            trendState = NONE;
            return SIGNAL_STOP;
        }
        else if(MathAbs(adxfifteen_plusDi - adxfifteen_minusDi) >= DI_MIN_DISTANCE && trendState == NONE) {
            if(adxfifteen_plusDi > adxfifteen_minusDi) {
                trendState = UP;
                return SIGNAL_STRONGUP;
            }
            else {
                trendState = DOWN;
                return SIGNAL_STRONGDOWN;
            }
        }
    }
    else {
        if(MathAbs(adxfifteen_plusDi - adxfifteen_minusDi) < DI_MIN_DISTANCE && trendState != NONE) {
            trendState = NONE;
            return SIGNAL_STOP;
        }
        else if(MathAbs(adxfifteen_plusDi - adxfifteen_minusDi) >= DI_MIN_DISTANCE && trendState == NONE) {
            if(adxfifteen_plusDi > adxfifteen_minusDi) {
                trendState = UP;
                return SIGNAL_WEAKUP;
            }
            else {
                trendState = DOWN;
                return SIGNAL_WEAKDOWN;
            }
            
        }
    }*/
    
    return currentSignal;
}
 
/**
 * Create a buy order
 */
void createBuy() {
    int optype = OP_BUY;
    double oprice = MarketInfo(Symbol(), MODE_ASK);
	double stoploss = oprice - BASE_PIPS*Point + MarketInfo(Symbol(), MODE_SPREAD)*Point;

	double osize = R_VOL;
	
	int order = OrderSend(
		Symbol(), //symbol
		optype, //operation
		osize, //volume
		oprice, //price
		3, //slippage???
		0,//NormalizeDouble(stoploss, digit), //Stop loss
		0//NormalizeDouble(takeprofit, digit) //Take profit
	);
	
	//save order
    buyOrder.op_type = optype;
    buyOrder.price = oprice;
    buyOrder.sl = stoploss;
    buyOrder.ticket = order;
    buyOrder.size = osize;
}

/**
 * Create a sell order
 */
void createSell() {
    int optype = OP_SELL;
    double oprice = MarketInfo(Symbol(), MODE_BID);
	double stoploss = oprice + BASE_PIPS*Point - MarketInfo(Symbol(), MODE_SPREAD)*Point;
	
	double osize = R_VOL;
	
	int order = OrderSend(
		Symbol(), //symbol
		optype, //operation
		osize, //volume
		oprice, //price
		3, //slippage???
		0,//NormalizeDouble(stoploss, digit), //Stop loss
		0//NormalizeDouble(takeprofit, digit) //Take profit
	);
	
	//save order
    sellOrder.op_type = optype;
    sellOrder.price = oprice;
    sellOrder.sl = stoploss;
    sellOrder.ticket = order;
    sellOrder.size = osize;
}

void closeBuy() {
    bool close = OrderClose(buyOrder.ticket, buyOrder.size, Bid, 3, Blue);
    if(close == TRUE)
        buyOrder.ticket = -1;
}

void closeSell() {
    bool close = OrderClose(sellOrder.ticket, sellOrder.size, Ask, 3, Blue);
    if(close == TRUE)
        sellOrder.ticket = -1;
}