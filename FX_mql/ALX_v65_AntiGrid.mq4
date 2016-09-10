//+------------------------------------------------------------------+
//|                                             ALX_v65_AntiGrid.mq4 |
//|                          Copyright 2015-2016, Alexander Fradiani |
//|                                          http://www.fradiani.com |
//+------------------------------------------------------------------+

/**
 * every GRID_Y pips represents a new stair. both sell/buy in every stair.
 * close trades in sl, leave open the profits
 * increase size x1 when stair is revisited in the same cycle
 */

#property copyright "Copyright 2015-2016, Alexander Fradiani"
#property link      "http://www.fradiani.com"
#property version   "1.00"
#property strict

//Money Management
#define DAY_TARGET 5.0

//Position constants
#define UP 1
#define NONE 0
#define DOWN -1
#define TO_UP 1
#define TO_NONE 0
#define TO_DOWN -1
#define NO_CHANGE -99

//Trade constants
#define GRID_Y 47
#define MAX_ORDERS 50
#define MAX_STAIRS 200
#define SLIPPAGE 10
#define ORDER_SIZE 0.01

//Order structure
struct order_t {     
    int ticket;
    string symbol;
    double price;
    int op_type;
    double size;
};
struct stair_t {
    int oi;
    double size;
    double profitloss;
    order_t orders[MAX_ORDERS];
};
struct cycle_t {
    stair_t stairs[MAX_STAIRS];
    int p;
};
//Cycles for buys and sells
cycle_t buys, sells;

//strategy variables
int bollSide;
datetime lastBar;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    resetCycle();
    readBollinger();
    
    lastBar = Time[0];
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    resetCycle();
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
        
    //---------------------------------------------------------------------------------------------TRADING RULES
    int bll = readBollinger();
    if(bll == TO_UP || bll == TO_DOWN) {
        if(cycleIsRunning() == FALSE) { //no current cycle
            createBuy();
            createSell();
        }
    }
    
    if(lastBar != Time[0]) {
        //verify current day
        int wday = TimeDayOfWeek(currentTime);
        if(wday == 5) {  //Fridays close early
            int hour = TimeHour(currentTime);
            if(hour >= 12)
                if(cycleIsRunning() == TRUE)
                    closeCycle();
        }
           
        lastBar = Time[0];
    }
    
    //---------------------------------------------------------------------------------------------PROFIT AND LOSSES
    if(cycleIsRunning() == TRUE) { //current cycle in process
        double spread = 17;
        //adjust current positions
        int lastoi = buys.stairs[buys.p].oi;
        if(bid - buys.stairs[buys.p].orders[lastoi].price <= -1 * (GRID_Y) * point) {
            closeBuy(buys.p, lastoi);
            buys.p--;
            sells.p--;
            createBuy();
            createSell();
        }
        /*else if(bid - buys.stairs[buys.p].orders[lastoi].price >= (GRID_Y - spread) * point) {
            buys.p++;
            createBuy();
        }*/
        
        lastoi = sells.stairs[sells.p].oi;
        if(sells.stairs[sells.p].orders[lastoi].price - ask <= -1 * (GRID_Y) * point) {
            closeSell(sells.p, lastoi);
            sells.p++;
            buys.p++;
            createSell();
            createBuy();
        }
        /*else if(sells.stairs[sells.p].orders[lastoi].price - ask >= (GRID_Y - spread) * point) {
            sells.p--;
            createSell();
        }*/
        
        //adjust older positions
        for(int i = 0; i < MAX_STAIRS; i++)
            for(int j = 0; j <= buys.stairs[i].oi; j++)
                if(buys.stairs[i].orders[j].ticket != -1) {
                    if(bid - buys.stairs[i].orders[j].price <= -1 * GRID_Y * point)
                        closeBuy(i, j);
                }
        
        for(int i = 0; i < MAX_STAIRS; i++)
            for(int j = 0; j <= sells.stairs[i].oi; j++)
                if(sells.stairs[i].orders[j].ticket != -1) {
                    if(sells.stairs[i].orders[j].price - ask <= -1 * GRID_Y * point)
                        closeSell(i, j);
                }
        
        //check possible closing of cycle by accumulated profits
        double accum = 0;
        for(int i = 0; i < MAX_STAIRS; i++) {
            if(buys.stairs[i].orders[0].ticket != -1) { //there are orders in this stair
                accum += buys.stairs[i].profitloss;
                
                for(int j = 0; j <= buys.stairs[i].oi; j++)
                    accum += (bid - buys.stairs[i].orders[j].price) / point * buys.stairs[i].orders[j].size;
            }
            else
                accum += buys.stairs[i].profitloss;
        }
        
        for(int i = 0; i < MAX_STAIRS; i++) {
            if(sells.stairs[i].orders[0].ticket != -1) { //there are orders in this stair
                accum += sells.stairs[i].profitloss;
                
                for(int j = 0; j <= sells.stairs[i].oi; j++)
                    accum += (sells.stairs[i].orders[j].price - ask) / point * sells.stairs[i].orders[j].size;
            }
            else
                accum += sells.stairs[i].profitloss;
        }
        
        if(accum >= DAY_TARGET)
            closeCycle();    
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
    string msg = "Bollinger position: " + IntegerToString(bollSide) + " \n" + "Week-day: " + IntegerToString(wday) + " \n";
    msg += "Ballance: " + DoubleToString(AccountBalance()) + " \n";
    
    Comment(msg);
}

/**
 * Check is a cycle is in action
 */
bool cycleIsRunning() {
    int lastoi = buys.stairs[buys.p].oi;
    if(buys.stairs[buys.p].orders[lastoi].ticket == -1)
        return FALSE;
    else
        return TRUE;
} 
 
/**
 * Reset all cycle variables
 */
void resetCycle() {
    //reset all buys
    for(int i = 0; i < MAX_STAIRS; i++) {
        buys.stairs[i].profitloss = 0;
        buys.stairs[i].size = 0;
        buys.stairs[i].oi = 0;
        
        for(int j = 0; j < MAX_ORDERS; j++)
            buys.stairs[i].orders[j].ticket = -1;
    }
    buys.p = 100;  //middle point for stairs
    
    //reset all sells
    for(int i = 0; i < MAX_STAIRS; i++) {
        sells.stairs[i].profitloss = 0;
        sells.stairs[i].size = 0;
        sells.stairs[i].oi = 0;
        
        for(int j = 0; j < MAX_ORDERS; j++)
            sells.stairs[i].orders[j].ticket = -1;
    }
    sells.p = 100;  //middle point for stairs
}

/**
 * READ bollinger bands and define side
 */
int readBollinger() {
    double bid = MarketInfo(Symbol(), MODE_BID);
    double upper = iBands(Symbol(), PERIOD_M5, 288, 2, 0, PRICE_CLOSE, MODE_UPPER, 0);
    double lower = iBands(Symbol(), PERIOD_M5, 288, 2, 0, PRICE_CLOSE, MODE_LOWER, 0);
    
    int change_state = NO_CHANGE;
    if(bid >= upper) {
        if(bollSide != UP)
            change_state = TO_UP;
            
        bollSide = UP;
    }
    else if(bid <= lower) {
        if(bollSide != DOWN)
            change_state = TO_DOWN;
        
        bollSide = DOWN;
    }
    else {
        if(bollSide != NONE)
            change_state = TO_NONE;
            
        bollSide = NONE;
    }
 
    return change_state;
}

/**
 * CLOSE a complete cycle
 */
void closeCycle() {
    for(int i = 0; i < MAX_STAIRS; i++) {
        while(buys.stairs[i].oi > 0 || buys.stairs[i].orders[0].ticket != -1) {
            closeBuy(i, 0);
        }
    }
    
    for(int i = 0; i < MAX_STAIRS; i++) {
        while(sells.stairs[i].oi > 0 || sells.stairs[i].orders[0].ticket != -1) {
            closeSell(i, 0);
        }
    }
    
    resetCycle();  //reset stairs variables
}

/**
 * CLOSE a buy stair
 */
bool closeBuy(int p, int oi) {
    string symbol = Symbol();
    double bid = MarketInfo(symbol, MODE_BID);
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    bool closed = OrderClose(buys.stairs[p].orders[oi].ticket, buys.stairs[p].orders[oi].size, bid, SLIPPAGE, clrNONE);
    if(closed) {
        buys.stairs[p].orders[oi].ticket = -1;
        
        //accumlate loss for that stair
        buys.stairs[p].profitloss += (bid - buys.stairs[p].orders[oi].price) / point * buys.stairs[p].orders[oi].size;
        
        //reorder array for that stair
        for(int i = oi; i <= buys.stairs[p].oi - 1; i++) {
            buys.stairs[p].orders[i].ticket = buys.stairs[p].orders[i+1].ticket;
            buys.stairs[p].orders[i].symbol = buys.stairs[p].orders[i+1].symbol;
            buys.stairs[p].orders[i].price = buys.stairs[p].orders[i+1].price;
            buys.stairs[p].orders[i].op_type = buys.stairs[p].orders[i+1].op_type;
            buys.stairs[p].orders[i].size = buys.stairs[p].orders[i+1].size;
        }
        if(buys.stairs[p].oi > 0)
            buys.stairs[p].oi--;
    }
    
    return closed;
}

/**
 * CLOSE a sell stair
 */
bool closeSell(int p, int oi) {
    string symbol = Symbol();
    double ask = MarketInfo(symbol, MODE_ASK);
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    bool closed = OrderClose(sells.stairs[p].orders[oi].ticket, sells.stairs[p].orders[oi].size, ask, SLIPPAGE, clrNONE);
    if(closed) {
        sells.stairs[p].orders[oi].ticket = -1;
        
        //accumlate loss for that stair
        sells.stairs[p].profitloss += (sells.stairs[p].orders[oi].price - ask) / point * sells.stairs[p].orders[oi].size;
        
        //reorder array for that stair
        for(int i = oi; i <= sells.stairs[p].oi - 1; i++) {
            sells.stairs[p].orders[i].ticket = sells.stairs[p].orders[i+1].ticket;
            sells.stairs[p].orders[i].symbol = sells.stairs[p].orders[i+1].symbol;
            sells.stairs[p].orders[i].price = sells.stairs[p].orders[i+1].price;
            sells.stairs[p].orders[i].op_type = sells.stairs[p].orders[i+1].op_type;
            sells.stairs[p].orders[i].size = sells.stairs[p].orders[i+1].size;
        }
        if(sells.stairs[p].oi > 0)
            sells.stairs[p].oi--;
    }
    
    return closed;
}

/**
 * CREATE a buy stair
 */
void createBuy() {
    string symbol = Symbol();
    int optype = OP_BUY;
    double oprice = MarketInfo(symbol, MODE_ASK);

    buys.stairs[buys.p].size += ORDER_SIZE;
    double osize = buys.stairs[buys.p].size;

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
        int lastoi = buys.stairs[buys.p].oi;
        if(buys.stairs[buys.p].orders[lastoi].ticket != -1)
            buys.stairs[buys.p].oi += 1; //increase order index
        
        lastoi = buys.stairs[buys.p].oi;
        
        buys.stairs[buys.p].orders[lastoi].ticket = ticket;
        buys.stairs[buys.p].orders[lastoi].op_type = optype;
        buys.stairs[buys.p].orders[lastoi].price = oprice;
        buys.stairs[buys.p].orders[lastoi].size = osize;
        buys.stairs[buys.p].orders[lastoi].symbol = symbol;
    }
}

/**
 * CREATE a SELL stair
 */
void createSell() {
    string symbol = Symbol();
    int optype = OP_SELL;
    double oprice = MarketInfo(symbol, MODE_BID);

    sells.stairs[sells.p].size += ORDER_SIZE;
    double osize = sells.stairs[sells.p].size;

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
        int lastoi = sells.stairs[sells.p].oi;
        if(sells.stairs[sells.p].orders[lastoi].ticket != -1)
            sells.stairs[sells.p].oi++; //increase order index
        
        lastoi = sells.stairs[sells.p].oi;
        
        sells.stairs[sells.p].orders[lastoi].ticket = ticket;
        sells.stairs[sells.p].orders[lastoi].op_type = optype;
        sells.stairs[sells.p].orders[lastoi].price = oprice;
        sells.stairs[sells.p].orders[lastoi].size = osize;
        sells.stairs[sells.p].orders[lastoi].symbol = symbol;
    }
}
