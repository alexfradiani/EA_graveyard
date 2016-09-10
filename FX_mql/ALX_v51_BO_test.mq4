//+------------------------------------------------------------------+
//|                                          ALX_v50_MGale_M1MAs.mq4 |
//+------------------------------------------------------------------+

/**
 *
 * 1- track the pair with more movement over the last hour
 * 2- play a trade when M1 5 SMA and 15 SMA point the same direction
 * 3- apply martingale of 1:2 ratio in the same direction, max 10 cycles.
 *
 */

#property copyright "ALEXANDER FRADIANI"
#property version   "1.00"
#property strict

#define ALL_SYMB_N 1
#define MAX_TRADES 1

#define SL 10
#define TP 20

#define INIT_SIZE 0.01
#define MAX_SIZE 5.12

#define UP 1
#define DOWN -1
#define NONE 0

datetime lastTime;

string suffix = "";
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
    int ticket;
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

bool test = FALSE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
    /*lastTime = NULL;
    
    for(int i = 0; i < MAX_TRADES; i++) {
        trades[i].trackedSymbol = NULL;
        trades[i].order.ticket = -1;
    }*/
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
    if(lastTime != Time[0]) {
        int order;
        if(test == FALSE)
            order = OrderSend(Symbol(), OP_BUY, 1, Ask, 0, 0, 0, "BO exp:60", 0, 0, clrNONE);
        
        Print("BO order test. ticket: ", order);
        
        test = TRUE;
        lastTime = Time[0];
    }
    
    RefreshRates();
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
    
    //for(int i = 0; i < ALL_SYMB_N; i++)
    //    Print("pairs ordered: ", orderedPairs[i].symbol, " movement: ", orderedPairs[i].movement);
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
    string symbol = trades[index].trackedSymbol;
    int optype = OP_BUY;
    double oprice = MarketInfo(symbol, MODE_ASK);
    
    double stoploss = oprice - SL * MarketInfo(symbol, MODE_POINT);
    double takeprofit = oprice + TP * MarketInfo(symbol, MODE_POINT);
	
	double osize;
	if(trades[index].cycleSize == 0)
        osize = INIT_SIZE;
    else
        osize = 2 * trades[index].cycleSize;
	
	int order = OrderSend(
        symbol, //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        3, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(order > 0) {
        trades[index].order.symbol = symbol;
        trades[index].order.op_type = optype;
        trades[index].order.price = oprice;
        trades[index].order.tp = takeprofit;
        trades[index].order.sl = stoploss;
        trades[index].order.ticket = order;
        trades[index].order.size = osize;
    }
}

/**
 * Open a SELL order
 */
void createSell(int index) {
    string symbol = trades[index].trackedSymbol;
    int optype = OP_SELL;
    double oprice = MarketInfo(symbol, MODE_BID);
    
    double stoploss = oprice + SL * MarketInfo(symbol, MODE_POINT);
    double takeprofit = oprice - TP * MarketInfo(symbol, MODE_POINT);
	
	double osize;
	if(trades[index].cycleSize == 0)
        osize = INIT_SIZE;
    else
        osize = 2 * trades[index].cycleSize;
	
	int order = OrderSend(
        symbol, //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        3, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(order > 0) {
        trades[index].order.symbol = symbol;
        trades[index].order.op_type = optype;
        trades[index].order.price = oprice;
        trades[index].order.tp = takeprofit;
        trades[index].order.sl = stoploss;
        trades[index].order.ticket = order;
        trades[index].order.size = osize;
    }
}

/**
 * Close an order
 */
bool closeOrder(int index) {
    double price;
    if(trades[index].order.op_type == OP_BUY)
        price = MarketInfo(trades[index].trackedSymbol, MODE_BID);
    else
        price = MarketInfo(trades[index].trackedSymbol, MODE_ASK);
        
    if(OrderClose(trades[index].order.ticket, trades[index].order.size, price, 3, clrNONE)) {
        trades[index].order.ticket = -1;
        return TRUE;
    }    
    else
        return FALSE;
}