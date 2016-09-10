//+------------------------------------------------------------------+
//|                                            ALX_v69_S-D-Trend.mq4 |
//+------------------------------------------------------------------+

/**
 * Simple trending strategy
 * relies on higher probability with low r:r
 * ATR for pips targets
 */

#property copyright "ALEXANDER FRADIANI"
#property version   "1.00"
#property strict

#define UP 1
#define DOWN -1
#define NONE 0

#define SLIPPAGE 18

datetime lastBar;

struct order_t {     //DATA for orders
    int ticket;      
    double price;
    double sl;
    double tp;
    int op_type;
    double size;
    string symbol;
};

order_t buyOrder, sellOrder;

int shortMASide;  //short-term moving average
int longMASide;   //long-term moving average
int currentDay;   //day of current trade

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
    lastBar = NULL;
    currentDay = NULL;
    
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
//---
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
    lastBar = NULL;
    currentDay = NULL;
    
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
//---
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
//---
    int t = TimeDay(TimeCurrent());
    //--------------------------------------------------------------------------------------------TRADING CONDITIONS
    if(currentDay != t) {  //new trading day
        //only trade from tuesday to thursday
        if(isTradingDay()) {
            //determine trend direction
            double longma_0 = iMA(Symbol(), PERIOD_D1, 30, 0, MODE_SMA, PRICE_MEDIAN, 1);
            double longma_1 = iMA(Symbol(), PERIOD_D1, 30, 0, MODE_SMA, PRICE_MEDIAN, 2);
            
            double shortma_0 = iMA(Symbol(), PERIOD_D1, 5, 0, MODE_SMA, PRICE_MEDIAN, 1);
            double shortma_1 = iMA(Symbol(), PERIOD_D1, 5, 0, MODE_SMA, PRICE_MEDIAN, 2);
            
            if(longma_0 > longma_1)
                longMASide = UP;
            else if(longma_0 < longma_1)
                longMASide = DOWN;
            else
                longMASide = NONE;
                
            if(shortma_0 > shortma_1)
                shortMASide = UP;
            else if(shortma_0 < shortma_1)
                shortMASide = DOWN;
            else
                shortMASide = NONE;
                
            if(shortMASide == UP) {
                double strength = 0.5;
                if(longMASide == UP)
                    strength = 1.0;
                
                if(buyOrder.ticket == -1) {
                    double size = calculateSize(strength);
                    createBuy(size);
                }
            }
            else if(shortMASide == DOWN) {
                double strength = 0.5;
                if(longMASide == DOWN)
                    strength = 1.0;
                
                if(sellOrder.ticket == -1) {
                    double size = calculateSize(strength);
                    createSell(size);
                }
            }
        }
        
        currentDay = t;
    }
    
    //--------------------------------------------------------------------------------------------PROFIT / LOSS MGMT
    //price values
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);
    
    if(buyOrder.ticket != -1) {
        if(bid >= buyOrder.tp)
            closeBuy();
        else if(bid <= buyOrder.sl)
            closeBuy();
    }
    
    if(sellOrder.ticket != -1) {
        if(ask <= sellOrder.tp)
            closeSell();
        else if(ask >= sellOrder.sl)
            closeSell();
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+

/**
 * Mondays and Fridays excluded from trading.
 * statistically these days are usually consolidation, no strong trend direction.
 */
bool isTradingDay() {
    datetime t = TimeCurrent();
    
    int wday = TimeDayOfWeek(t);
    if(wday >= 2 && wday <= 4)  //tuesday to thursday
        return TRUE;
    else
        return FALSE;
}

/** 
 * calculate size of order based on account state
 */
double calculateSize(double strength) {
    double size = 0.0;
    
    double point = MarketInfo(Symbol(), MODE_POINT); 
    double balance = AccountBalance();
    double risk = balance * 0.05;  //only risk 5%
    double atrPips = iATR(Symbol(), PERIOD_D1, 30, 1) / point; //Stop Loss pips
    size = strength * risk / atrPips;
    
    return NormalizeDouble(size, 2);
}

/**
 * send buy order
 */
void createBuy(double size) {
    string symbol = Symbol();
    int optype = OP_BUY;
    double oprice = MarketInfo(symbol, MODE_ASK);
    
    double atr = iATR(Symbol(), PERIOD_D1, 30, 1);
    double sl = oprice - atr;
	double tp = oprice + atr * 0.5;
	
	int order = OrderSend(
        symbol, //symbol
        optype, //operation
        size, //volume
        oprice, //price
        SLIPPAGE, //slippage
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(order > 0) {
        buyOrder.ticket = order;
        buyOrder.op_type = optype;
        buyOrder.price = oprice;
        buyOrder.size = size;
        buyOrder.sl = sl;
        buyOrder.tp = tp;
        buyOrder.symbol = symbol;
    }
}

/**
 * send sell order
 */
void createSell(double size) {
    string symbol = Symbol();
    int optype = OP_SELL;
    double oprice = MarketInfo(symbol, MODE_BID);
    
    double atr = iATR(Symbol(), PERIOD_D1, 30, 1);
    double sl = oprice + atr;
	double tp = oprice - atr * 0.5;
	
	int order = OrderSend(
        symbol, //symbol
        optype, //operation
        size, //volume
        oprice, //price
        SLIPPAGE, //slippage
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(order > 0) {
        sellOrder.ticket = order;
        sellOrder.op_type = optype;
        sellOrder.price = oprice;
        sellOrder.size = size;
        sellOrder.sl = sl;
        sellOrder.tp = tp;
        sellOrder.symbol = symbol;
    }
}

/**
 * close a buy
 */
void closeBuy() {
    double bid = MarketInfo(Symbol(), MODE_BID);
    bool close = OrderClose(buyOrder.ticket, buyOrder.size, bid, SLIPPAGE);
    if(close)
        buyOrder.ticket = -1;
}

/**
 * close a sell
 */
void closeSell() {
    double ask = MarketInfo(Symbol(), MODE_ASK);
    bool close = OrderClose(sellOrder.ticket, sellOrder.size, ask, SLIPPAGE);
    if(close)
        sellOrder.ticket = -1;
}