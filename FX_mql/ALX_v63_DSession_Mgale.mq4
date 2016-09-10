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

//Money Management
#define MAX_LOSS 150
#define DAY_TARGET 100

//Trade constants
#define SLIPPAGE 5
#define FSPREAD 17
#define PROFIT_COEF 40
#define REC_COEF 4

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
order_t order;

//strategy variables
int bollSide, maSide;
datetime lastBar;

int currentIndex = 0;
double dayAccum = 0;
int currentDay;

int trendDirection = NONE;
bool swDayTraded = FALSE;
int londonOpen, nyOpen;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    order.ticket = -1;
    
    lastBar = Time[0];
    
    adjustGMTOpenings();
    
    datetime currentTime = TimeCurrent();
    currentDay = TimeDay(currentTime);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    order.ticket = -1;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    //--------------------------------------------------------------------------------------------- TIME metric
    datetime currentTime = TimeCurrent();
    
    //price values
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    //New day checking
    if(currentDay != TimeDay(currentTime)) {
        adjustGMTOpenings();
        
        currentDay = TimeDay(currentTime);
    }
    
    //---------------------------------------------------------------------------------------------TRADING RULES
    if(isTradingDay()) {
        if(Time[0] != lastBar) {
            //determine long-term trend
            double ma0 = iMA(Symbol(), PERIOD_M1, 720, 0, MODE_SMA, PRICE_CLOSE, 0);
            double ma1 = iMA(Symbol(), PERIOD_M1, 720, 0, MODE_SMA, PRICE_CLOSE, 15);
            if(ma0 > ma1)
                trendDirection = UP;
            else
                trendDirection = DOWN;
            
            //time for trade execution
            int h = TimeHour(currentTime);
            if(h >= londonOpen && h <= nyOpen + 8) {
                if(order.ticket == -1) {
                    double osize = calcOrderSize();
                    if(trendDirection == UP)
                        createBuy(osize);
                    else
                        createSell(osize);
                }
            }
            
            lastBar = Time[0];
        }
    }
    
    //---------------------------------------------------------------------------------------------PROFIT AND LOSSES
    if(order.ticket != -1) {
        if(order.op_type == OP_BUY) {  //CASE FOR BUYS
            if(bid >= order.tp) {
                closeBuy();
            }
            else if(bid <= order.sl) {
                closeBuy();
                
                if(dayAccum > -1*MAX_LOSS) {
                    double osize = calcOrderSize();
                    createSell(osize);
                }
            }
        }
        else {  //CASE FOR SELLS
            if(ask <= order.tp)
                closeSell();
            else if(ask >= order.sl) {
                closeSell();
                
                if(dayAccum > -1*MAX_LOSS) {
                    double osize = calcOrderSize();
                    createBuy(osize);
                }
            }
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
    
    string msg = "Trend direction: " + IntegerToString(trendDirection) + " \n";
    msg += "Day accum: " + DoubleToString(dayAccum, 2) + " \n";
    msg += "Week-day: " + IntegerToString(wday);
    
    Comment(msg);
}

/**
 * Calculate Size of a new order
 */
double calcOrderSize() {
    double newlot = (DAY_TARGET + MathAbs(dayAccum)) / (PROFIT_COEF * FSPREAD);
    
    if(newlot < 0.01)
        newlot = 0.01;
    return NormalizeDouble(newlot, 2);
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
            Alert("SESSION DATES FOR THIS YEAR ARE NECESSARY");
    }
}

/********************************************** CLOSE Functions ************************************************************/

bool closeBuy() {
    string symbol = Symbol();
    double bid = MarketInfo(symbol, MODE_BID);
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    bool closed = OrderClose(order.ticket, order.size, bid, SLIPPAGE, clrNONE);
    if(closed) {
        order.ticket = -1;
        
        dayAccum += (bid - order.price) / point * order.size;
        if(dayAccum > 0)
            dayAccum = 0;
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
        
        dayAccum += (order.price - ask) / point * order.size;
        if(dayAccum > 0)
            dayAccum = 0;
    }
    
    return closed;
}

/********************************************** CREATE Functions *************************************************************/

void createBuy(double osize) {
    string symbol = Symbol();
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    int optype = OP_BUY;
    double oprice = MarketInfo(symbol, MODE_ASK);

    double tp = oprice + PROFIT_COEF * FSPREAD * point;
    double sl = oprice - REC_COEF * FSPREAD * point;

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

    double tp = oprice - PROFIT_COEF * FSPREAD * point;
    double sl = oprice + REC_COEF * FSPREAD * point;

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
