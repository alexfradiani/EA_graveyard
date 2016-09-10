//+------------------------------------------------------------------+
//|                                       ALX_v63_DSession_Mgale.mq4 |
//|                               Copyright 2015, Alexander Fradiani |
//|                                          http://www.fradiani.com |
//+------------------------------------------------------------------+

/**
 * trade the major trend in London Opening from Tues-Thurs
 *
 * martingale with high ratio to increase profits
 * expectancy of doubling capital in monthly basis
 */

#property copyright "Copyright 2015, Alexander Fradiani"
#property link      "http://www.fradiani.com"
#property version   "1.00"
#property strict

//Trade constants
#define SLIPPAGE 50
#define ORDER_SIZE 0.01 

#define UP 1
#define DOWN -1
#define NONE 0

#define NO_OP -99

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
order_t order;

//strategy variables
datetime lastBar;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    order.ticket = -1; 
    lastBar = NULL;
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    order.ticket = -1; 
    lastBar = NULL;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    //--------------------------------------------------------------------------------------------- TIME metric
    datetime t = TimeCurrent();
    
    //price values
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    //Event checking
    int event = checkNewsTrade(TimeYear(t), TimeMonth(t), TimeDay(t), TimeHour(t), TimeMinute(t));
    if(event == OP_BUY && order.ticket == -1) {
        createBuy(ORDER_SIZE);
    }
    else if(event == OP_SELL && order.ticket == -1) {
        createSell(ORDER_SIZE);
    }
    
    //---------------------------------------------------------------------------------------------PROFIT AND LOSSES
    if(order.ticket != -1) {
        if(order.op_type == OP_BUY) {  //CASE FOR BUYS
            if(bid >= order.tp) {
                closeBuy();
            }
            else if(bid <= order.sl) {
                closeBuy();
                
                if(order.size < 0.04) {
                    double osize = order.size + ORDER_SIZE;
                    createSell(osize);
                }
            }
        }
        else {  //CASE FOR SELLS
            if(ask <= order.tp)
                closeSell();
            else if(ask >= order.sl) {
                closeSell();
                
                if(order.size < 0.04) {
                    double osize = order.size + ORDER_SIZE;
                    createBuy(osize);
                }
            }
        }
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+

/********************************************** CLOSE Functions ************************************************************/

bool closeBuy() {
    string symbol = Symbol();
    double bid = MarketInfo(symbol, MODE_BID);
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    bool closed = OrderClose(order.ticket, order.size, bid, SLIPPAGE, clrNONE);
    if(closed) {
        order.ticket = -1;
    }
    
    return closed;
}

bool closeSell() {
    string symbol = Symbol();
    double ask = MarketInfo(symbol, MODE_ASK);
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    bool closed = OrderClose(order.ticket, order.size, ask, SLIPPAGE, clrNONE);
    if(closed) {
        order.ticket = -1;
    }
    
    return closed;
}

/********************************************** CREATE Functions *************************************************************/

void createBuy(double osize) {
    string symbol = Symbol();
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    int optype = OP_BUY;
    double oprice = MarketInfo(symbol, MODE_ASK);

    double tp = oprice + 300 * point;
    double sl = oprice - 100 * point;

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
        order.ticket = ticket;
        order.op_type = optype;
        order.price = oprice;
        order.size = osize;
        order.symbol = symbol;
        order.tp = tp;
        order.sl = sl;
    }
}

void createSell(double osize) {
    string symbol = Symbol();
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    int optype = OP_SELL;
    double oprice = MarketInfo(symbol, MODE_BID);

    double tp = oprice - 300 * point;
    double sl = oprice + 100 * point;

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
        order.ticket = ticket;
        order.op_type = optype;
        order.price = oprice;
        order.size = osize;
        order.symbol = symbol;
        order.tp = tp;
        order.sl = sl;
    }
}

/**
 * hard coded samples for testing
 */
int checkNewsTrade(int y, int month, int d, int h, int min) {
    if(y == 2014 && month == 10 && d == 1 && h == 12 && min == 13)  //ADP Non-Farm Employment Change
        return OP_SELL;
    
    if(y == 2014 && month == 10 && d == 1 && h == 13 && min == 58)
        return OP_BUY;
    
    if(y == 2014 && month == 10 && d == 2 && h == 12 && min == 28)
        return OP_BUY;
    
    if(y == 2014 && month == 10 && d == 14 && h == 8 && min == 58)
        return OP_SELL;
    
    if(y == 2014 && month == 10 && d == 15 && h == 12 && min == 28)
        return OP_BUY;
    
    if(y == 2014 && month == 10 && d == 17 && h == 13 && min == 53)
        return OP_BUY;
    
    if(y == 2014 && month == 10 && d == 23 && h == 6 && min == 58)
        return OP_SELL;
    
    if(y == 2014 && month == 10 && d == 23 && h == 7 && min == 28)
        return OP_SELL;
        
    if(y == 2014 && month == 10 && d == 27 && h == 8 && min == 58) //German Ifo Business Climate
        return OP_SELL;
    
    if(y == 2014 && month == 10 && d == 28 && h == 13 && min == 58)  //CB Consumer Confidence
        return OP_BUY;
        
    return NO_OP;
}