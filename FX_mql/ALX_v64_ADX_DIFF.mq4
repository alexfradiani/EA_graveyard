//+------------------------------------------------------------------+
//|                                             ALX_v64_ADX_DIFF.mq4 |
//|                          Copyright 2015-2016, Alexander Fradiani |
//|                                          http://www.fradiani.com |
//+------------------------------------------------------------------+

/**
 * - ADX sends valid triggers during London-NY time
 * - ATR determines SL-TP with a minimum profit difference, and with a cycle minimum restriction
 * - orders are controlled by cycles with following rules:
 *         - a cycle is valid only during one trading day, every new day starts a new cycle
 *         - maximum 2 full cycles per day
 *         - every order that opens having one or more still active belongs to the same cycle (given the same day)
 */

#property copyright "Copyright 2015-2016, Alexander Fradiani"
#property link      "http://www.fradiani.com"
#property version   "1.00"
#property strict

//Money Management
#define DIFF_PROFIT 50
#define ORDER_SIZE 0.1

//Trade constants
#define MAX_ORDERS 100
#define SLIPPAGE 10

#define UP 1
#define DOWN -1
#define NONE 0

//Order structure
struct order_t {     
    int ticket;
    string symbol;
    double price;
    int op_type;
    double size;
    
    double sl;
    double tp;
    double atr;
};
order_t orders[MAX_ORDERS];
int oIndex = 0;

//strategy variables
int adxSide;
datetime lastBar;

int currentDay, dayCycles;
int londonOpen, nyOpen;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    oIndex = 0;
    
    double adxPlus = iADX(Symbol(), PERIOD_H1, 12, PRICE_CLOSE, MODE_PLUSDI, 0);
    double adxMinus = iADX(Symbol(), PERIOD_H1, 12, PRICE_CLOSE, MODE_MINUSDI, 0);
    if(adxPlus > adxMinus)
        adxSide = UP;
    else if(adxPlus < adxMinus)
        adxSide = DOWN;
    else
        adxSide = NONE;
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    oIndex = 0;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    //---------------------------------------------------------------------------------------------TIME metric
    datetime currentTime = TimeCurrent();
    
    //price values
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    //New day checking
    if(currentDay != TimeDay(currentTime))
        adjustGMTOpenings();
        
    //---------------------------------------------------------------------------------------------TRADING RULES
    if(lastBar != Time[0]) {
        double adxPlus = iADX(Symbol(), PERIOD_H1, 12, PRICE_CLOSE, MODE_PLUSDI, 0);
        double adxMinus = iADX(Symbol(), PERIOD_H1, 12, PRICE_CLOSE, MODE_MINUSDI, 0);
        if(adxPlus > adxMinus) {
            if(adxSide <= NONE) {
                createBuy();
                
                adxSide = UP;
            }
        }
        else if(adxPlus < adxMinus) {
            if(adxSide >= NONE) {
                createSell();
                
                adxSide = DOWN;
            }
        }
        else
            adxSide = NONE;
            
        lastBar = Time[0];
    }
    
    //---------------------------------------------------------------------------------------------PROFIT AND LOSSES
    for(int i = 0; i < oIndex; i++) {
        if(orders[i].op_type == OP_BUY) { //case for buys
            if(bid >= orders[i].tp)
                closeBuy(i);
            else if(bid <= orders[i].sl)
                closeBuy(i);
                
            if(TimeDayOfWeek(TimeCurrent()) == 5 && TimeHour(TimeCurrent()) >= 14)  //friday limit
                closeBuy(i);
        }
        else if(orders[i].op_type == OP_SELL) { //case for sells
            if(ask <= orders[i].tp)
                closeSell(i);
            else if(ask >= orders[i].sl)
                closeSell(i);
                
            if(TimeDayOfWeek(TimeCurrent()) == 5 && TimeHour(TimeCurrent()) >= 14)  //friday limit
                closeSell(i);
        }
    }
    
    writeComments();
    RefreshRates();
}
//+------------------------------------------------------------------+

/**
 * Comments for log in terminal
 */
void writeComments() {
    datetime t = TimeCurrent();
    int wday = TimeDayOfWeek(t);
    
    string msg = "Trend direction: " + IntegerToString(adxSide) + " \n";
    msg += "Week-day: " + IntegerToString(wday) + " \n";
    msg += "Ballance: " + DoubleToString(AccountBalance()) + " \n";
    msg += "Opened orders: " + IntegerToString(oIndex);
    
    Comment(msg);
}

/**
 * Calculate Size of a new order
 */
double calcOrderSize() {
    //TODO
    
    return 0.0;
}

/**
 * Mondays and Fridays excluded from trading.
 */
bool isTradingDay() {
    datetime t = TimeCurrent();
    
    int wday = TimeDayOfWeek(t);
    if(wday >= 2 && wday <= 4)  //Tuesday to thursday
        return TRUE;
    else
        return FALSE;
}

/**
 * Adjust London and New York time switch during winter and summer
 */
void adjustGMTOpenings() {
    datetime t = TimeCurrent();
    
    int year = TimeYear(t);
    int month = TimeMonth(t);
    int day = TimeDay(t);
    switch(year) {
        case 2010:
            //london offset
            if( (month >= 4 || (month == 3 && day >= 28)) && (month < 10 || (month == 10 && day < 31 )) )
                londonOpen = 7;
            else
                londonOpen = 8;
            //ny offset
            if( (month >= 4 || (month == 3 && day >= 14)) && (month < 11 || (month == 11 && day < 7 )) )
                nyOpen = 12;
            else
                nyOpen = 13;
        break;
        case 2011:
            //london offset
            if( (month >= 4 || (month == 3 && day >= 27)) && (month < 10 || (month == 10 && day < 30 )) )
                londonOpen = 7;
            else
                londonOpen = 8;
            //ny offset
            if( (month >= 4 || (month == 3 && day >= 13)) && (month < 11 || (month == 11 && day < 6 )) )
                nyOpen = 12;
            else
                nyOpen = 13;
        break;
        case 2012:
            //london offset
            if( (month >= 4 || (month == 3 && day >= 25)) && (month < 10 || (month == 10 && day < 28 )) )
                londonOpen = 7;
            else
                londonOpen = 8;
            //ny offset
            if( (month >= 4 || (month == 3 && day >= 11)) && (month < 11 || (month == 11 && day < 4 )) )
                nyOpen = 12;
            else
                nyOpen = 13;
        break;
        case 2013:
            //london offset
            if( (month >= 4 || (month == 3 && day >= 31)) && (month < 10 || (month == 10 && day < 27 )) )
                londonOpen = 7;
            else
                londonOpen = 8;
            //ny offset
            if( (month >= 4 || (month == 3 && day >= 10)) && (month < 11 || (month == 11 && day < 3 )) )
                nyOpen = 12;
            else
                nyOpen = 13;
        break;
        case 2014:
            //london offset
            if( (month >= 4 || (month == 3 && day >= 30)) && (month < 10 || (month == 10 && day < 26 )) )
                londonOpen = 7;
            else
                londonOpen = 8;
            //ny offset
            if( (month >= 4 || (month == 3 && day >= 9)) && (month < 11 || (month == 11 && day < 2 )) )
                nyOpen = 12;
            else
                nyOpen = 13;
        break;
        case 2015:
            //london offset
            if( (month >= 4 || (month == 3 && day >= 29)) && (month < 10 || (month == 10 && day < 25 )) )
                londonOpen = 7;
            else
                londonOpen = 8;
            //ny offset
            if( (month >= 4 || (month == 3 && day >= 8)) && (month < 11 || (month == 11 && day < 1 )) )
                nyOpen = 12;
            else
                nyOpen = 13;
        break;
        default: 
            Alert("SESSION DATES FOR THIS YEAR HAVE NOT BEEN DEFINED");
    }
}

double compareATRs(double atr) {
    double maxATR = atr;
    
    for(int i = 0; i < oIndex; i++)
        if(orders[i].atr > maxATR)
            maxATR = orders[i].atr;
            
    return maxATR;
}

/********************************************** CLOSE Functions ************************************************************/

bool closeBuy(int index) {
    string symbol = Symbol();
    double bid = MarketInfo(symbol, MODE_BID);
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    bool closed = OrderClose(orders[index].ticket, orders[index].size, bid, SLIPPAGE, clrNONE);
    if(closed) {
        orders[index].ticket = -1;
        
        for(int i = index; i < oIndex - 1; i++) {
            orders[i].op_type = orders[i + 1].op_type;
            orders[i].ticket = orders[i + 1].ticket;
            orders[i].symbol = orders[i + 1].symbol;
            orders[i].price = orders[i + 1].price;
            orders[i].op_type = orders[i + 1].op_type;
            orders[i].size = orders[i + 1].size;
            orders[i].sl = orders[i + 1].sl;
            orders[i].tp = orders[i + 1].tp;
            orders[i].atr = orders[i + 1].atr;
        }
        
        oIndex--;
    }
    
    return closed;
}

bool closeSell(int index) {
    string symbol = Symbol();
    double ask = MarketInfo(symbol, MODE_ASK);
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    bool closed = OrderClose(orders[index].ticket, orders[index].size, ask, SLIPPAGE, clrNONE);
    if(closed) {
        orders[index].ticket = -1;
        
        for(int i = index; i < oIndex - 1; i++) {
            orders[i].op_type = orders[i + 1].op_type;
            orders[i].ticket = orders[i + 1].ticket;
            orders[i].symbol = orders[i + 1].symbol;
            orders[i].price = orders[i + 1].price;
            orders[i].size = orders[i + 1].size;
            orders[i].sl = orders[i + 1].sl;
            orders[i].tp = orders[i + 1].tp;
            orders[i].atr = orders[i + 1].atr;
        }
        
        oIndex--;
    }
    
    return closed;
}

/********************************************** CREATE Functions *************************************************************/

void createBuy() {
    string symbol = Symbol();
    double point = MarketInfo(Symbol(), MODE_POINT);
    double spread = MarketInfo(symbol, MODE_SPREAD);
    int optype = OP_BUY;
    double oprice = MarketInfo(symbol, MODE_ASK);

    double atr = iATR(symbol, PERIOD_H1, 12, 0);
    atr = compareATRs(atr);
    double tp = oprice + DIFF_PROFIT*point + atr;
    double sl = oprice - atr - spread*point;

	int ticket = OrderSend(
        symbol, //symbol
        optype, //operation
        ORDER_SIZE, //volume
        oprice, //price
        SLIPPAGE, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(ticket > 0) {
        orders[oIndex].ticket = ticket;
        orders[oIndex].op_type = optype;
        orders[oIndex].price = oprice;
        orders[oIndex].size = ORDER_SIZE;
        orders[oIndex].symbol = symbol;
        orders[oIndex].tp = tp;
        orders[oIndex].sl = sl;
        orders[oIndex].atr = atr;
        
        oIndex++;
    }
}

void createSell() {
    string symbol = Symbol();
    double point = MarketInfo(Symbol(), MODE_POINT);
    double spread = MarketInfo(symbol, MODE_SPREAD);
    int optype = OP_SELL;
    double oprice = MarketInfo(symbol, MODE_BID);

    double atr = iATR(symbol, PERIOD_H1, 12, 0);
    atr = compareATRs(atr);
    double tp = oprice - DIFF_PROFIT*point - atr;
    double sl = oprice + atr + spread*point;

	int ticket = OrderSend(
        symbol, //symbol
        optype, //operation
        ORDER_SIZE, //volume
        oprice, //price
        SLIPPAGE, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(ticket > 0) {
        orders[oIndex].ticket = ticket;
        orders[oIndex].op_type = optype;
        orders[oIndex].price = oprice;
        orders[oIndex].size = ORDER_SIZE;
        orders[oIndex].symbol = symbol;
        orders[oIndex].tp = tp;
        orders[oIndex].sl = sl;
        orders[oIndex].atr = atr;
        
        oIndex++;
    }
}
