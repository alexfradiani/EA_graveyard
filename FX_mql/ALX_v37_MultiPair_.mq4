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

#define ALL_SYMBOLS_N 7
string allSymbols[ALL_SYMBOLS_N];

struct _symbSorter {
    double adxDiff;
    string symbol;
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    allSymbols[0]  = "AUDUSD";  allSymbols[1]  = "USDCAD";  allSymbols[2]  = "USDCHF";  allSymbols[3]  = "EURUSD";
    allSymbols[4]  = "GBPUSD";  allSymbols[5]  = "USDJPY";  allSymbols[6]  = "NZDUSD";
    
    lastBarTime = Time[0];
    
    setSymbols();
    
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
    
    RefreshRates();
}
//+------------------------------------------------------------------+ 

void setSymbols() {
    _symbSorter tosort[ALL_SYMBOLS_N];
    for(int i = 0; i < ALL_SYMBOLS_N; i++) {
        double adx = iADX(allSymbols[i], 0, 15, PRICE_MEDIAN, MODE_MAIN, 10);
        double adxOld = iADX(allSymbols[i], 0, 15, PRICE_MEDIAN, MODE_MAIN, 11);
        double adxDiff = adx;
        
        tosort[i].adxDiff = adxDiff;
        tosort[i].symbol = allSymbols[i];
        Print(tosort[i].symbol, " adxDiff:", tosort[i].adxDiff);
    }
    
    //order in descending mode
    for(int i = 0; i < ALL_SYMBOLS_N; i++)
        for(int j = i; j < ALL_SYMBOLS_N; j++)
            if(tosort[j].adxDiff > tosort[i].adxDiff) {
                _symbSorter temp;
                temp.adxDiff = tosort[i].adxDiff;
                temp.symbol = tosort[i].symbol;
                
                tosort[i].adxDiff = tosort[j].adxDiff;
                tosort[i].symbol = tosort[j].symbol;
                
                tosort[j].adxDiff = temp.adxDiff;
                tosort[j].symbol = temp.symbol;
            }
    
    Print("tracked symbols in order: ");
    for(int i = 0; i < ALL_SYMBOLS_N; i++)
        Print(tosort[i].symbol, " adxDiff:", tosort[i].adxDiff);
}

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