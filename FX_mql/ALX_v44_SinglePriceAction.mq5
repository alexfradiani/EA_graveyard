//+------------------------------------------------------------------+
//|                                    ALX_v44_GlobalPriceAction.mq5 |
//+------------------------------------------------------------------+

#property copyright "ALEXANDER FRADIANI"
#property version   "1.00"
#property strict

#define ALL_SYMB_N 1
#define CONCURRENT_TRADES_N 1
#define DAY_TARGET 10

#define UP 1
#define DOWN -1
#define NONE 0

//NECESSARY TO ASSIST IN CONVERSION FROM MQL4
#define OP_BUY 0           //Buy 
#define OP_SELL 1          //Sell 
#define MODE_BID 9
#define MODE_ASK 10
#define MODE_POINT 11

extern double R_VOL = 0.1;  //Risk Volume. base volume of trades

datetime lastTime;

string defaultPairs[] = {
    "EURUSD.m"  //ONLY FOR BACKTESTING
};

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
order_t trades[CONCURRENT_TRADES_N];
int tradeIndex;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    lastTime = NULL;
    tradeIndex = 0;
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    
    return;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {  
    //get current time
    datetime Time[];
    ArraySetAsSeries(Time, true);
    CopyTime(_Symbol, _Period, 0, 1, Time);
    
    if(lastTime != Time[0]) {
        //--------------------------------------------------------------------Check new ordering
        orderPairs();
        
        //--------------------------------------------------------------------Evaluate possible trades
        if(isMarginEnough()) {
            for(int i = 0; i < CONCURRENT_TRADES_N; i++) {
                if(symbolAvailable(orderedPairs[i].symbol))
                    evaluateTrade(i);
            }
        }
        
        lastTime = Time[0];
    }
    
    //--------------------------------------------------------------------Check current trades
    double currPips = 0.0;
    for(int i = 0; i < tradeIndex; i++) {
        if(trades[i].op_type == OP_BUY) {  //CASE FOR BUYS
            double bid = MarketInfo(trades[i].symbol, MODE_BID);
            double diff = (bid - trades[i].price) / MarketInfo(trades[i].symbol, MODE_POINT);    
            if(bid > trades[i].sl)
                currPips += diff;
            else
                closeTrade(i);
        }
        else if(trades[i].op_type == OP_SELL) {  //CASE FOR SELLS
            double ask = MarketInfo(trades[i].symbol, MODE_ASK);
            double diff = (trades[i].price - ask) / MarketInfo(trades[i].symbol, MODE_POINT);
            if(ask < trades[i].sl)
                currPips += diff;
            else
                closeTrade(i);
        }
    }
    if(currPips >= DAY_TARGET*1.0)
        closeDayTrades();  //close and reset
}
//+------------------------------------------------------------------+

/********************************************************************************************************
 * helpers for mql4 style
 */
double MarketInfo(string symbol, int mode) {
    MqlTick tick;
    
    SymbolInfoTick(symbol, tick);
    
    switch(mode) {
        case MODE_ASK:
            return tick.ask;
        case MODE_BID:
            return tick.bid;
        case MODE_POINT:
            return SymbolInfoDouble(symbol, SYMBOL_POINT);
    }
    
    return 0;
}

double iOpen(string symbol, ENUM_TIMEFRAMES tf, int index) {
    if(index < 0)
        return(-1);
        
    double Arr[];
    if(CopyOpen(symbol, tf, index, 1, Arr) > 0) 
        return Arr[0];
    else 
        return -1;
}

double iClose(string symbol, ENUM_TIMEFRAMES tf, int index) {
    if(index < 0)
        return(-1);
        
    double Arr[];
    if(CopyClose(symbol, tf, index, 1, Arr) > 0) 
        return Arr[0];
    else 
        return -1;
}

double iHigh(string symbol, ENUM_TIMEFRAMES tf, int index) {
   if(index < 0)
        return(-1);
        
    double Arr[];
    if(CopyHigh(symbol, tf, index, 1, Arr) > 0) 
        return Arr[0];
    else 
        return -1;
}

double iLow(string symbol, ENUM_TIMEFRAMES tf, int index) {
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
}

/**
 * Check conditions for opening a trade
 */
void evaluateTrade(int index) {
    string symbol = orderedPairs[index].symbol;
    int m1, m5, m15, m30, h1, h4, d1, w1, mn;
    m1 = m5 = m15 = m30 = h1 = h4 = d1 = w1 = mn = NONE;
    
    int p1, p2;
    p1 = p2 = -1;
    int wavecount = 0;
    double wavesize = 0;
    
    double openm1    = iOpen(symbol, PERIOD_M1, 0);
    double closem1   = iClose(symbol, PERIOD_M1, 0);
    double openm5    = iOpen(symbol, PERIOD_M5, 0);
    double closem5   = iClose(symbol, PERIOD_M5, 0);
    double openm15   = iOpen(symbol, PERIOD_M15, 0);
    double closem15  = iClose(symbol, PERIOD_M15, 0);
    double openm30   = iOpen(symbol, PERIOD_M30, 0);
    double closem30  = iClose(symbol, PERIOD_M30, 0);
    double openh1    = iOpen(symbol, PERIOD_H1, 0);
    double closeh1   = iClose(symbol, PERIOD_H1, 0);      
    double openh4    = iOpen(symbol, PERIOD_H4, 0);
    double closeh4   = iClose(symbol, PERIOD_H4, 0);
    double opend     = iOpen(symbol, PERIOD_D1, 0);
    double closed    = iClose(symbol, PERIOD_D1, 0);
    double openw     = iOpen(symbol, PERIOD_W1, 0);
    double closew    = iClose(symbol, PERIOD_W1, 0);
    double openmn    = iOpen(symbol, PERIOD_MN1, 0);
    double closemn   = iClose(symbol, PERIOD_MN1, 0);
    
    if(closem1 > openm1) m1 = UP;
    if(closem1 < openm1) m1 = DOWN;
    if(closem5 > openm5) m5 = UP;
    if(closem5 < openm5) m5 = DOWN;
    if(closem15 > openm15) m15 = UP;
    if(closem15 < openm15) m15 = DOWN;
    if(closem30 > openm30) m30 = UP;
    if(closem30 < openm30) m30 = DOWN;
    if(closeh1 > openh1) h1 = UP;
    if(closeh1 < openh1) h1 = DOWN;
    if(closeh4 > openh4) h4 = UP;
    if(closeh4 < openh4) h4 = DOWN;
    if(closed > opend) d1 = UP;
    if(closed < opend) d1 = DOWN;
    if(closew > openw) w1 = UP;
    if(closew < openw) w1 = DOWN;
    if(closemn > openmn) mn = UP;
    if(closemn < openmn) mn = DOWN;
    
    if(orderedPairs[index].movement > 0) {  //CASE FOR BUY
        if(m1 != UP || m5 != UP || m15 != UP || m30 != UP || h1 != UP || h4 != UP || d1 != UP || w1 != UP || mn != UP)
            return;  //no matching of tf's.
        
        //Find wave average length. For SL
        for(int i = 100; i >= 0; i--) {
            if(p1 == -1) {
                p1 = p2 = i;
            }
            
            if(iLow(symbol, PERIOD_M5, i) < iLow(symbol, PERIOD_M5, p2))
                p2 = i;
            if((p1 == p2) && iOpen(symbol, PERIOD_M5, i) > iClose(symbol, PERIOD_M5, i))
                p2 = i;
            
            if(iHigh(symbol, PERIOD_M5, i) >= iHigh(symbol, PERIOD_M5, p1)) {
                if(p1 == p2)
                    p1 = p2 = i;
                else {
                    wavecount++;
                    wavesize += iHigh(symbol, PERIOD_M5, p1) - iLow(symbol, PERIOD_M5, p2);
                    
                    p1 = p2 = i;
                }
            }
        }
        
        if(wavecount != 0) {
            double average = wavesize / wavecount;
            if(p2 != p1 && (iHigh(symbol, PERIOD_M5, p1) - iLow(symbol, PERIOD_M5, p2)) > average) { //significant unfinished wave
                wavesize += iHigh(symbol, PERIOD_M5, p1) - iLow(symbol, PERIOD_M5, p2);
                wavecount++;
            }
            wavesize = wavesize / wavecount; 
        }
        else
            return;  //Bars movement is not trending-consistent
        
        createBuy(symbol, wavesize);
    }
    else if(orderedPairs[index].movement < 0) {  //CASE FOR SELL
        if(m1 == UP || m5 == UP || m15 == UP || m30 == UP || h1 == UP || h4 == UP || d1 == UP || w1 == UP || mn == UP)
            return;  //no matching of tf's.
        
        //Find wave average length. For SL
        for(int i = 100; i >= 0; i--) {
            if(p1 == -1) {
                p1 = p2 = i;
            }
            
            if(iHigh(symbol, PERIOD_M5, i) > iHigh(symbol, PERIOD_M5, p2))
                p2 = i;
            if((p1 == p2) && iOpen(symbol, PERIOD_M5, i) < iClose(symbol, PERIOD_M5, i))
                p2 = i;
            
            if(iLow(symbol, PERIOD_M5, i) <= iLow(symbol, PERIOD_M5, p1)) {
                if(p1 == p2)
                    p1 = p2 = i;
                else {
                    wavecount++;
                    wavesize += iHigh(symbol, PERIOD_M5, p2) - iLow(symbol, PERIOD_M5, p1);
                    
                    p1 = p2 = i;
                }
            }
        }
    
        if(wavecount != 0) {
            double average = wavesize / wavecount;
            if(p2 != p1 && (iHigh(symbol, PERIOD_M5, p2) - iLow(symbol, PERIOD_M5, p1)) > average) { //significant unfinished wave
                wavesize += iHigh(symbol, PERIOD_M5, p2) - iLow(symbol, PERIOD_M5, p1);
                wavecount++;
            }
            wavesize = wavesize / wavecount; 
        }
        else
            return;  //Bars movement is not trending-consistent
        
        createSell(symbol, wavesize);
    }
}
 
/**
 * Determine if margin available is enough for secure trading
 */
bool isMarginEnough() {
    double capital = AccountInfoDouble(ACCOUNT_BALANCE);
    
    double risk = 0;
    for(int i = 0; i < tradeIndex; i++) {
        if(trades[i].op_type == OP_BUY)
            risk += (trades[i].price - trades[i].sl) * trades[i].size / MarketInfo(trades[i].symbol, MODE_POINT);
        else
            risk += (trades[i].sl - trades[i].price) * trades[i].size / MarketInfo(trades[i].symbol, MODE_POINT);
    }
    
    if(risk > (0.1) * capital)
        return false;
    else
        return true;
}

/**
 * Allow only one trade for symbol
 */
bool symbolAvailable(string symbol) {
    for(int i = 0; i < tradeIndex; i++) {
        if(trades[i].symbol == symbol)
            return false;
    }
    
    return true;
}

/**
 * Open a BUY order
 */
void createBuy(string symbol, double sl) {
    MqlTradeRequest request;
    MqlTradeResult res;
    
    ZeroMemory(request);
    request.symbol = symbol;
    request.price = MarketInfo(symbol, MODE_ASK);
    Print("request price: ", request.price);
    request.volume = R_VOL;
    request.deviation = 10;  //slippage
    request.type_filling = ORDER_FILLING_IOC;
    request.action = TRADE_ACTION_DEAL;
    request.type = ORDER_TYPE_BUY;
    
    double stoploss = request.price - 500*MarketInfo(symbol, MODE_POINT);;
    
    bool sent = OrderSend(request, res);
    
    //check response
    if(sent) {
        if(res.retcode == TRADE_RETCODE_PLACED || res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_DONE_PARTIAL) {
            trades[tradeIndex].symbol = symbol;
            trades[tradeIndex].op_type = request.type;
            trades[tradeIndex].price = res.price;
            trades[tradeIndex].ticket = res.deal;
            trades[tradeIndex].size = res.volume;
            trades[tradeIndex].sl = stoploss;
            
            tradeIndex++;
        }
    }
}

/**
 * Open a SELL order
 */
void createSell(string symbol, double sl) {
    MqlTradeRequest request;
    MqlTradeResult res;
    
    ZeroMemory(request);
    request.symbol = symbol;
    request.price = MarketInfo(symbol, MODE_BID);
    request.volume = R_VOL;
    request.deviation = 10;  //slippage
    request.type_filling = ORDER_FILLING_IOC;
    request.action = TRADE_ACTION_DEAL;
    request.type = ORDER_TYPE_SELL;
    
    double stoploss = request.price + 500*MarketInfo(symbol, MODE_POINT);
    
    bool sent = OrderSend(request, res);
    
    //check response
    if(sent) {
        if(res.retcode == TRADE_RETCODE_PLACED || res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_DONE_PARTIAL) {
            trades[tradeIndex].symbol = symbol;
            trades[tradeIndex].op_type = request.type;
            trades[tradeIndex].price = res.price;
            trades[tradeIndex].ticket = res.deal;
            trades[tradeIndex].size = res.volume;
            trades[tradeIndex].sl = stoploss;
            
            tradeIndex++;
        }
    }
}

/**
 * Close a trade, reorder array and index
 */
bool closeTrade(int i) {
    MqlTradeRequest request;
    MqlTradeResult result;
    
    ZeroMemory(request);
    ZeroMemory(result);
    
    Print("trying to close trade");
    
    ENUM_ORDER_TYPE ptype;
    if(trades[i].op_type == ORDER_TYPE_BUY) {
        request.price = MarketInfo(trades[i].symbol, MODE_BID);
        ptype = ORDER_TYPE_SELL;
    }
    else {
        request.price = MarketInfo(trades[i].symbol, MODE_ASK);
        ptype = ORDER_TYPE_BUY;
    }
    
    request.action = TRADE_ACTION_DEAL;
    request.type = ptype;
    request.volume = trades[i].size;
    request.deviation = 10;  //slippage
    request.symbol = trades[i].symbol;
    request.type_filling = ORDER_FILLING_FOK;
    
    Print("request: ", request.price," ", request.type," ", request.volume," ", request.deviation," ", request.symbol);
    
    bool sent = OrderSend(request, result);
    
    if(sent) {
        if(result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_DONE) {
            for(int p = i; p < tradeIndex - 1; p++) {
                trades[p].op_type = trades[p+1].op_type;
                trades[p].price = trades[p+1].price;
                trades[p].size = trades[p+1].size;
                trades[p].sl = trades[p+1].sl;
                trades[p].symbol = trades[p+1].symbol;
                trades[p].ticket = trades[p+1].ticket;
            }
           
            tradeIndex--;
            
            return true;
        }    
    }
    
    return false;

}

/**
 * close ALL trades
 * Achieved when day target is reached
 */
void closeDayTrades() {
    Print("CLOSING DAY");
    bool tradesOpened = true;
    
    while(tradesOpened) {
        if(tradeIndex > 0) {
            tradesOpened = true;
            for(int i = 0; i < tradeIndex; i++) {
                if(closeTrade(i) == true)
                    i--;
            }
        }
        else
            tradesOpened = false;
    }
}