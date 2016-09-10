//+------------------------------------------------------------------+
//|                                             ALX_v62_TRFusion.mq4 |
//|                               Copyright 2015, Alexander Fradiani |
//|                                         https://www.fradiani.com |
//+------------------------------------------------------------------+

/**
 * Fusion of trending and range strategy
 *
 * bollinger triggers ranging-like trades
 * crossing of MA's triggers trending-like trades
 *
 * Expected profits from either one according to market.
 */

#property copyright "Copyright 2015, Alexander Fradiani"
#property link      "https://www.fradiani.com"
#property version   "1.00"
#property strict

//Money Management
#define MAX_LOSS 1000

//Trade constants
#define INIT_SIZE 0.1
#define SLIPPAGE 5

#define UP 1
#define DOWN -1
#define NONE 0

//Order structure
struct order_t {     
    int ticket;
    double price;
    int op_type;
    double size;
    string symbol;
    double sl;
    double tp;
};
order_t bollOrder, maOrder;
order_t orders[50];

//strategy variables
int bollSide, maSide;
datetime lastBar;

int currentIndex = 0;
double dayAccum = 0;
int currentDay;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    bollOrder.ticket = -1;
    maOrder.ticket = -1;
    
    lastBar = Time[0];
    
    //initialize sides
    bollSide = NONE;
    double ma60 = iMA(Symbol(), PERIOD_M1, 60, 0, MODE_EMA, PRICE_CLOSE, 0);
    double ma240 = iMA(Symbol(), PERIOD_M1, 240, 0, MODE_EMA, PRICE_CLOSE, 0);
    
    if(ma60 > ma240) 
        maSide = UP;
    
    if(ma60 < ma240)
        maSide = DOWN;
    
    datetime currentTime = TimeCurrent();
    currentDay = TimeDay(currentTime);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    bollOrder.ticket = -1;
    maOrder.ticket = -1;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    //--------------------------------------------------------------------------------------------- TIME metric and trade rules
    datetime currentTime = TimeCurrent();
    int h = TimeHour(currentTime);
    
    //price values
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    double upBand = iBands(Symbol(), PERIOD_M5, 48, 2, 0, PRICE_CLOSE, MODE_UPPER, 0);
    double middleBand = iBands(Symbol(), PERIOD_M5, 48, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    double middleBandOld = iBands(Symbol(), PERIOD_M5, 48, 2, 0, PRICE_CLOSE, MODE_MAIN, 1);
    double downBand = iBands(Symbol(), PERIOD_M5, 48, 2, 0, PRICE_CLOSE, MODE_LOWER, 0);
    
    double ma60 = iMA(Symbol(), PERIOD_M1, 60, 0, MODE_EMA, PRICE_CLOSE, 1);
    double ma240 = iMA(Symbol(), PERIOD_M1, 240, 0, MODE_EMA, PRICE_CLOSE, 1);
    
    if(Time[0] != lastBar) {  //determine side
        if(
            isTradingDay() == TRUE &&
            ( (currentIndex == 0 && (h >= 7 && h <= 22)) || currentIndex > 0 )
        ) {
            if(ma60 > ma240) {
                if(maSide == DOWN)
                    if(currentIndex < 50 && (currentIndex == 0 || (currentIndex > 0 && orders[currentIndex - 1].op_type==OP_SELL))) {
                        //try to close older buys in profit
                        for(int i = 0; i < currentIndex; i++) {
                            if(orders[i].op_type == OP_BUY) {
                                if(bid - orders[i].price >= 0)
                                    closeBuy(i);
                            }
                        }
                        
                        createBuy(INIT_SIZE);
                    }
                maSide = UP;
            }
            
            if(ma60 < ma240) {
                if(maSide == UP)
                    if(currentIndex < 50 && (currentIndex == 0 || (currentIndex > 0 && orders[currentIndex - 1].op_type==OP_BUY))) {
                        //try to close older sells in profit
                        for(int i = 0; i < currentIndex; i++) {
                            if(orders[i].op_type == OP_SELL) {
                                if(orders[i].price - ask >= 0)
                                    closeSell(i);
                            }
                        }
                        
                        createSell(INIT_SIZE);
                    }
                maSide = DOWN;
            }
        }
        
        Comment("price side: ",maSide, " AccEquity: ", AccountEquity());
        lastBar = Time[0];
    } 
    
    //---------------------------------------------------------------------------------------------PROFIT AND LOSSES
    for(int i = 0; i < currentIndex; i++) {
        if(orders[i].op_type == OP_BUY) {
            if(bid - orders[i].price <= -1*100*point)
                closeBuy(i);
        }
        else {
            if(orders[i].price - ask <= -1*100*point)
                closeSell(i);
        }
    }
    
    double currAccum = 0;
    for(int i = 0; i < currentIndex; i++) {
        if(orders[i].op_type == OP_BUY)
            currAccum += bid - orders[i].price;
        else
            currAccum += orders[i].price - ask;
    }
    if(currAccum + dayAccum >= 50 * point) {
        closeAllOrders();
        dayAccum = 0;
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+

/**
 * Fridays excluded from trading.
 */
bool isTradingDay() {
    datetime t = TimeCurrent();
    
    int wday = TimeDayOfWeek(t);
    if(wday >= 1 && wday <= 4)  //Monday to thursday
        return TRUE;
    else
        return FALSE;
}

/********************************************** CLOSE Functions ************************************************************/

bool closeBuy(int index) {
    string symbol = Symbol();
    double bid = MarketInfo(symbol, MODE_BID);
    bool closed = OrderClose(orders[index].ticket, orders[index].size, bid, SLIPPAGE, clrNONE);
    if(closed) {
        orders[index].ticket = -1;
        
        dayAccum += bid - orders[index].price;
        
        for(int i = index; i < currentIndex; i++) {
            orders[i].ticket = orders[i+1].ticket;
            orders[i].op_type = orders[i+1].op_type;
            orders[i].price = orders[i+1].price;
        }
        
        currentIndex--;
    }
    
    return closed;
}

bool closeSell(int index) {
    string symbol = Symbol();
    double ask = MarketInfo(symbol, MODE_ASK);
    bool closed = OrderClose(orders[index].ticket, orders[index].size, ask, SLIPPAGE, clrNONE);
    if(closed) {
        orders[index].ticket = -1;
        
        dayAccum += orders[index].price - ask;
        
        for(int i = index; i < currentIndex; i++) {
            orders[i].ticket = orders[i+1].ticket;
            orders[i].op_type = orders[i+1].op_type;
            orders[i].price = orders[i+1].price;
        }
        
        currentIndex--;
    }
    
    return closed;
}

void closeAllOrders() {
    while(currentIndex > 0) {
        if(orders[0].op_type == OP_BUY)
            closeBuy(0);
        else
            closeSell(0);
    }
}

/********************************************** CREATE Functions *************************************************************/

void createBuy(double osize) {
    string symbol = Symbol();
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    int optype = OP_BUY;
    double oprice = MarketInfo(symbol, MODE_ASK);

	int ticket = OrderSend(
        symbol, //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        SLIPPAGE, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(ticket > 0) {
        orders[currentIndex].ticket = ticket;
        orders[currentIndex].op_type = optype;
        orders[currentIndex].price = oprice;
        orders[currentIndex].size = osize;
        orders[currentIndex].symbol = symbol;
        
        currentIndex++;
    }
}

void createSell(double osize) {
    string symbol = Symbol();
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    int optype = OP_SELL;
    double oprice = MarketInfo(symbol, MODE_BID);

	int ticket = OrderSend(
        symbol, //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        SLIPPAGE, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(ticket > 0) {
        orders[currentIndex].ticket = ticket;
        orders[currentIndex].op_type = optype;
        orders[currentIndex].price = oprice;
        orders[currentIndex].size = osize;
        orders[currentIndex].symbol = symbol;
        
        currentIndex++;
    }
}
