//+------------------------------------------------------------------+
//|                                               ALX_v69_WTrain.mq4 |
//|                          Copyright 2015-2016, Alexander Fradiani |
//|                                          http://www.fradiani.com |
//+------------------------------------------------------------------+

/**
 * WEIGHTED TRAIN
 *
 * play the trending market in the direction of 15 day average.
 * take profits every GRID_Y pips and reduce lot size until trend reversal
 */

#property copyright "Copyright 2015-2016, Alexander Fradiani"
#property link      "http://www.fradiani.com"
#property version   "1.00"
#property strict

//Position constants
#define UP 1
#define NONE 0
#define DOWN -1

//Trade constants
#define MAX_ORDERS 500
#define MAX_STAIRS 100
#define SLIPPAGE 10
#define GRID_Y 100

//Order structure
struct order_t {     
    int ticket;
    string symbol;
    double price;
    int op_type;
    double size;
};
order_t buyOrder, sellOrder;

//strategy variables
datetime lastBar;

int priceSide;
int trainLevel;
double trainStart;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    double ma_0 = iMA(Symbol(), PERIOD_D1, 15, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma_1 = iMA(Symbol(), PERIOD_D1, 15, 0, MODE_SMA, PRICE_CLOSE, 1);
    if(ma_0 < ma_1)
        priceSide = DOWN;
    else
        priceSide = UP;
    
    lastBar = NULL;
    trainLevel = 1;
    
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    lastBar = NULL;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    datetime currentTime = TimeCurrent();
    
    //price values
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);
    double point = MarketInfo(Symbol(), MODE_POINT);
    double spread = MarketInfo(Symbol(), MODE_SPREAD);
        
    //---------------------------------------------------------------------------------------------TRADING RULES
    //double ma_0 = iMA(Symbol(), PERIOD_D1, 15, 0, MODE_SMA, PRICE_CLOSE, 0);
    //double ma_1 = iMA(Symbol(), PERIOD_D1, 15, 0, MODE_SMA, PRICE_CLOSE, 1);
    double adxPlus = iADX(Symbol(), PERIOD_D1, 15, PRICE_MEDIAN, MODE_PLUSDI, 0);
    double adxMinus = iADX(Symbol(), PERIOD_D1, 15, PRICE_MEDIAN, MODE_MINUSDI, 0);
    
    if(lastBar != Time[0]) {
        if(adxPlus < adxMinus) {
            if(priceSide == UP || (lastBar == NULL && emptyTrades())) {
                //draw arrow
                ObjectCreate("arrow"+TimeToString(Time[0]), OBJ_ARROW_DOWN, 0, Time[0], bid);
                
                priceSide = DOWN;
                Print("Price set to DOWN at ", Time[0]);
                
                if(sellOrder.ticket != -1)
                    closeSell();
                
                //trainLevel = 1;
                trainStart = bid;
                createBuy();
            }
        }
        else if(adxPlus > adxMinus) {
            if(priceSide == DOWN || (lastBar == NULL && emptyTrades())) {
                //draw arrow
                ObjectCreate("arrow"+TimeToString(Time[0]), OBJ_ARROW_UP, 0, Time[0], bid);
                
                priceSide = UP;
                Print("Price set to UP at ", Time[0]);
                
                if(buyOrder.ticket != -1)
                    closeBuy();
                
                //trainLevel = 1;
                trainStart = ask;
                createSell();
            }
        }
        
        lastBar = Time[0];
    }
    
    //TAKE PROFITS AND TRAIN LEVELING
    if(buyOrder.ticket != -1) {
        if(bid - buyOrder.price <= -1* GRID_Y * point) {
            closeBuy();
            trainLevel++;
            createBuy();
        }
    }
    
    if(sellOrder.ticket != -1) {
        if(sellOrder.price - ask <= -1* GRID_Y * point) {
            closeSell();
            trainLevel++;
            createSell();
        }
    }
    
    writeComments();
    RefreshRates();
}
//+------------------------------------------------------------------+

bool emptyTrades() {
    if(buyOrder.ticket == -1 && sellOrder.ticket == -1)
        return TRUE;
    else
        return FALSE;
}

/**
 * Comments for log in terminal
 */
void writeComments() {
    //TODO...
    
    /*datetime t = TimeCurrent();
    int wday = TimeDayOfWeek(t);
    string msg = "Week-day: " + IntegerToString(wday) + " \n";
    msg += "AG float: " + DoubleToString(AG_float, 2) + " \n";
    msg += "mapTop: "+IntegerToString(mapTop - (MAX_STAIRS/2 -1))+" mapBottom: "+IntegerToString(mapBottom - (MAX_STAIRS/2 -1))+" \n";
    msg += "pivot: " + IntegerToString(pivot);
    */
    //Comment(msg);
}

/**
 * determine lot size based on train level
 */
double getLotSize() {
    double size = 0.0;
    
    size = trainLevel * 0.01;
                    
    return size;
}

/**
 * CLOSE BUY ORDER
 */
bool closeBuy() {
    string symbol = Symbol();
    double bid = MarketInfo(symbol, MODE_BID);
    double point = MarketInfo(Symbol(), MODE_POINT);

    bool closed = OrderClose(buyOrder.ticket, buyOrder.size, bid, SLIPPAGE, clrNONE);
    if(closed) {  
        buyOrder.ticket = -1;
    }
    
    return TRUE;
}

/**
 * CLOSE SELL ORDER
 */
bool closeSell() {
    string symbol = Symbol();
    double ask = MarketInfo(symbol, MODE_ASK);
    double point = MarketInfo(Symbol(), MODE_POINT);

    bool closed = OrderClose(sellOrder.ticket, sellOrder.size, ask, SLIPPAGE, clrNONE);
    if(closed) {  
        sellOrder.ticket = -1;
    }
    
    return TRUE;
}

/**
 * CREATE a buy
 */
void createBuy() {
    string symbol = Symbol();
    int optype = OP_BUY;
    double oprice = MarketInfo(symbol, MODE_ASK);

    double osize = getLotSize();

	int ticket = OrderSend(
        symbol, //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        SLIPPAGE, //slippage
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(ticket > 0) {
        buyOrder.ticket = ticket;
        buyOrder.op_type = optype;
        buyOrder.price = oprice;
        buyOrder.size = osize;
        buyOrder.symbol = symbol;
    }
}

/**
 * CREATE a SELL 
 */
void createSell() {
    string symbol = Symbol();
    int optype = OP_SELL;
    double oprice = MarketInfo(symbol, MODE_BID);

    double osize = getLotSize();

	int ticket = OrderSend(
        symbol, //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        SLIPPAGE, //slippage
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(ticket > 0) {
        sellOrder.ticket = ticket;
        sellOrder.op_type = optype;
        sellOrder.price = oprice;
        sellOrder.size = osize;
        sellOrder.symbol = symbol;
    }
}