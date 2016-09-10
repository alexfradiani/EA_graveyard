//+------------------------------------------------------------------+
//|                                  ALX_v34_D_ADX_M1_maFilter.mq4   |
//|                                             Alexander Fradiani   |
//+------------------------------------------------------------------+

/**
 * THIS STRATEGY CONSISTS OF:
 *    - D1 ADX telling direction of global trend
 *    - M15 RSI triggers daily for orders
 *    - TP is RSI in opposite extreme when coming back from higher top
 *    - SL is 2*ATR, filter trades when is bigger that 100 pips.
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define BAND_TRIGGER 35
#define LOW_BAND_TRIGGER 10

#define UP 1
#define DOWN -1
#define NONE 0

#define BASE_PIPS 50

#define RSI_BOTTOM 30
#define RSI_TOP 70

#define MAX_ATR_RISK 100

extern double R_VOL = 0.1;  //Risk Volume. base volume of trades

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

datetime lastBarTime;
int trendState = 0;
int rsiState = 0;

bool swCollect = FALSE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    lastBarTime = Time[0];
    
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
    //ADX D1 global trend
    double adx = iADX(NULL, PERIOD_D1, 14, PRICE_CLOSE, MODE_MAIN, 0);
    double adxMinus = iADX(NULL, PERIOD_D1, 14, PRICE_CLOSE, MODE_MINUSDI, 0);
    double adxPlus = iADX(NULL, PERIOD_D1, 14, PRICE_CLOSE, MODE_PLUSDI, 0);
    
    if(adxPlus > adxMinus)
        trendState = UP;
    else if(adxPlus < adxMinus)
        trendState = DOWN;
    else
        trendState = NONE;
    
    //M15 RSI for triggering
    int oldRSIState = rsiState;
    if(Time[0] != lastBarTime) {
        double rsi = iRSI(NULL, PERIOD_M15, 8, PRICE_CLOSE, 1);
        
        if(rsi <= RSI_BOTTOM && rsiState >= NONE) {
            rsiState = DOWN;
        }
        
        if(rsi >= RSI_BOTTOM && rsiState == DOWN) {  //possible BUY trigger
            if(trendState == UP && adx >= 30) {
                double atr = iATR(NULL, PERIOD_M15, 14, 1);
                if(atr <= MAX_ATR_RISK*Point) {
                    if(buyOrder.ticket == -1)
                        createBuy(atr);
                }
            }
            
            rsiState = NONE;
        }
        
        if(rsi >= RSI_TOP && rsiState <= NONE) {
            rsiState = UP;
        }
        
        if(rsi <= RSI_TOP && rsiState == UP) {  //possible SELL trigger
            if(trendState == DOWN && adx >= 30) {
                double atr = iATR(NULL, PERIOD_M15, 14, 1);
                if(atr <= MAX_ATR_RISK*Point) {
                    if(sellOrder.ticket == -1)
                        createSell(atr);
                }
            }
            
            rsiState = NONE;
        }
        
        lastBarTime = Time[0];  
    }
    
    //------------------------------------------------------------------------- EXIT rules
    if(buyOrder.ticket != -1) {
        if(trendState == DOWN) {
            closeBuy();
            swCollect = FALSE;
        }
        else {
            if(rsiState == UP && Bid - buyOrder.price > 0)
                swCollect = TRUE;
            
            if(swCollect == TRUE) {
                double instantRSI = iRSI(NULL, PERIOD_M15, 8, PRICE_CLOSE, 0);
                if(instantRSI < RSI_TOP) {
                    closeBuy();
                    swCollect = FALSE;
                }
            }
        }
    }
    
    if(sellOrder.ticket != -1) {
        if(trendState == UP) {
            closeSell();
            swCollect = FALSE;
        }
        else {
            if(rsiState == DOWN && sellOrder.price - Ask > 0)
                swCollect = TRUE;
            
            if(swCollect == TRUE) {
                double instantRSI = iRSI(NULL, PERIOD_M15, 8, PRICE_CLOSE, 0);
                if(instantRSI > RSI_BOTTOM) {
                    closeSell();
                    swCollect = FALSE;
                }
            }
        }
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+ 

/**
 * Moving Average Filter
 */
int maFilter() {
    double ma = iMA(NULL, PERIOD_M1, 81, 0, MODE_SMA, PRICE_CLOSE, 0);
    double maOld = iMA(NULL, PERIOD_M1, 81, 0, MODE_SMA, PRICE_CLOSE, 1);
    
    if(ma > maOld)
        return UP;
    else if(ma < maOld)
        return DOWN;
    else
        return NONE;
} 

/**
 * Create a buy order
 */
void createBuy(double atr) {
    int optype = OP_BUY;
    double oprice = MarketInfo(Symbol(), MODE_ASK);
	double stoploss = oprice - 3*atr + MarketInfo(Symbol(), MODE_SPREAD)*Point;

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
void createSell(double atr) {
    int optype = OP_SELL;
    double oprice = MarketInfo(Symbol(), MODE_BID);
	double stoploss = oprice + 3*atr - MarketInfo(Symbol(), MODE_SPREAD)*Point;
	
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