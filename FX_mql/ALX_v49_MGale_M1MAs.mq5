//+------------------------------------------------------------------+
//|                                          ALX_v49_MGale_M1MAs.mq5 |
//+------------------------------------------------------------------+

/**
 * 1- track the pair with more movement over the last hour
 * 2- play a trade in direction of that movement when M1 5 SMA and 15 SMA also point the same
 * 3- apply martingale of 1:2 ratio in the same direction, max 10 cycles.
 */

#property copyright "ALEXANDER FRADIANI"
#property version   "1.00"
#property strict

#define ALL_SYMB_N 1
#define MAX_TRADES 1
#define GALE_LIMIT 10

#define SL 10
#define TP 20

#define INIT_SIZE 0.01
#define MAX_SIZE 5.12

#define UP 1
#define DOWN -1
#define NONE 0

//NECESSARY TO ASSIST IN CONVERSION FROM MQL4
#define MODE_BID 9
#define MODE_ASK 10
#define MODE_POINT 11
#define MODE_SPREAD 13

datetime lastTime;

string suffix = ".e";
string defaultPairs[] = {
    "EURUSD"
};
/*string defaultPairs[] = {
    "AUDCAD","AUDCHF","AUDJPY","AUDNZD","AUDUSD","CADCHF","CADJPY",
    "CHFJPY","EURAUD","EURCAD","EURCHF","EURGBP","EURJPY","EURNZD",
    "EURUSD","GBPAUD","GBPCAD","GBPCHF","GBPJPY","GBPNZD","GBPUSD",
    "NZDCAD","NZDCHF","NZDJPY","NZDUSD","USDCAD","USDCHF","USDJPY"
};*/

struct _symbSorter {
    double medBar;
    double movement;
    string symbol;
};
_symbSorter orderedPairs[ALL_SYMB_N];

struct order_t {     //DATA for orders
    ulong ticket;
    double price;
    double sl;
    double tp;
    int op_type;
    double size;
    string symbol;
};
struct gale_trade_t {
    double cycleSize;
    string trackedSymbol;
    order_t order;
};

gale_trade_t trades[MAX_TRADES];

//handlers for MAs
double      SMA5[];
int         SMA5_handle;
double      SMA15[];
int         SMA15_handle;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
    lastTime = NULL;
    
    for(int i = 0; i < MAX_TRADES; i++) {
        trades[i].trackedSymbol = NULL;
        trades[i].order.ticket = -1;
    }
//---
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
    lastTime = NULL;
//---
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
//---
    datetime Time[];
    ArraySetAsSeries(Time, true);
    CopyTime(_Symbol, _Period, 0, 1, Time);
    
    if(lastTime != Time[0]) {
        //----------------------------------------------------------------------- orderPairs and assign symbols
        orderPairs();
        int pivot = 0;
        for(int i = 0; i < MAX_TRADES; i++) {  //assign symbol for mgale cycles
            while(trades[i].trackedSymbol == NULL) {
                string symbol = orderedPairs[pivot].symbol;
                if(symbolAvailable(symbol) == true)
                    trades[i].trackedSymbol = symbol;
                pivot++;
            }
        }
        
        //----------------------------------------------------------------------- check if a cycle can be opened
        for(int i = 0; i < MAX_TRADES; i++) {
            if(trades[i].order.ticket == -1) {  //available to start cycle 
                //get indicator data
                SMA5_handle = iMA(trades[i].trackedSymbol, PERIOD_M1, 5, 0, MODE_SMA, PRICE_CLOSE);
                SMA15_handle = iMA(trades[i].trackedSymbol, PERIOD_M1, 15, 0, MODE_SMA, PRICE_CLOSE);
                CopyBuffer(SMA5_handle, 0, 0, 100, SMA5);
                CopyBuffer(SMA15_handle, 0, 0, 100, SMA15);
                ArraySetAsSeries(SMA5, true);
                ArraySetAsSeries(SMA15, true);
                
                if(SMA5[0] > SMA5[1] && SMA15[0] > SMA15[1]) {
                    Print("sma5[0]: ", SMA5[0], " sma5[1]: ", SMA5[1]);
                    Print("sma15[0]: ", SMA15[0], " sma15[1]: ", SMA15[1]);
                    createBuy(i);
                }
                if(SMA5[0] < SMA5[1] && SMA15[0] < SMA15[1]) {
                    Print("sma5[0]: ", SMA5[0], " sma5[1]: ", SMA5[1]);
                    Print("sma15[0]: ", SMA15[0], " sma15[1]: ", SMA15[1]);
                    createSell(i);
                }
            }
        }
        
        lastTime = Time[0];
    }
    
    //--------------------------------------------------------------------------- check in real time, cycles that can be closed
    for(int i = 0; i < MAX_TRADES; i++) {
        if(trades[i].order.ticket != -1) {
            double ask = MarketInfo(trades[i].trackedSymbol, MODE_ASK);
            double bid = MarketInfo(trades[i].trackedSymbol, MODE_BID);
            
            if(trades[i].order.op_type == ORDER_TYPE_BUY) {
                if(bid >= trades[i].order.tp) { //PROFIT
                    if(closeOrder(i)) {  //reset this trade place, symbol might change next time
                        trades[i].cycleSize = 0;
                        trades[i].trackedSymbol = NULL;
                    }
                }
                
                if(ask <= trades[i].order.sl) {  //LOSS
                    if(closeOrder(i)) {  //close loss, next cycle.
                        trades[i].cycleSize = trades[i].order.size;
                        trades[i].order.ticket = -1;
                        
                        if(trades[i].cycleSize >= MAX_SIZE) { //Limit of martingale, no more cycles, take loss.
                            trades[i].cycleSize = 0;
                            trades[i].trackedSymbol = NULL;
                        }
                    }
                }
            }
            
            if(trades[i].order.op_type == ORDER_TYPE_SELL) {
                if(ask <= trades[i].order.tp) { //PROFIT
                    if(closeOrder(i)) {  //reset this trade place, symbol might change next time
                        trades[i].cycleSize = 0;
                        trades[i].trackedSymbol = NULL;
                    }
                }
                
                if(bid >= trades[i].order.sl) {  //LOSS
                    if(closeOrder(i)) {  //close loss, next cycle.
                        trades[i].cycleSize = trades[i].order.size;
                        trades[i].order.ticket = -1;
                        
                        if(trades[i].cycleSize >= MAX_SIZE) { //Limit of martingale, no more cycles, take loss.
                            trades[i].cycleSize = 0;
                            trades[i].trackedSymbol = NULL;
                        }
                    }
                }
            }
        }
    }
}
//+------------------------------------------------------------------+


/**
 * Order pairs based on more movement
 */
void orderPairs() {
    //---------------------------------------------------------------Get the movement amount of each pair
    for(int pIndex = 0; pIndex < ALL_SYMB_N; pIndex++) {
        double movUp = 0;
        double movDown = 0;
        double medBar = 0;
        
        for(int i = 1; i <= 60; i++) {
            double open = iOpen(defaultPairs[pIndex], PERIOD_M5, i);
            double high = iHigh(defaultPairs[pIndex], PERIOD_M5, i);
            double low = iLow(defaultPairs[pIndex], PERIOD_M5, i);
            
            movUp += high - open;
            movDown += open - low;
            medBar += high - low;
        }
        
        orderedPairs[pIndex].medBar = medBar / 100;
        orderedPairs[pIndex].symbol = defaultPairs[pIndex];
        orderedPairs[pIndex].movement = (movUp - movDown) / MarketInfo(defaultPairs[pIndex], MODE_POINT);
    }
    
    //---------------------------------------------------------------Order by descending mode
    for(int i = 0; i < ALL_SYMB_N; i++) {
        for(int j = i; j < ALL_SYMB_N; j++) {
            if(MathAbs(orderedPairs[j].movement) > MathAbs(orderedPairs[i].movement)) {
                _symbSorter temp;
                temp.movement = orderedPairs[i].movement;
                temp.medBar = orderedPairs[i].medBar;
                temp.symbol = orderedPairs[i].symbol;
                
                orderedPairs[i].movement = orderedPairs[j].movement;
                orderedPairs[i].medBar = orderedPairs[j].medBar;
                orderedPairs[i].symbol = orderedPairs[j].symbol;
                
                orderedPairs[j].movement = temp.movement;
                orderedPairs[j].medBar = temp.medBar;
                orderedPairs[j].symbol = temp.symbol;
            }
        }
    }
    
    for(int i = 0; i < ALL_SYMB_N; i++)
        Print("pairs ordered: ", orderedPairs[i].symbol, " movement: ", orderedPairs[i].movement);
}

/** 
 * Get movement amount recorded for that symbol
 */
double getMovement(string symbol) {
    for(int i = 0; i < ALL_SYMB_N; i++)
        if(orderedPairs[i].symbol == symbol)
            return orderedPairs[i].movement;
            
    return 0;
}


/**
 * Allow only one trade for symbol
 */
bool symbolAvailable(string symbol) {
    for(int i = 0; i < MAX_TRADES; i++) {
        if(trades[i].trackedSymbol == symbol)
            return false;
    }
    
    return true;
}

/**
 * Open a BUY order
 */
void createBuy(int index) {
    MqlTradeRequest request;
    MqlTradeResult res;
    
    ZeroMemory(request);
    ZeroMemory(res);
    
    string symbol_s;
    string symbol = trades[index].trackedSymbol;
    StringConcatenate(symbol_s, symbol, suffix);
    request.symbol = symbol_s;
    
    request.price = MarketInfo(symbol, MODE_ASK);
    
    if(trades[index].cycleSize == 0)
        request.volume = INIT_SIZE;
    else
        request.volume = 2 * trades[index].cycleSize;
    
    request.deviation = 3;  //slippage
    request.type_filling = ORDER_FILLING_FOK;
    request.action = TRADE_ACTION_DEAL;
    request.type = ORDER_TYPE_BUY;
    
    bool sent = OrderSend(request, res);
    
    //check response
    if(sent) {
        if(res.retcode == TRADE_RETCODE_PLACED || res.retcode == TRADE_RETCODE_DONE) {
            trades[index].order.symbol = symbol;
            trades[index].order.op_type = request.type;
            trades[index].order.price = res.price;
            
            double stoploss = res.price - SL * MarketInfo(symbol, MODE_POINT);
            double takeprofit = res.price + TP * MarketInfo(symbol, MODE_POINT);
            
            trades[index].order.ticket = res.deal;
            trades[index].order.size = res.volume;
            trades[index].order.sl = stoploss;
            trades[index].order.tp = takeprofit;
        }
    }
}

/**
 * Open a SELL order
 */
void createSell(int index) {
    MqlTradeRequest request;
    MqlTradeResult res;
    
    ZeroMemory(request);
    ZeroMemory(res);
    
    string symbol_s;
    string symbol = trades[index].trackedSymbol;
    StringConcatenate(symbol_s, symbol, suffix);
    request.symbol = symbol_s;
    
    request.price = MarketInfo(symbol, MODE_BID);
    
    if(trades[index].cycleSize == 0)
        request.volume = INIT_SIZE;
    else
        request.volume = 2 * trades[index].cycleSize;
    
    request.deviation = 3;  //slippage
    request.type_filling = ORDER_FILLING_FOK;
    request.action = TRADE_ACTION_DEAL;
    request.type = ORDER_TYPE_SELL;
    
    bool sent = OrderSend(request, res);
    
    //check response
    if(sent) {
        if(res.retcode == TRADE_RETCODE_PLACED || res.retcode == TRADE_RETCODE_DONE) {
            trades[index].order.symbol = symbol;
            trades[index].order.op_type = request.type;
            trades[index].order.price = res.price;
            
            double stoploss = res.price + SL * MarketInfo(symbol, MODE_POINT);
            double takeprofit = res.price - TP * MarketInfo(symbol, MODE_POINT);
            
            trades[index].order.ticket = res.deal;
            trades[index].order.size = res.volume;
            trades[index].order.sl = stoploss;
            trades[index].order.tp = takeprofit;
        }
    }
}

/**
 * Close an order
 */
bool closeOrder(int index) {
    MqlTradeRequest request;
    MqlTradeResult result;
    
    ZeroMemory(request);
    ZeroMemory(result);
    
    ENUM_ORDER_TYPE ptype;
    if(trades[index].order.op_type == ORDER_TYPE_BUY) {
        request.price = MarketInfo(trades[index].trackedSymbol, MODE_BID);
        ptype = ORDER_TYPE_SELL;
    }
    else {
        request.price = MarketInfo(trades[index].trackedSymbol, MODE_ASK);
        ptype = ORDER_TYPE_BUY;
    }
    
    request.action = TRADE_ACTION_DEAL;
    request.type = ptype;
    request.volume = trades[index].order.size;
    request.deviation = 3;  //slippage
    
    string symbol_s;
    StringConcatenate(symbol_s, trades[index].trackedSymbol, suffix);
    request.symbol = symbol_s;
    
    request.type_filling = ORDER_FILLING_FOK;
    
    bool sent = OrderSend(request, result);
    
    if(sent)
        if(result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_DONE)
            return true;
    
    return false;
}

/********************************************************************************************************
 * helpers for mql4 style
 */
double MarketInfo(string symbol, int mode) {
    StringConcatenate(symbol, symbol, suffix);
    MqlTick tick;
    
    SymbolInfoTick(symbol, tick);
    
    switch(mode) {
        case MODE_ASK:
            return tick.ask;
        case MODE_BID:
            return tick.bid;
        case MODE_POINT:
            return SymbolInfoDouble(symbol, SYMBOL_POINT);
        case MODE_SPREAD:
            return SymbolInfoInteger(symbol, SYMBOL_SPREAD) * 1.0;
    }
    
    return 0;
}

double iOpen(string symbol, ENUM_TIMEFRAMES tf, int index) {
    StringConcatenate(symbol, symbol, suffix);
    if(index < 0)
        return(-1);
        
    double Arr[];
    if(CopyOpen(symbol, tf, index, 1, Arr) > 0) 
        return Arr[0];
    else 
        return -1;
}

double iClose(string symbol, ENUM_TIMEFRAMES tf, int index) {
    StringConcatenate(symbol, symbol, suffix);
    if(index < 0)
        return(-1);
        
    double Arr[];
    if(CopyClose(symbol, tf, index, 1, Arr) > 0) 
        return Arr[0];
    else 
        return -1;
}

double iHigh(string symbol, ENUM_TIMEFRAMES tf, int index) {
   StringConcatenate(symbol, symbol, suffix);
   if(index < 0)
        return(-1);
        
    double Arr[];
    if(CopyHigh(symbol, tf, index, 1, Arr) > 0) 
        return Arr[0];
    else 
        return -1;
}

double iLow(string symbol, ENUM_TIMEFRAMES tf, int index) {
   StringConcatenate(symbol, symbol, suffix);
   if(index < 0)
        return(-1);
        
    double Arr[];
    if(CopyLow(symbol, tf, index, 1, Arr) > 0) 
        return Arr[0];
    else 
        return -1;
}
/********************************************************************************************************
 */