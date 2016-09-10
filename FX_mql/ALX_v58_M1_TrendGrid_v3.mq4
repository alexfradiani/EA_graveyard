//+------------------------------------------------------------------+
//|                                      ALX_v58_M1_TrendGrid_v3.mq4 |
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

#define GRID_Y 30
#define TRADE_SIZE 0.01
#define TARGET 10

#define UP 1
#define DOWN -1
#define NONE 0

#define ALL_SYMB_N 1

string defaultPairs[] = {
    "EURUSD"
};
/*
string defaultPairs[] = {
    "AUDCAD","AUDCHF","AUDJPY","AUDNZD","AUDUSD","CADCHF","CADJPY",
    "CHFJPY","EURAUD","EURCAD","EURCHF","EURGBP","EURJPY","EURNZD",
    "EURUSD","GBPAUD","GBPCAD","GBPCHF","GBPJPY","GBPNZD","GBPUSD",
    "NZDCAD","NZDCHF","NZDJPY","NZDUSD","USDCAD","USDCHF","USDJPY"
};*/
struct _symbSorter {
    double movement;
    string symbol;
};
_symbSorter orderedPairs[ALL_SYMB_N];

datetime lastTime;

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
int dailyTrend;
int bollingerSide;
int fastMA;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
    lastTime = Time[0];
    
    cycle.level = 0;
    cycle.accum = 0;
    cycle.order.ticket = -1;
//---
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
    lastTime = Time[0];
//---
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
//---
    double point = MarketInfo(Symbol(), MODE_POINT);
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);
    
    if(lastTime != Time[0]) {
        //Read long term MA
        double dma_0 = iMA(Symbol(), PERIOD_D1, 5, 0, MODE_SMA, PRICE_CLOSE, 0);
        double dma_1 = iMA(Symbol(), PERIOD_D1, 5, 0, MODE_SMA, PRICE_CLOSE, 1);
        
        if(dma_0 > dma_1)
            dailyTrend = UP;
        else if(dma_0 < dma_1)
            dailyTrend = DOWN;
        else
            dailyTrend = NONE;
        
        //Read fast ma
        double m3_0 = iMA(Symbol(), PERIOD_M1, 3, 0, MODE_SMA, PRICE_CLOSE, 0);
        double m3_1 = iMA(Symbol(), PERIOD_M1, 3, 0, MODE_SMA, PRICE_CLOSE, 1);
        
        if(m3_0 > m3_1)
            fastMA = UP;
        else if(m3_0 < m3_1)
            fastMA = DOWN;
        else
            fastMA = NONE;
        
        //read Bollinger bands
        double higherBand = iBands(Symbol(), PERIOD_M1, 60, 2, 0, PRICE_CLOSE, MODE_UPPER, 0);
        double middleBand = iBands(Symbol(), PERIOD_M1, 60, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
        double lowerBand = iBands(Symbol(), PERIOD_M1, 60, 2, 0, PRICE_CLOSE, MODE_LOWER, 0);
        
        double upThreshold = middleBand + 0.8*(higherBand - middleBand);
        double downThreshold = middleBand - 0.8*(middleBand - lowerBand);
        
        if(bid > upThreshold)
            bollingerSide = UP;
        else if(bid < downThreshold)
            bollingerSide = DOWN;
        
        //Get last movement of pair
        orderPairs();
        
        Print("daily trend ", dailyTrend, " bollinger: ", bollingerSide, " pair mov: ", orderedPairs[0].movement, " fma: ", fastMA);
        
        if(dailyTrend == UP && orderedPairs[0].movement > 0 && bollingerSide == DOWN && fastMA == UP)
            if(bid <= middleBand - 0.5*(middleBand - lowerBand))        
                if(cycle.order.ticket == -1)
                    createBuy(TRADE_SIZE);
        
        if(dailyTrend == DOWN && orderedPairs[0].movement < 0 && bollingerSide == UP && fastMA == DOWN)
            if(bid >= middleBand + 0.5*(higherBand - middleBand))
                if(cycle.order.ticket == -1)
                    createSell(TRADE_SIZE);
        
        lastTime = Time[0];
    }
    
    if(cycle.order.ticket != -1) {
        if(cycle.order.op_type == OP_BUY) {  //CASE BUY
            double currAccum = (bid - cycle.order.price) * cycle.order.size / point;
            
            if(fastMA == DOWN && (bid - cycle.order.price) >= TARGET * point)
                closeTrade(TRUE);
            else if(bid - cycle.order.price <= -1 * GRID_Y * point) {  //next level of mini-martingale
                closeTrade(FALSE);
                
                //double size = calcNextSize();
                //createBuy(size);
            }
        }
        else { //CASE SELL
            double currAccum = (cycle.order.price - ask) * cycle.order.size / point;
            
            if(fastMA == UP && (cycle.order.price - ask) >= TARGET * point)
                closeTrade(TRUE);
            else if(cycle.order.price - ask <= -1 * GRID_Y * point) {  //next level of mini-martingale
                closeTrade(FALSE);
                
                //double size = calcNextSize();
                //createSell(size);
            }
        }
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
        
        for(int i = 1; i <= 100; i++) {
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

/**
 * Open a BUY order
 */
void createBuy(double osize) {
    double point = MarketInfo(Symbol(), MODE_POINT);
    int optype = OP_BUY;
    double oprice = MarketInfo(Symbol(), MODE_ASK);
	
	int order = OrderSend(
        Symbol(), //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        10, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(order > 0) {
        cycle.order.op_type = optype;
        cycle.order.price = oprice;
        cycle.order.ticket = order;
        cycle.order.size = osize;
    }
}

/**
 * Open a SELL order
 */
void createSell(double osize) {
    double point = MarketInfo(Symbol(), MODE_POINT);
    int optype = OP_SELL;
    double oprice = MarketInfo(Symbol(), MODE_BID);
	
	int order = OrderSend(
        Symbol(), //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        10, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(order > 0) {
        cycle.order.op_type = optype;
        cycle.order.price = oprice;
        cycle.order.ticket = order;
        cycle.order.size = osize;
    }
}

/**
 * close Trades
 */
void closeTrade(bool in_profit) {
    bool stillOpen = TRUE;
    
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);;
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    while(stillOpen) {
        double price = 0;
        if(cycle.order.op_type == OP_BUY)
            price = bid;
        else
            price = ask;
            
        if(OrderClose(cycle.order.ticket, cycle.order.size, price, 10, clrNONE)) {
            cycle.order.ticket = -1;
            
            cycle.accum = 0;
            cycle.level = 0;
            /*
            if(in_profit == TRUE) {
                cycle.accum = 0;
                cycle.level = 0;
            }
            else {
                if(cycle.order.op_type == OP_BUY)
                    cycle.accum += (bid - cycle.order.price) * cycle.order.size / point;
                else
                    cycle.accum += (cycle.order.price - ask) * cycle.order.size / point;
                    
                cycle.level++;
                if(cycle.level > 4) {  //reset martingale
                    cycle.accum = 0;
                    cycle.level = 0;
                }
            } */
            
            stillOpen = FALSE;
        }
    }
}