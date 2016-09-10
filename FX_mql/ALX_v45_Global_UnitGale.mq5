//+------------------------------------------------------------------+
//|                                      ALX_v45_Global_UnitGale.mq5 |
//+------------------------------------------------------------------+

#property copyright "ALEXANDER FRADIANI"
#property version   "1.00"
#property strict

#define ALL_SYMB_N 1
#define MAX_TRADES 1
#define RISK_LIMIT 10
#define PIP_TARGET 10
#define INIT_SIZE 0.01

#define UP 1
#define DOWN -1
#define NONE 0

//NECESSARY TO ASSIST IN CONVERSION FROM MQL4
#define OP_BUY 0           //Buy 
#define OP_SELL 1          //Sell 
#define MODE_BID 9
#define MODE_ASK 10
#define MODE_POINT 11
#define MODE_SPREAD 13

datetime lastTime;

string suffix = ".m";
string defaultPairs[] = {
    "GBPJPY"
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
    int cycleIndex;
    order_t orders[15];
};

gale_trade_t trades[MAX_TRADES];
int tradeIndex;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
    lastTime = NULL;
    tradeIndex = 0;
//---
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
    lastTime = NULL;
    tradeIndex = 0;
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
        //----------------------------------------------------------------------- orderPairs and check possible trades
        orderPairs();
        for(int i = tradeIndex; i < MAX_TRADES; i++) {
            bool swSymb = true;
            int pivot = 0;
            while(swSymb == true) {
                string symbol = orderedPairs[pivot].symbol;
                if(symbolAvailable(symbol) == true) {
                    evaluateTrade(pivot);
                    swSymb = false;
                }
                else
                    pivot++;
            }
        }
        
        //----------------------------------------------------------------------- check cycles of current trades
        checkTradeCycles();
        
        lastTime = Time[0];
    }
    
    //--------------------------------------------------------------------------- check in real time, cycles that can be closed
    for(int i = 0; i < tradeIndex; i++) {
        double accum = 0;
        for(int j = 0; j < trades[i].cycleIndex; j++) {
            if(trades[i].orders[j].op_type == ORDER_TYPE_BUY) {  //CASE BUY
                double bid = MarketInfo(trades[i].orders[j].symbol, MODE_BID);
                double points = (bid - trades[i].orders[j].price) / MarketInfo(trades[i].orders[j].symbol, MODE_POINT);
                
                accum += points * trades[i].orders[j].size;
            }
            else {  //CASE SELL
                double ask = MarketInfo(trades[i].orders[j].symbol, MODE_ASK);
                double points = (trades[i].orders[j].price - ask) / MarketInfo(trades[i].orders[j].symbol, MODE_POINT);
                
                accum += points * trades[i].orders[j].size;
            }
        }
        if(accum >= PIP_TARGET*INIT_SIZE) {
            closeCycles(i);
            reorderTrades(i);
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
        
        for(int i = 1; i <= 100; i++) {
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
 * Allow only one trade for symbol
 */
bool symbolAvailable(string symbol) {
    for(int i = 0; i < tradeIndex; i++) {
        if(trades[i].orders[0].symbol == symbol)
            return false;
    }
    
    return true;
}

/** 
 * Set a trade in the symbol specified
 */
void evaluateTrade(int i) {
    string symbol = orderedPairs[i].symbol;
    double movement = orderedPairs[i].movement;
    
    if(movement > 0) {
        Print("evaluate buy");
        double bid = MarketInfo(symbol, MODE_BID);
        double sl = bid - PIP_TARGET*MarketInfo(symbol, MODE_POINT);
        
        trades[tradeIndex].cycleIndex = 0;
        createBuy(symbol, sl, INIT_SIZE, tradeIndex);
    }
    else {
        Print("evaluate sell");
        double ask = MarketInfo(symbol, MODE_ASK);
        double sl = ask + PIP_TARGET*MarketInfo(symbol, MODE_POINT);
        
        trades[tradeIndex].cycleIndex = 0;
        createSell(symbol, sl, INIT_SIZE, tradeIndex);
    }
} 

/**
 * render all current trades and check if cycles need to be added
 */
void checkTradeCycles() {
    for(int i = 0; i < tradeIndex; i++) {
        int lastCycle = trades[i].cycleIndex - 1;
        
        string symbol = trades[i].orders[lastCycle].symbol;
        double bid = MarketInfo(symbol, MODE_BID);
        double ask = MarketInfo(symbol, MODE_ASK);
        double point = MarketInfo(symbol, MODE_POINT);
        
        if(trades[i].orders[lastCycle].op_type == ORDER_TYPE_BUY) {
            double orderPrice = trades[i].orders[lastCycle].price - MarketInfo(symbol, MODE_SPREAD)*point;
            double diff = (bid - orderPrice);
            if( diff < -1* PIP_TARGET*point ) {  //need to create new cycle
                double sl = ask + PIP_TARGET*point;
                double nsize = 2*trades[i].orders[lastCycle].size;
                createSell(symbol, sl, nsize, i); 
            }    
        }
        else {
            double orderPrice = trades[i].orders[lastCycle].price;
            double diff = (orderPrice - ask);
            if( diff < -1* PIP_TARGET*point ) {  //need to create new cycle
                double sl = bid - PIP_TARGET*point;
                double nsize = 2*trades[i].orders[lastCycle].size;
                createBuy(symbol, sl, nsize, i); 
            }
        }
    }
}

/**
 * Open a BUY order
 */
void createBuy(string symbol, double sl, double size, int tradePos) {
    MqlTradeRequest request;
    MqlTradeResult res;
    
    ZeroMemory(request);
    ZeroMemory(res);
    
    string symbol_s;
    StringConcatenate(symbol_s, symbol, suffix);
    request.symbol = symbol_s;
    
    request.price = MarketInfo(symbol, MODE_ASK);
    request.volume = size;
    request.deviation = 3;  //slippage
    request.type_filling = ORDER_FILLING_FOK;
    request.action = TRADE_ACTION_DEAL;
    request.type = ORDER_TYPE_BUY;
    
    double stoploss = sl;
    
    bool sent = OrderSend(request, res);
    
    //check response
    if(sent) {
        if(res.retcode == TRADE_RETCODE_PLACED || res.retcode == TRADE_RETCODE_DONE) {
            int cycle = trades[tradePos].cycleIndex;
            trades[tradePos].orders[cycle].symbol = symbol;
            trades[tradePos].orders[cycle].op_type = request.type;
            trades[tradePos].orders[cycle].price = res.price;
            trades[tradePos].orders[cycle].ticket = res.deal;
            trades[tradePos].orders[cycle].size = res.volume;
            trades[tradePos].orders[cycle].sl = stoploss;
            
            trades[tradePos].cycleIndex++;
            if(size == INIT_SIZE)
                tradeIndex++;
        }
    }
}

/**
 * Open a SELL order
 */
void createSell(string symbol, double sl, double size, int tradePos) {
    MqlTradeRequest request;
    MqlTradeResult res;
    
    ZeroMemory(request);
    ZeroMemory(res);
    
    string symbol_s;
    StringConcatenate(symbol_s, symbol, suffix);
    request.symbol = symbol_s;
    
    request.price = MarketInfo(symbol, MODE_BID);
    request.volume = size;
    request.deviation = 3;  //slippage
    request.type_filling = ORDER_FILLING_FOK;
    request.action = TRADE_ACTION_DEAL;
    request.type = ORDER_TYPE_SELL; 
    
    double stoploss = sl;
    
    bool sent = OrderSend(request, res);
    
    //check response
    if(sent) {
        if(res.retcode == TRADE_RETCODE_PLACED || res.retcode == TRADE_RETCODE_DONE) {
            int cycle = trades[tradePos].cycleIndex;
            trades[tradePos].orders[cycle].symbol = symbol;
            trades[tradePos].orders[cycle].op_type = request.type;
            trades[tradePos].orders[cycle].price = res.price;
            trades[tradePos].orders[cycle].ticket = res.deal;
            trades[tradePos].orders[cycle].size = res.volume;
            trades[tradePos].orders[cycle].sl = stoploss;
            
            trades[tradePos].cycleIndex++;
            if(size == INIT_SIZE)
                tradeIndex++;
        }
    }
}

/**
 * Close all cycles orders
 */
void closeCycles(int i) {
    while(trades[i].cycleIndex > 0) {
        int cycle = trades[i].cycleIndex - 1;
        if(closeOrder(i, cycle))
            trades[i].cycleIndex--;
    }
}

/**
 * reorder array after closing trade
 */
void reorderTrades(int i) {
    for(int p = i; p < tradeIndex - 1; p++) {
        trades[p].cycleIndex = trades[p+1].cycleIndex;
        for(int c = 0; c < trades[p].cycleIndex; c++) {
            trades[p].orders[c].op_type = trades[p+1].orders[c].op_type;
            trades[p].orders[c].price = trades[p+1].orders[c].price;
            trades[p].orders[c].size = trades[p+1].orders[c].size;
            trades[p].orders[c].sl = trades[p+1].orders[c].sl;
            trades[p].orders[c].symbol = trades[p+1].orders[c].symbol;
            trades[p].orders[c].ticket = trades[p+1].orders[c].ticket;
        }
    }
   
    tradeIndex--;
}

/**
 * Close an order
 */
bool closeOrder(int tI, int cI) {
    MqlTradeRequest request;
    MqlTradeResult result;
    
    ZeroMemory(request);
    ZeroMemory(result);
    
    ENUM_ORDER_TYPE ptype;
    if(trades[tI].orders[cI].op_type == ORDER_TYPE_BUY) {
        request.price = MarketInfo(trades[tI].orders[0].symbol, MODE_BID);
        ptype = ORDER_TYPE_SELL;
    }
    else {
        request.price = MarketInfo(trades[tI].orders[0].symbol, MODE_ASK);
        ptype = ORDER_TYPE_BUY;
    }
    
    request.action = TRADE_ACTION_DEAL;
    request.type = ptype;
    request.volume = trades[tI].orders[cI].size;
    request.deviation = 3;  //slippage
    
    string symbol_s;
    StringConcatenate(symbol_s, trades[tI].orders[cI].symbol, suffix);
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