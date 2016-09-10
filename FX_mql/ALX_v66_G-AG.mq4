//+------------------------------------------------------------------+
//|                                                 ALX_v66_G-AG.mq4 |
//|                          Copyright 2015-2016, Alexander Fradiani |
//|                                          http://www.fradiani.com |
//+------------------------------------------------------------------+

/**
 * GRID and ANTI-GRID behaviour working simultaneously
 *
 * every GRID_Y pips represents a new stair.
 * 
 * AG System:
 *     - close trades in sl, leave open the profits
 * G System:
 *     - leave open losing trades, take GRID_Y profits in any direction
 */

#property copyright "Copyright 2015-2016, Alexander Fradiani"
#property link      "http://www.fradiani.com"
#property version   "1.00"
#property strict

//Money Management
#define TARGET 1.0

//Position constants
#define UP 1
#define NONE 0
#define DOWN -1

//Trade constants
#define MAX_ORDERS 200
#define SLIPPAGE 10
#define ORDER_SIZE 0.01

//Order structure
struct order_t {     
    int ticket;
    string symbol;
    double price;
    int op_type;
    double size;
    
    double sl;
    double tp;
    
    int position; //only for G System
};
//list of orders for both systems
order_t AG[MAX_ORDERS], G[MAX_ORDERS];
int AG_i, G_i; //index of orders
int G_pivot; //G system needs a pivot point

//strategy variables
double GRID_Y;  //for both systems, units of the grid
double G_MAX_Y; //for grid system, maximum loss of a trade
double G_accum, G_float, AG_accum, AG_float;
datetime lastBar;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    resetSystems();
    
    lastBar = Time[0];
    GRID_Y = iATR(Symbol(), PERIOD_M30, 300, 0)/MarketInfo(Symbol(), MODE_POINT);
    G_MAX_Y = iATR(Symbol(), PERIOD_W1, 50, 0);
    if(G_MAX_Y == 0.0)  //no history error
        G_MAX_Y = 0.02000;
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    resetSystems();
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
    if(systemsActive() == FALSE) { //no current activity
        //initial movement guess
        double ma_0 = iMA(Symbol(), PERIOD_H1, 12, 0, MODE_SMA, PRICE_CLOSE, 0);
        double ma_2 = iMA(Symbol(), PERIOD_H1, 12, 0, MODE_SMA, PRICE_CLOSE, 2);
        if(ma_0 > ma_2) {
            //AG_createBuy();
            G_createSell(0);
            G_pivot = 0;
        }
        else {
            //AG_createSell();
            G_createBuy(0);
            G_pivot = 0;
        }
    }
    
    if(lastBar != Time[0]) {
        //verify current day
        int wday = TimeDayOfWeek(currentTime);
        if(wday == 5) {  //Fridays close early
            int hour = TimeHour(currentTime);
            if(hour >= 12)
                if(systemsActive() == TRUE)
                    closeSystems();
        }
        
        lastBar = Time[0];
    }
    
    //---------------------------------------------------------------------------------------------PROFIT AND LOSSES
    if(systemsActive() == TRUE) { //current cycle in process
        //-------------------------------------------------------------------------------AG SYSTEM 
        //adjust current positions
        /*if(AG[AG_i].op_type == OP_BUY) {
            if(bid - AG[AG_i].price <= -1 * GRID_Y * point) {
                AG_close(AG_i);
                AG_createSell();
            }
            else if(bid - AG[AG_i].price >= (GRID_Y - spread) * point) {
                AG_createBuy();
            }
        }
        else if(AG[AG_i].op_type == OP_SELL) {
            if(AG[AG_i].price - ask <= -1 * GRID_Y * point) {
                AG_close(AG_i);
                AG_createBuy();
            }
            else if(AG[AG_i].price - ask >= (GRID_Y - spread) * point) {
                AG_createSell();
            }
        }
        
        //adjust older positions
        for(int i = 0; i <= AG_i; i++) {
            if(AG[i].ticket != -1) {
                if(AG[i].op_type == OP_BUY) {
                    if(bid - AG[i].price <= -1 * GRID_Y * point)
                        AG_close(i);
                }
                else if(AG[i].op_type == OP_SELL) {
                    if(AG[i].price - ask <= -1 * GRID_Y * point)
                        AG_close(i);
                }
            }
        }
        
        //calculate floating trades
        AG_float = 0.0;
        for(int i = 0; i <= AG_i; i++) {
            if(AG[i].ticket != -1) {
                if(AG[i].op_type == OP_BUY)
                    AG_float += (bid - AG[i].price) / point * AG[i].size;
                else
                    AG_float += (AG[i].price - ask) / point * AG[i].size;
            }
        }*/
        
        //-------------------------------------------------------------------------------G SYSTEM 
        //adjust current position
        if(G[G_pivot].op_type == OP_BUY) {
            if(ask - G[G_pivot].price >= GRID_Y * point) {
                int np = G[G_pivot].position + (int)MathFloor(MathAbs(ask - G[G_pivot].price) / (GRID_Y*point));
                
                G_close(G_pivot);
                int concurrency = G_checkConcurrency(OP_BUY, np);
                if(concurrency >= 0) {
                    G_pivot = concurrency;
                    Print("pivot changed to ticket: ", G[G_pivot].ticket);
                }
                else {
                    G_createBuy(np);
                    G_pivot = G_i;
                }
            }
            else if(bid - G[G_pivot].price <= -1 * GRID_Y * point) {
                int np = G[G_pivot].position - (int)MathFloor(MathAbs(bid - G[G_pivot].price) / (GRID_Y*point));
                
                int concurrency = G_checkConcurrency(OP_SELL, np);
                if(concurrency >= 0) {
                    G_pivot = concurrency;
                    Print("pivot changed to ticket: ", G[G_pivot].ticket);
                }
                else {
                    G_createSell(np);
                    G_pivot = G_i;
                }
            }
        }
        else if(G[G_pivot].op_type == OP_SELL) {
            if(G[G_pivot].price - bid >= GRID_Y * point) {
                int np = G[G_pivot].position - (int)MathFloor(MathAbs(G[G_pivot].price - bid) / (GRID_Y*point));
                
                G_close(G_pivot);
                int concurrency = G_checkConcurrency(OP_SELL, np);
                if(concurrency >= 0) {
                    G_pivot = concurrency;
                    Print("pivot changed to ticket: ", G[G_pivot].ticket);
                }
                else {
                    G_createSell(np);
                    G_pivot = G_i;
                }
            }
            else if(G[G_pivot].price - ask <= -1 * GRID_Y * point) {
                int np = G[G_pivot].position + (int)MathFloor(MathAbs(G[G_pivot].price - ask) / (GRID_Y*point));
                
                int concurrency = G_checkConcurrency(OP_BUY, np);
                if(concurrency >= 0) {
                    G_pivot = concurrency;
                    Print("pivot changed to ticket: ", G[G_pivot].ticket);
                }
                else {
                    G_createBuy(np);
                    G_pivot = G_i;
                }
            }
        }
        
        //adjust older positions
        for(int i = 0; i <= G_i; i++) {
            if(G[i].ticket != -1) {
                if(G[i].op_type == OP_BUY) {
                    if(ask - G[i].price >= GRID_Y * point)
                        G_close(i);
                    else if(bid - G[i].price <= -1 * G_MAX_Y)
                        G_close(i);
                }
                else if(G[i].op_type == OP_SELL) {
                    if(G[i].price - bid >= GRID_Y * point)
                        G_close(i);
                    else if(G[i].price - ask <= -1 * G_MAX_Y)
                        G_close(i);
                }
            }
        }
        
        //calculate floating trades
        G_float = 0.0;
        for(int i = 0; i <= G_i; i++) {
            if(G[i].ticket != -1) {
                if(G[i].op_type == OP_BUY)
                    G_float += (bid - G[i].price) / point * G[i].size;
                else
                    G_float += (G[i].price - ask) / point * G[i].size;
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
    string msg = "Week-day: " + IntegerToString(wday) + " \n";
    //msg += "AG accum: " + DoubleToString(AG_accum, 2) + " / AG float: " + DoubleToString(AG_float, 2) + " \n";
    msg += "G accum: " + DoubleToString(G_accum, 2) + " / G float: " + DoubleToString(G_float, 2) + " \n";
    msg += "Ballance: " + DoubleToString(AccountBalance(), 2) + " \n";
    
    Comment(msg);
}

/**
 * Check is a cycle is in action
 */
bool systemsActive() {
    if(G[0].ticket != -1 || AG[0].ticket != -1)
        return TRUE;
    else
        return FALSE;
} 
 
/**
 * Reset all systems variables
 */
void resetSystems() {
    //reset AG
    for(int i = 0; i < MAX_ORDERS; i++) {
        AG[i].ticket = -1;
    }
    AG_accum = 0.0;
    AG_i = 0;
    
    //reset G
    for(int i = 0; i < MAX_ORDERS; i++) {
        G[i].ticket = -1;
    }
    G_accum = 0.0;
    G_i = 0;
}

/**
 * CLOSE a complete cycle
 */
void closeSystems() {
    while(AG[0].ticket != 0) {
        AG_close(0);
    }
    
    while(G[0].ticket != 0) {
        G_close(0);
    }
    
    resetSystems();  //reset variables
}

/**
 * AG
 * CLOSE
 */
bool AG_close(int index) {
    string symbol = Symbol();
    double bid = MarketInfo(symbol, MODE_BID);
    double ask = MarketInfo(symbol, MODE_ASK);
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    double price;
    if(AG[index].op_type == OP_BUY)
        price = bid;
    else
        price = ask;
    bool closed = OrderClose(AG[index].ticket, AG[index].size, price, SLIPPAGE, clrNONE);
    if(closed) {  
        AG[index].ticket = -1;
         
        //accumlate
        if(AG[index].op_type == OP_BUY)
            AG_accum += (bid - AG[index].price) / point * AG[index].size;
        else
            AG_accum += (AG[index].price - ask) / point * AG[index].size;
            
        //reorder array
        for(int i = index; i <= AG_i - 1; i++) {
            AG[i].ticket = AG[i+1].ticket;
            AG[i].symbol = AG[i+1].symbol;
            AG[i].price = AG[i+1].price;
            AG[i].op_type = AG[i+1].op_type;
            AG[i].size = AG[i+1].size;
        }
        if(AG_i > 0)
            AG_i--;
    }
    
    return closed;
}

/**
 * G
 * CLOSE
 */
bool G_close(int index) {
    string symbol = Symbol();
    double bid = MarketInfo(symbol, MODE_BID);
    double ask = MarketInfo(symbol, MODE_ASK);
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    double price;
    if(G[index].op_type == OP_BUY)
        price = bid;
    else
        price = ask;
    bool closed = OrderClose(G[index].ticket, G[index].size, price, SLIPPAGE, clrNONE);
    if(closed) {  
        G[index].ticket = -1;
         
        //accumlate
        if(G[index].op_type == OP_BUY)
            G_accum += (bid - G[index].price) / point * G[index].size;
        else
            G_accum += (G[index].price - ask) / point * G[index].size;
            
        //reorder array
        for(int i = index; i <= G_i - 1; i++) {
            G[i].ticket = G[i+1].ticket;
            G[i].symbol = G[i+1].symbol;
            G[i].price = G[i+1].price;
            G[i].op_type = G[i+1].op_type;
            G[i].size = G[i+1].size;
            
            G[i].position = G[i+1].position;
        }
        if(G_i > 0) {
            G_i--;
            if(G_pivot > 0)
                G_pivot--;
        }
    }
    
    return closed;
}

/**
 * AG
 * CREATE a buy
 */
void AG_createBuy() {
    string symbol = Symbol();
    int optype = OP_BUY;
    double oprice = MarketInfo(symbol, MODE_ASK);

	int ticket = OrderSend(
        symbol, //symbol
        optype, //operation
        ORDER_SIZE, //volume
        oprice, //price
        SLIPPAGE, //slippage
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(ticket > 0) {
        if(AG[AG_i].ticket != -1)
            AG_i++; //increase order index
        
        AG[AG_i].ticket = ticket;
        AG[AG_i].op_type = optype;
        AG[AG_i].price = oprice;
        AG[AG_i].size = ORDER_SIZE;
        AG[AG_i].symbol = symbol;
    }
}

/**
 * AG
 * CREATE a SELL 
 */
void AG_createSell() {
    string symbol = Symbol();
    int optype = OP_SELL;
    double oprice = MarketInfo(symbol, MODE_BID);

	int ticket = OrderSend(
        symbol, //symbol
        optype, //operation
        ORDER_SIZE, //volume
        oprice, //price
        SLIPPAGE, //slippage
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(ticket > 0) {
        if(AG[AG_i].ticket != -1)
            AG_i++; //increase order index
        
        AG[AG_i].ticket = ticket;
        AG[AG_i].op_type = optype;
        AG[AG_i].price = oprice;
        AG[AG_i].size = ORDER_SIZE;
        AG[AG_i].symbol = symbol;
    }
}

/**
 * G
 * CREATE a buy
 */
void G_createBuy(int np) {
    string symbol = Symbol();
    int optype = OP_BUY;
    double oprice = MarketInfo(symbol, MODE_ASK);

	int ticket = OrderSend(
        symbol, //symbol
        optype, //operation
        ORDER_SIZE, //volume
        oprice, //price
        SLIPPAGE, //slippage
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(ticket > 0) {
        if(G[G_i].ticket != -1)
            G_i++; //increase order index
        
        G[G_i].ticket = ticket;
        G[G_i].op_type = optype;
        G[G_i].price = oprice;
        G[G_i].size = ORDER_SIZE;
        G[G_i].symbol = symbol;
        
        G[G_i].position = np;
        Print("ticket ", ticket, " at position: ", np);
    }
}

/**
 * G
 * CREATE a SELL
 */
void G_createSell(int np) {
    string symbol = Symbol();
    int optype = OP_SELL;
    double oprice = MarketInfo(symbol, MODE_BID);

	int ticket = OrderSend(
        symbol, //symbol
        optype, //operation
        ORDER_SIZE, //volume
        oprice, //price
        SLIPPAGE, //slippage
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(ticket > 0) {
        if(G[G_i].ticket != -1)
            G_i++; //increase order index
        
        G[G_i].ticket = ticket;
        G[G_i].op_type = optype;
        G[G_i].price = oprice;
        G[G_i].size = ORDER_SIZE;
        G[G_i].symbol = symbol;
        
        G[G_i].position = np;
        Print("ticket ", ticket, " at position: ", np);
    }
}

/**
 * G
 * Check concurrency
 * no more than one concurrent buy/sell for every position in the grid
 */
int G_checkConcurrency(int op_type, int position) {
    for(int i = 0; i <= G_i; i++)
        if(G[i].ticket != -1)    
            if(G[i].position == position && G[i].op_type == op_type) {
                return i; //already exists order of that type in that position
            }
              
    return -1; //no concurrency
} 