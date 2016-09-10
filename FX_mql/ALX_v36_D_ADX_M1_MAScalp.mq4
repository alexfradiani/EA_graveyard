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
    double target;
    int op_type;
    double size;
};
order_t buyOrder;
order_t sellOrder;

datetime lastBarTime;
int trendState = 0;
int shortState;

int trend3;
int trend9;
int trend27;
int trend81;

bool swEnabled = TRUE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    lastBarTime = Time[0];
    
    shortState = DOWN;
    
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
    
    double ma3 = iMA(NULL, PERIOD_M1, 3, 0, MODE_SMA, PRICE_OPEN, 0);
    double ma9 = iMA(NULL, PERIOD_M1, 9, 0, MODE_SMA, PRICE_OPEN, 0);
    double ma27 = iMA(NULL, PERIOD_M1, 27, 0, MODE_SMA, PRICE_OPEN, 0);
    double ma81 = iMA(NULL, PERIOD_M1, 81, 0, MODE_SMA, PRICE_OPEN, 0);
    
    double ma3Old = iMA(NULL, PERIOD_M1, 3, 0, MODE_SMA, PRICE_OPEN, 1);
    double ma9Old = iMA(NULL, PERIOD_M1, 9, 0, MODE_SMA, PRICE_OPEN, 1);
    double ma27Old = iMA(NULL, PERIOD_M1, 27, 0, MODE_SMA, PRICE_OPEN, 1);
    double ma81Old = iMA(NULL, PERIOD_M1, 81, 0, MODE_SMA, PRICE_OPEN, 1);
    
    if(ma3 >= ma3Old)
        trend3 = UP;
    else
        trend3 = DOWN;
    
    if(ma9 >= ma9Old)
        trend9 = UP;
    else
        trend9 = DOWN;
    
    if(ma27 >= ma27Old)
        trend27 = UP;
    else
        trend27 = DOWN;
        
    if(ma81 >= ma81Old)
        trend81 = UP;
    else
        trend81 = DOWN;
        
    if(trendState == UP) {
        if(trend81 == UP)
            if(ma3 > ma9)
                if(ma3 - ma3Old >= 5*Point && ma9 - ma9Old >= 5*Point)
                    if(buyOrder.ticket == -1 && swEnabled == TRUE) {
                        createBuy();
                        swEnabled = FALSE;
                    }
        
        if(ma3 < ma9)
            swEnabled = TRUE;
    }
    else if(trendState == DOWN) {
        if(ma3 <= ma9 && shortState == UP) {
            shortState = DOWN;
            
            if(trend3 == DOWN && trend9 == DOWN && trend27 == DOWN && trend81 == DOWN)
                if(sellOrder.ticket == -1)
                    createSell();
        }
        
        if(ma3 > ma9 && shortState == DOWN)
            shortState = UP;
    }
    
    //------------------------------------------------------------------------- EXIT rules
    if(buyOrder.ticket != -1) {
        if(Bid < buyOrder.sl)
            closeBuy();
        if(Bid - buyOrder.price > buyOrder.target)
            closeBuy();
    }
    
    if(sellOrder.ticket != -1) {
        if(Ask > sellOrder.sl)
            closeSell();
        else if(sellOrder.price - Ask > sellOrder.target) {
            double times = floor( (sellOrder.price - Ask)/(sellOrder.target) );
            sellOrder.sl = sellOrder.price - times*sellOrder.target;
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
void createBuy() {
    int optype = OP_BUY;
    double oprice = MarketInfo(Symbol(), MODE_ASK);
	
	double atr = iATR(NULL, PERIOD_M1, 14, 0);
	double stoploss = oprice - atr;
    double target = atr + MarketInfo(Symbol(), MODE_SPREAD)*Point;

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
    buyOrder.target = target;
    buyOrder.ticket = order;
    buyOrder.size = osize;
}

/**
 * Create a sell order
 */
void createSell() {
    int optype = OP_SELL;
    double oprice = MarketInfo(Symbol(), MODE_BID);
	
	double atr = iATR(NULL, PERIOD_M1, 14, 0);
	double stoploss = oprice + atr;
    double target = atr - MarketInfo(Symbol(), MODE_SPREAD)*Point;
	
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
    sellOrder.target = target;
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