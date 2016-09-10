//+------------------------------------------------------------------+
//|                                   ALX_v59_M1_TrendGrid_Multi.mq4 |
//+------------------------------------------------------------------+

/**
 * Play direction of major trend
 * if price goes against trend, play mini-martingale
 * Expecting minimum retrace from that level to Break Even
 */

#property copyright "ALEXANDER FRADIANI"
#property link "http://www.fradiani.com"
#property version   "1.00"
#property strict

#define GRID_Y 50
#define TRADE_SIZE 0.01
#define TARGET 1

#define UP 1
#define DOWN -1
#define NONE 0

#define ALL_SYMB_N 28

string defaultPairs[] = {
    "AUDCAD","AUDCHF","AUDJPY","AUDNZD","AUDUSD","CADCHF","CADJPY",
    "CHFJPY","EURAUD","EURCAD","EURCHF","EURGBP","EURJPY","EURNZD",
    "EURUSD","GBPAUD","GBPCAD","GBPCHF","GBPJPY","GBPNZD","GBPUSD",
    "NZDCAD","NZDCHF","NZDJPY","NZDUSD","USDCAD","USDCHF","USDJPY"
};
struct _symbSorter {
    double movement;
    string symbol;
};
_symbSorter orderedPairs[ALL_SYMB_N];

//DATA for orders
struct order_t {     
    int ticket;
    double price;
    int op_type;
    double size;
    string symbol;
    double sl;
    double tp;
};

//DATA for trade cycle
struct cycle_t {
    order_t order;
    double accum;
    int level;
};
cycle_t cycle;

//To identify trend movement
int shortMA, dayMA, bollingerSide;

int debug_levels[50]; //for backtesting performance

//time for bar action
datetime lastTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
    cycle.order.ticket = -1;
    cycle.accum = 0;
    cycle.level = 1;
    
    lastTime = Time[0];
    
    for(int i = 0; i < 50; i++)
        debug_levels[i] = 0;
    
    //Timer for multicurrency checking
    EventSetMillisecondTimer(100);
    
    orderPairs();
//---
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
    cycle.order.ticket = -1;
    cycle.accum = 0;
    cycle.level = 1;
    
    Print("Levels concurrency: ");
    for(int i = 0; i < 50; i++)
        Print("for level: ", i," count: ", debug_levels[i]);
//---
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
//---
    //parseStrategy();
    
    RefreshRates();
}
//+------------------------------------------------------------------+

/**
 * TIMER EVENT 
 */
void OnTimer() {
    //parseStrategy();
}

/**
 * STRATEGY FUNCTION,
 * for both OnTimer and OnTick callbacks
 */
void parseStrategy() {
    //---------------------------------------------------------------------------------- reorder pairs
    if(lastTime != Time[0]) {
        //orderPairs();
    
        lastTime = Time[0];
    }
    
    double point = MarketInfo(Symbol(), MODE_POINT);
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);

    //---------------------------------------------------------------------------------- loop pairs for trade triggers
    //loop top pairs trending up
    /*for(int i = 0; i < 5; i++) {
        
    }
    
    //loop top pairs trending down
    for(int i = ALL_SYMB_N - 1; i > 22; i--) {
        
    }*/
    
    //short term MA
    double ma_0 = iMA(Symbol(), PERIOD_M1, 5, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma_1 = iMA(Symbol(), PERIOD_M1, 5, 0, MODE_SMA, PRICE_CLOSE, 1);
    
    if(ma_0 > ma_1)
        shortMA = UP;
    else if(ma_0 < ma_1)
        shortMA = DOWN;
    else
        shortMA = NONE;
    
    //long term MA
    double dma_0 = iMA(Symbol(), PERIOD_D1, 5, 0, MODE_SMA, PRICE_CLOSE, 0);
    double dma_1 = iMA(Symbol(), PERIOD_D1, 5, 0, MODE_SMA, PRICE_CLOSE, 1);
    
    if(dma_0 > dma_1)
        dayMA = UP;
    else if(dma_0 < dma_1)
        dayMA = DOWN;
    else
        dayMA = NONE;
    
    //Bollinger bands
    double higherBand = iBands(Symbol(), PERIOD_M1, 60, 2, 0, PRICE_CLOSE, MODE_UPPER, 0);
    double middleBand = iBands(Symbol(), PERIOD_M1, 60, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    double lowerBand = iBands(Symbol(), PERIOD_M1, 60, 2, 0, PRICE_CLOSE, MODE_LOWER, 0);
    
    if(bid <= lowerBand)
        bollingerSide = DOWN;
    else if(ask >= higherBand)
        bollingerSide = UP;
    
    if(shortMA == UP && dayMA == UP && bid < middleBand && bollingerSide == DOWN)
        if(cycle.order.ticket == -1)
            createCycle(OP_BUY, TRADE_SIZE);
    
    if(shortMA == DOWN && dayMA == DOWN && ask > middleBand && bollingerSide == UP)
        if(cycle.order.ticket == -1)
            createCycle(OP_SELL, TRADE_SIZE);
    
    //---------------------------------------------------------------------------------- STOPLOSS verification or profit
    if(cycle.order.ticket != -1) {
        if(cycle.order.op_type == OP_BUY) {
            double currAccum = (bid - cycle.order.price) * cycle.order.size / point;
            if(currAccum + cycle.accum >= 1)
                closeCycle(TRUE);
            else if(bid - cycle.order.price <= -1 * GRID_Y * point)
                closeCycle(FALSE);
        }
        else {
            double currAccum = (cycle.order.price - ask) * cycle.order.size / point;
            if(currAccum + cycle.accum >= 1)
                closeCycle(TRUE);
            else if(cycle.order.price - ask <= -1 * GRID_Y * point)
                closeCycle(FALSE);
        }
    }
}

/**
 * Order pairs based on more movement
 */
void orderPairs() {
    //---------------------------------------------------------------Get the movement amount of each pair
    for(int pIndex = 0; pIndex < ALL_SYMB_N; pIndex++) {
        double movUp = 0;
        double movDown = 0;
        double medBar = 0;
        
        for(int i = 1; i <= 2880 /*last 2 dsys*/; i++) {
            double open = iOpen(defaultPairs[pIndex], PERIOD_M1, i);
            double high = iHigh(defaultPairs[pIndex], PERIOD_M1, i);
            double low = iLow(defaultPairs[pIndex], PERIOD_M1, i);
            
            movUp += high - open;
            movDown += open - low;
        }
        
        orderedPairs[pIndex].symbol = defaultPairs[pIndex];
        orderedPairs[pIndex].movement = (movUp - movDown) / MarketInfo(defaultPairs[pIndex], MODE_POINT);
    }
    
    //---------------------------------------------------------------Order by descending mode
    for(int i = 0; i < ALL_SYMB_N; i++) {
        for(int j = i; j < ALL_SYMB_N; j++) {
            if(orderedPairs[j].movement > orderedPairs[i].movement) {
                _symbSorter temp;
                temp.movement = orderedPairs[i].movement;
                temp.symbol = orderedPairs[i].symbol;
                
                orderedPairs[i].movement = orderedPairs[j].movement;
                orderedPairs[i].symbol = orderedPairs[j].symbol;
                
                orderedPairs[j].movement = temp.movement;
                orderedPairs[j].symbol = temp.symbol;
            }
        }
    }
    
    for(int i = 0; i < ALL_SYMB_N; i++)
        Print("ordered pairs ", orderedPairs[i].symbol, ": ", orderedPairs[i].movement);
}

/**
 * DETERMINE the size of next lot based on grid table
 */
double calcNextSize() {
    double accumLoss = 0;
    double accumPips = 0;
    
    double level_size = TRADE_SIZE;
    for(int i = 1; i <= cycle.level; i++) {
        accumPips = i * GRID_Y;
        accumLoss += level_size * GRID_Y;
        level_size = accumLoss / (accumPips / 3);
    }
    
    return level_size;
}

void createCycle(int optype, double osize) {
    string symbol = Symbol();
    double oprice = optype == OP_BUY? MarketInfo(symbol, MODE_ASK) : MarketInfo(symbol, MODE_BID);
    //double stoploss = Ask - 50*Point;
	//double tp = Bid + 10*Point;
	
	int order = OrderSend(
        symbol, //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        5, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(order > 0) {
        cycle.order.ticket = order;
        cycle.order.op_type = optype;
        cycle.order.price = oprice;
        cycle.order.size = osize;
        cycle.order.symbol = symbol;
    }
}

/**
 * close cycle
 */
void closeCycle(bool in_profit) {
    bool stillOpen = TRUE;
    
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    while(stillOpen) {
        double price = 0;
        if(cycle.order.op_type == OP_BUY)
            price = bid;
        else
            price = ask;
            
        if(OrderClose(cycle.order.ticket, cycle.order.size, price, 10, clrNONE)) {
            cycle.order.ticket = -1;
            
            if(in_profit == TRUE) {
                //debugging
                debug_levels[cycle.level]++;
                
                cycle.accum = 0;
                cycle.level = 1;
            }
            else {
                if(cycle.level < 2) {
                    if(cycle.order.op_type == OP_BUY)
                        cycle.accum += (bid - cycle.order.price) * cycle.order.size / point;
                    else
                        cycle.accum += (cycle.order.price - ask) * cycle.order.size / point;
                        
                    double size = calcNextSize();
                    createCycle(cycle.order.op_type, size);
                    cycle.level++;
                }
                else {
                    cycle.accum = 0;
                    cycle.level = 1;
                }
            }
            
            stillOpen = FALSE;
        }
    }
}