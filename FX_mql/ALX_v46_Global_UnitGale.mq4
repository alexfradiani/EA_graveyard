//+------------------------------------------------------------------+
//|                                      ALX_v46_Global_UnitGale.mq5 |
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

datetime lastTime;

string suffix = "";
string defaultPairs[] = {
    "CADCHF"
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
    int ticket;      
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
            if(trades[i].orders[j].op_type == OP_BUY) {  //CASE BUY
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
        
        if(trades[i].orders[lastCycle].op_type == OP_BUY) {
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
    int optype = OP_BUY;
    double oprice = MarketInfo(symbol, MODE_ASK);
    double stoploss = sl;
	double osize = size;
	
	int order = OrderSend(
        symbol, //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        5, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(order != -1) {
        int cycle = trades[tradePos].cycleIndex;
        trades[tradePos].orders[cycle].symbol = symbol;
        trades[tradePos].orders[cycle].op_type = optype;
        trades[tradePos].orders[cycle].price = oprice;
        trades[tradePos].orders[cycle].ticket = order;
        trades[tradePos].orders[cycle].size = osize;
        trades[tradePos].orders[cycle].sl = stoploss;
        
        trades[tradePos].cycleIndex++;
        if(size == INIT_SIZE)
            tradeIndex++;
    }
}

/**
 * Open a SELL order
 */
void createSell(string symbol, double sl, double size, int tradePos) {
    int optype = OP_SELL;
    double oprice = MarketInfo(symbol, MODE_BID);
    double stoploss = sl;
	double osize = size;
	
	int order = OrderSend(
        symbol, //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        5, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(order != -1) {
        int cycle = trades[tradePos].cycleIndex;
        trades[tradePos].orders[cycle].symbol = symbol;
        trades[tradePos].orders[cycle].op_type = optype;
        trades[tradePos].orders[cycle].price = oprice;
        trades[tradePos].orders[cycle].ticket = order;
        trades[tradePos].orders[cycle].size = osize;
        trades[tradePos].orders[cycle].sl = stoploss;
        
        trades[tradePos].cycleIndex++;
        if(size == INIT_SIZE)
            tradeIndex++;
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
    double price;
    if(trades[tI].orders[cI].op_type == OP_BUY)
        price = MarketInfo(trades[tI].orders[cI].symbol, MODE_BID);
    else
        price = MarketInfo(trades[tI].orders[cI].symbol, MODE_ASK);
        
    bool closed = OrderClose(trades[tI].orders[cI].ticket, trades[tI].orders[cI].size, price, 3, Blue);
    return closed;
}